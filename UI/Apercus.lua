-- Aperçus animés des modules sans élément à l'écran : une petite scène qui
-- tourne en boucle dans l'en-tête fixe de leur page (voir UI/Menu.lua).
-- Une scène = { cycle (s), creer(f), image(f, t) } ; t = temps dans la boucle.
-- Les modules qui ont un vrai élément (barre d'XP, tir, usure, poubelle,
-- proposition d'Auto Equip, boutons du swap, widget) le montrent eux-mêmes.

local ADDON, ns = ...

local Apercus = {}
ns.Apercus = Apercus

local L = ns.L or setmetatable({}, { __index = function(_, k) return k end })
local LARGEUR, HAUTEUR = 330, 92
local ICONES = "Interface\\Icons\\"

local scenes, cadres = {}, {}

local function T() return ns.Theme end
local function C() return ns.Controles end

-- 0 avant a, 1 après b, linéaire entre les deux.
local function entre(t, a, b) return math.max(0, math.min(1, (t - a) / (b - a))) end
-- Apparaît entre a et a + 0,3 s, disparaît entre b et b + 0,4 s.
local function vie(t, a, b) return math.min(entre(t, a, a + 0.3), 1 - entre(t, b, b + 0.4)) end

local function icone(f, chemin, taille)
    local i = f:CreateTexture(nil, "ARTWORK")
    i:SetSize(taille, taille)
    i:SetTexture(chemin)
    if chemin:find("^Interface\\Icons\\") then i:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    return i
end

local function texte(f, police, couleur, txt)
    local t = C().texte(f, police, couleur)
    if txt then t:SetText(txt) end
    return t
end

function Apercus.definir(nom, cycle, creer, image)
    scenes[nom] = { cycle = cycle, creer = creer, image = image }
end

function Apercus.vitrine(nom)
    local s = scenes[nom]
    if not s then return nil end
    local f = cadres[nom]
    if not f then
        f = CreateFrame("Frame", nil, UIParent)
        f:SetSize(LARGEUR, HAUTEUR)
        s.creer(f)
        f:Hide()
        cadres[nom] = f
    end
    return f, "apercu:" .. nom, true   -- scène à part : rien à rendre à l'écran
end

function Apercus.apercu(nom, oui)
    local s = scenes[nom]
    local f = s and Apercus.vitrine(nom)
    if not f then return end
    if oui then
        f.debut = GetTime()
        s.image(f, 0)
        f:Show()
        f:SetScript("OnUpdate", function(self) s.image(self, (GetTime() - self.debut) % s.cycle) end)
    else
        f:SetScript("OnUpdate", nil)
        f:Hide()
    end
end

---------------------------------------------------------------------------
-- Les scènes
---------------------------------------------------------------------------

-- Marchand : réparation, puis vente des gris.
Apercus.definir("marchand", 4.5, function(f)
    local jeu = ns.Jeu
    local function argent(c) return jeu and jeu.texteArgent and jeu.texteArgent(c) or (c .. " pc") end
    f.icone = icone(f, ICONES .. "INV_Misc_Bag_07", 40)
    f.icone:SetPoint("LEFT", 20, 0)
    f.reparer = CreateFrame("Frame", nil, f)
    f.reparer:SetSize(240, 20)
    f.reparer:SetPoint("LEFT", 80, 14)
    local i1 = icone(f.reparer, ICONES .. "Trade_BlackSmithing", 18)
    i1:SetPoint("LEFT")
    texte(f.reparer, "petit", "texte", L["Réparé : %s."]:format(argent(120))):SetPoint("LEFT", i1, "RIGHT", 6, 0)
    f.vendre = CreateFrame("Frame", nil, f)
    f.vendre:SetSize(240, 20)
    f.vendre:SetPoint("LEFT", 80, -14)
    local i2 = icone(f.vendre, ICONES .. "INV_Misc_Coin_02", 18)
    i2:SetPoint("LEFT")
    texte(f.vendre, "petit", "orange", L["%d objet(s) gris vendu(s) : %s."]:format(8, argent(45))):SetPoint("LEFT", i2, "RIGHT", 6, 0)
end, function(f, t)
    f.reparer:SetAlpha(vie(t, 0.5, 3.8))
    f.vendre:SetAlpha(vie(t, 1.4, 3.8))
end)

-- Points de vol : connus en blanc, à découvrir en orange qui pulsent.
Apercus.definir("vols", 3, function(f)
    local carte = CreateFrame("Frame", nil, f)
    carte:SetSize(300, 64)
    carte:SetPoint("CENTER", 0, 4)
    T().fond(carte, "sombre", 0.9, "bord")
    f.points = {}
    local pos = { { 30, 20, true }, { 90, -12, true }, { 150, 14, false }, { 210, -10, true }, { 262, 16, false } }
    for i, p in ipairs(pos) do
        local ic = icone(carte, "Interface\\Minimap\\Tracking\\FlightMaster", 18)
        ic:SetPoint("CENTER", carte, "LEFT", p[1], p[2])
        if p[3] then ic:SetVertexColor(1, 1, 1) else ic:SetVertexColor(1, 0.6, 0.15) end
        ic.connu = p[3]
        f.points[i] = ic
    end
    local leg = texte(f, "petit", "texteDoux", L["Point de vol connu"] .. "   |cffff9933" .. L["Point de vol à découvrir"] .. "|r")
    leg:SetPoint("BOTTOM", 0, 2)
end, function(f, t)
    for _, ic in ipairs(f.points) do
        if not ic.connu then ic:SetAlpha(0.45 + 0.55 * math.abs(math.sin(t * 3))) end
    end
end)

-- Marqueurs : une touche, et les symboles se posent au-dessus de chacun.
Apercus.definir("marqueurs", 4, function(f)
    f.touche = CreateFrame("Frame", nil, f)
    f.touche:SetSize(34, 26)
    f.touche:SetPoint("LEFT", 16, -8)
    f.toucheFond = T().fond(f.touche, "flot", 1, "bordFort")
    texte(f.touche, "petit", "texte", "F1"):SetPoint("CENTER")
    f.persos = {}
    local noms = { L["Toi"], L["Pote"] .. " 1", L["Pote"] .. " 2" }
    for i, nom in ipairs(noms) do
        local p = CreateFrame("Frame", nil, f)
        p:SetSize(70, 8)
        p:SetPoint("LEFT", 80 + (i - 1) * 84, -14)
        local barre = p:CreateTexture(nil, "ARTWORK")
        barre:SetAllPoints()
        barre:SetColorTexture(T().rgb("vert"))
        texte(p, "petit", "texte", nom):SetPoint("TOP", p, "BOTTOM", 0, -3)
        p.symbole = icone(p, "Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. ({ 1, 2, 8 })[i], 24)
        p.symbole:SetPoint("BOTTOM", p, "TOP", 0, 6)
        f.persos[i] = p
    end
end, function(f, t)
    local appui = t >= 0.6 and t < 0.85
    f.touche:SetScale(appui and 0.9 or 1)
    if f.toucheFond then f.toucheFond:SetVertexColor(T().rgb(appui and "accent" or "flot")) end
    for i, p in ipairs(f.persos) do
        local a = vie(t, 0.8 + i * 0.15, 3.4)
        p.symbole:SetAlpha(a)
        local pop = 1 + 0.4 * (1 - entre(t, 0.8 + i * 0.15, 1.1 + i * 0.15))
        p.symbole:SetSize(24 * (a > 0 and pop or 1), 24 * (a > 0 and pop or 1))
    end
end)

-- Spy Ping : clic sur l'ennemi de la liste, un ping part.
Apercus.definir("spyPing", 3.5, function(f)
    f.ligne = CreateFrame("Frame", nil, f)
    f.ligne:SetSize(170, 22)
    f.ligne:SetPoint("LEFT", 16, 0)
    f.ligneFond = T().fond(f.ligne, "sombre", 1, "bordFort")
    texte(f.ligne, "petit", "rouge", L["Voleur"] .. " 60  ·  Grinta"):SetPoint("LEFT", 8, 0)
    f.anneau = f:CreateTexture(nil, "OVERLAY")
    f.anneau:SetTexture(T().MEDIA .. "RondBord")
    f.anneau:SetVertexColor(T().rgb("rouge"))
    f.anneau:SetPoint("CENTER", f, "LEFT", 260, 0)
    f.cible = icone(f, "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8", 22)
    f.cible:SetPoint("CENTER", f, "LEFT", 260, 0)
    f.mot = texte(f, "petit", "rouge", L["Attaque"])
    f.mot:SetPoint("TOP", f.cible, "BOTTOM", 0, -16)
end, function(f, t)
    local clic = t >= 0.5 and t < 0.75
    if f.ligneFond then f.ligneFond:SetVertexColor(T().rgb(clic and "accent" or "sombre")) end
    local p = entre(t, 0.8, 1.8)
    f.anneau:SetSize(20 + p * 60, 20 + p * 60)
    f.anneau:SetAlpha(t >= 0.8 and (1 - p) or 0)
    f.cible:SetAlpha(vie(t, 0.8, 3.0))
    f.mot:SetAlpha(vie(t, 0.9, 3.0))
end)

-- Interaction rapide : l'icône flotte au-dessus du filon le plus proche.
Apercus.definir("softInteract", 2.4, function(f)
    f.filon = icone(f, ICONES .. "INV_Ore_Copper_01", 36)
    f.filon:SetPoint("CENTER", -40, -14)
    f.main = icone(f, ICONES .. "Trade_Mining", 22)
    f.portee = texte(f, "petit", "accent", L["jusqu'à 20 m"])
    f.portee:SetPoint("LEFT", f.filon, "RIGHT", 40, 0)
end, function(f, t)
    f.main:ClearAllPoints()
    f.main:SetPoint("BOTTOM", f.filon, "TOP", 0, 6 + 4 * math.sin(t * math.pi * 2 / 2.4 * 2))
    f.main:SetAlpha(0.7 + 0.3 * math.abs(math.sin(t * 3)))
end)

-- Tsquid Area : un coup critique qui éclate.
Apercus.definir("tsquid", 2.4, function(f)
    f.nombre = f:CreateFontString(nil, "OVERLAY")
    f.nombre:SetFont(T().MEDIA .. "Polices\\Archivo-BoldCondensed.ttf", 30, "OUTLINE")
    f.nombre:SetTextColor(1, 0.85, 0.2)
    f.nombre:SetText("2 481")
    f.nombre:SetPoint("CENTER", -20, 4)
    f.mot = texte(f, "petit", "orange", L["Critique !"])
    f.mot:SetPoint("LEFT", f.nombre, "RIGHT", 10, 0)
end, function(f, t)
    local p = entre(t, 0.3, 0.55)
    local echelle = t < 0.3 and 0.01 or (p < 1 and (0.4 + p * 1.1) or (1.5 - 0.5 * entre(t, 0.55, 0.8)))
    f.nombre:SetScale(math.max(0.01, echelle))
    f.nombre:SetAlpha(vie(t, 0.3, 1.8))
    f.mot:SetAlpha(vie(t, 0.5, 1.8))
end)

-- Boost FPS : le compteur grimpe.
Apercus.definir("boostFPS", 4, function(f)
    f.nombre = f:CreateFontString(nil, "OVERLAY")
    f.nombre:SetFont(T().MEDIA .. "Polices\\Archivo-BoldCondensed.ttf", 26, "")
    f.nombre:SetPoint("LEFT", 24, 8)
    f.fond = f:CreateTexture(nil, "ARTWORK")
    f.fond:SetColorTexture(T().rgb("sombre"))
    f.fond:SetSize(280, 8)
    f.fond:SetPoint("LEFT", 24, -22)
    f.barre = f:CreateTexture(nil, "OVERLAY")
    f.barre:SetHeight(8)
    f.barre:SetPoint("LEFT", f.fond, "LEFT")
end, function(f, t)
    local p = entre(t, 0.4, 2.4)
    local fps = math.floor(48 + 48 * p)
    f.nombre:SetText(("%d FPS"):format(fps))
    local r, g = 1 - p * 0.75, 0.35 + p * 0.55
    f.nombre:SetTextColor(r, g, 0.35)
    f.barre:SetWidth(math.max(1, 280 * (0.45 + 0.55 * p)))
    f.barre:SetColorTexture(r, g, 0.35)
end)

-- Ménage des objets de quête : l'objet qui ne sert plus disparaît.
Apercus.definir("menage", 3.6, function(f)
    f.objets = {}
    local chemins = { "INV_Misc_Bone_08", "INV_Misc_Note_01", "INV_Misc_MonsterClaw_04" }
    for i, c in ipairs(chemins) do
        local o = icone(f, ICONES .. c, 34)
        o:SetPoint("CENTER", (i - 2) * 50, 4)
        f.objets[i] = o
    end
    f.croix = f:CreateTexture(nil, "OVERLAY")
    f.croix:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady")
    f.croix:SetSize(22, 22)
    f.croix:SetPoint("BOTTOMRIGHT", f.objets[2], "BOTTOMRIGHT", 6, -6)
    f.mot = texte(f, "petit", "vert", L["quête terminée"])
    f.mot:SetPoint("TOP", f.objets[2], "BOTTOM", 0, -8)
end, function(f, t)
    local part = entre(t, 1.6, 2.2)
    f.objets[2]:SetAlpha(1 - part)
    f.croix:SetAlpha(vie(t, 0.5, 1.6))
    f.mot:SetAlpha(vie(t, 0.5, 1.6))
    f.objets[1]:ClearAllPoints()
    f.objets[1]:SetPoint("CENTER", -50 + 25 * entre(t, 2.2, 2.8), 4)
    f.objets[3]:ClearAllPoints()
    f.objets[3]:SetPoint("CENTER", 50 - 25 * entre(t, 2.2, 2.8), 4)
end)

-- Auto Sets : en selle, la carotte prend la place du bijou ; pied à terre,
-- le bijou revient.
Apercus.definir("tenues", 4.4, function(f)
    f.monture = icone(f, ICONES .. "Ability_Mount_RidingHorse", 30)
    f.monture:SetPoint("CENTER", -70, 4)
    f.bijou = icone(f, ICONES .. "INV_Jewelry_Talisman_07", 38)
    f.bijou:SetPoint("CENTER", 20, 4)
    f.carotte = icone(f, ICONES .. "INV_Misc_Food_54", 38)
    f.carotte:SetPoint("CENTER", 20, 4)
    f.mot = texte(f, "petit", "vert", L["En selle : tenue Monture mise"])
    f.mot:SetPoint("TOP", f.bijou, "BOTTOM", -30, -8)
    f.retour = texte(f, "petit", "accent", L["Pied à terre : équipement remis"])
    f.retour:SetPoint("TOP", f.bijou, "BOTTOM", -30, -8)
end, function(f, t)
    local selle = entre(t, 0.6, 0.9) * (1 - entre(t, 2.8, 3.1))
    f.monture:SetAlpha(0.25 + 0.75 * selle)
    f.carotte:SetAlpha(selle)
    f.bijou:SetAlpha(1 - selle)
    f.mot:SetAlpha(vie(t, 0.9, 2.6))
    f.retour:SetAlpha(vie(t, 3.1, 4.0))
end)

-- Météo et brouillard : la pluie tombe, puis s'arrête.
Apercus.definir("meteo", 4, function(f)
    f.gouttes = {}
    for i = 1, 28 do
        local g = f:CreateTexture(nil, "ARTWORK")
        g:SetColorTexture(0.6, 0.75, 1, 0.7)
        g:SetSize(1, 10)
        g.x, g.v = (i * 37) % 320 + 5, 60 + (i * 13) % 40
        f.gouttes[i] = g
    end
    f.soleil = icone(f, ICONES .. "Spell_Holy_SearingLight", 32)
    f.soleil:SetPoint("CENTER")
end, function(f, t)
    local pluie = 1 - entre(t, 1.6, 2.2)
    for i, g in ipairs(f.gouttes) do
        local y = (t * g.v + i * 11) % 92
        g:ClearAllPoints()
        g:SetPoint("TOPLEFT", f, "TOPLEFT", g.x, -y)
        g:SetAlpha(pluie * 0.8)
    end
    f.soleil:SetAlpha(vie(t, 2.0, 3.5))
end)

---------------------------------------------------------------------------
-- Branchement : chaque module qui a une scène et pas encore d'aperçu.
---------------------------------------------------------------------------

for _, m in ipairs(ns.Reglages and ns.Reglages.MODULES or {}) do
    if scenes[m.nom] and not m.vitrine then
        local nom = m.nom
        m.vitrine = function() return Apercus.vitrine(nom) end
        m.apercu = function(oui) Apercus.apercu(nom, oui) end
    end
end
