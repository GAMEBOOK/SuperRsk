-- Fabrication : la barre d'une série (« Créer 10 ») : nom de la recette,
-- « 4 / 10 fabriqués », un repère par objet, le temps total restant et
-- l'icône. Elle se montre au lancement d'une série depuis la fenêtre de
-- métier et disparaît à la fin, ou si la série s'arrête. Calculs dans
-- Core/Fabrication.lua.
-- Aperçu : une copie (même construction) avec une série d'exemple.

local ADDON, ns = ...

local Fabrication = ns.Fabrication
local L = ns.L or setmetatable({}, { __index = function(_, k) return k end })
local function R(cle) return ns.Reglages.get(cle) end

local BLANC = "Interface\\Buttons\\WHITE8x8"
local POLICE = "Polices\\Archivo-BoldCondensed.ttf"
local LARGEUR, H_BARRE, ICONE, ECART = 420, 20, 30, 10
local L_TEMPS = 46                  -- place du temps, à gauche de la barre
local REPERE_MIN = 8               -- moins de 8 px entre deux repères : aucun
local BARRES = { "PlayerCastingBarFrame", "CastingBarFrame" }
local EVENEMENTS = { "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_SUCCEEDED",
                     "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_FAILED" }
local EXEMPLE = { nom = "Fondre du cuivre", icone = "Interface\\Icons\\INV_Ingot_02", faits = 4, nombre = 10,
                  part = 0.45, reste = 15 }

local barre, copie, ecoute, veille
local serie                         -- série en cours (Core/Fabrication.lua)
local apercu = false
local cachees = {}                  -- barres d'incantation du jeu cachées -> alpha d'origine

---------------------------------------------------------------------------
-- La barre (la vraie et la copie de l'aperçu)
---------------------------------------------------------------------------

local function police(fs, taille)
    fs:SetFont(ns.Theme.MEDIA .. POLICE, taille, "OUTLINE")
end

local function construire(nom)
    local T = ns.Theme
    local w = CreateFrame("Frame", nom, UIParent)
    -- Temps, barre et icône tiennent dans le cadre (bannière d'aperçu,
    -- poignée du mode Déplacer).
    w:SetSize(L_TEMPS + ECART + LARGEUR + ECART + ICONE, H_BARRE + 2 * 24)
    w:SetFrameStrata("MEDIUM")
    w:SetClampedToScreen(true)
    local piste = CreateFrame("StatusBar", nil, w)
    piste:SetPoint("LEFT", L_TEMPS + ECART, 0)
    piste:SetSize(LARGEUR, H_BARRE)
    piste:SetMinMaxValues(0, 1)
    w.fond = piste:CreateTexture(nil, "BACKGROUND")
    w.fond:SetAllPoints()
    w.fond:SetColorTexture(T.rgb("panneau"))
    -- Contour d'un pixel.
    w.bords = {}
    for i, p in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" },
                         { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local b = piste:CreateTexture(nil, "OVERLAY", nil, 2)
        b:SetColorTexture(0, 0, 0, 1)
        b:SetPoint(p[1], piste, p[1])
        b:SetPoint(p[2], piste, p[2])
        if i <= 2 then b:SetHeight(1) else b:SetWidth(1) end
        w.bords[i] = b
    end
    w.piste = piste
    w.reperes = {}
    -- Textes au-dessus des repères.
    local dessus = CreateFrame("Frame", nil, w)
    dessus:SetAllPoints()
    dessus:SetFrameLevel(piste:GetFrameLevel() + 3)
    w.nom = dessus:CreateFontString(nil, "OVERLAY")
    w.nom:SetPoint("BOTTOMLEFT", piste, "TOPLEFT", 0, 4)
    w.nom:SetWidth(LARGEUR * 0.6)
    w.nom:SetJustifyH("LEFT")
    w.nom:SetWordWrap(false)
    w.compte = dessus:CreateFontString(nil, "OVERLAY")
    w.compte:SetPoint("BOTTOMRIGHT", piste, "TOPRIGHT", 0, 4)
    w.compte:SetJustifyH("RIGHT")
    w.temps = dessus:CreateFontString(nil, "OVERLAY")
    w.temps:SetPoint("RIGHT", piste, "LEFT", -ECART, 0)
    w.temps:SetJustifyH("RIGHT")
    local ic = CreateFrame("Frame", nil, w)
    ic:SetSize(ICONE, ICONE)
    ic:SetPoint("LEFT", piste, "RIGHT", ECART, 0)
    w.icone = ic:CreateTexture(nil, "ARTWORK")
    w.icone:SetAllPoints()
    w.icone:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    w.cadreIcone = ic
    w:Hide()
    return w
end

-- Réglages visuels : texture, fond, taille, icône, polices.
local function habiller(w)
    local T = ns.Theme
    local chemin = ns.BarreXP and ns.BarreXP.chemin and ns.BarreXP.chemin(R("fabTexture")) or BLANC
    w.piste:SetStatusBarTexture(chemin)
    w.piste:SetStatusBarColor(T.rgb("accent"))
    w.fond:SetAlpha(tonumber(R("fabFond")) or 0.9)
    w.cadreIcone:SetShown(R("fabIcone") ~= false)
    if w == barre then w:SetScale(tonumber(R("fabTaille")) or 1) end
    police(w.nom, 14)
    police(w.compte, 14)
    police(w.temps, 18)
    w.nom:SetTextColor(T.rgb("texte"))
    w.compte:SetTextColor(T.rgb("texteDoux"))
    w.temps:SetTextColor(T.rgb("accent"))
end

local function remplir(w, icone, nom, faits, nombre)
    w.icone:SetTexture(icone)
    w.nom:SetText(nom or "")
    w.compte:SetText(L["%d / %d fabriqués"]:format(faits, nombre))
end

-- Un repère après chaque objet ; ceux déjà faits sont foncés.
local function poserReperes(w, nombre, faits, position)
    local n = (LARGEUR / nombre < REPERE_MIN) and 0 or nombre - 1
    for i = 1, n do
        local r = w.reperes[i]
        if not r then
            r = w.piste:CreateTexture(nil, "OVERLAY", nil, 1)
            r:SetWidth(1)
            w.reperes[i] = r
        end
        if i <= faits then r:SetColorTexture(0, 0, 0, 0.8) else r:SetColorTexture(1, 1, 1, 0.25) end
        local x = position(i) * LARGEUR
        r:ClearAllPoints()
        r:SetPoint("TOP", w.piste, "TOPLEFT", x, 0)
        r:SetPoint("BOTTOM", w.piste, "BOTTOMLEFT", x, 0)
        r:Show()
    end
    for i = n + 1, #w.reperes do w.reperes[i]:Hide() end
end

local function avancer(w, part, reste)
    w.piste:SetValue(math.min(1, part))
    local s = math.max(0, math.floor(reste + 0.5))
    if s ~= w.secondes then
        w.secondes = s
        w.temps:SetText(Fabrication.horloge(reste))
    end
end

local function montrerExemple(w)
    habiller(w)
    remplir(w, EXEMPLE.icone, L[EXEMPLE.nom], EXEMPLE.faits, EXEMPLE.nombre)
    poserReperes(w, EXEMPLE.nombre, EXEMPLE.faits, function(i) return i / EXEMPLE.nombre end)
    w.secondes = nil
    avancer(w, EXEMPLE.part, EXEMPLE.reste)
    w:Show()
end

---------------------------------------------------------------------------
-- Barre d'incantation du jeu et titre de la fenêtre de métier
---------------------------------------------------------------------------

local function cacherIncantation()
    if R("fabBarreNormale") then return end
    for _, nom in ipairs(BARRES) do
        local f = _G[nom]
        if f and f.SetAlpha and f.GetAlpha then
            if cachees[f] == nil then cachees[f] = f:GetAlpha() end
            -- Le jeu remet l'alpha à chaque incantation : on recache.
            if f:GetAlpha() ~= 0 then f:SetAlpha(0) end
        end
    end
end

local function rendreIncantation()
    for f, a in pairs(cachees) do f:SetAlpha(a) end
    wipe(cachees)
end

local function texteTitre()
    local f = _G.ProfessionsFrame
    if f and f.GetTitleText then
        local ok, t = pcall(f.GetTitleText, f)
        if ok and t and t.GetText then return t end
    end
    local t = _G.TradeSkillFrameTitleText
    if t and t.GetText then return t end
end

local function majTitre(reste)
    local t = texteTitre()
    if not t then return end
    local avant = t:GetText()
    if not avant then return end
    local apres = Fabrication.titre(avant, R("fabTitre") and reste or nil)
    if apres ~= avant then t:SetText(apres) end
end

---------------------------------------------------------------------------
-- La série
---------------------------------------------------------------------------

local function arreter(finie)
    serie = nil
    if ecoute then ecoute:UnregisterAllEvents() end
    if veille then veille:Cancel(); veille = nil end
    rendreIncantation()
    majTitre(nil)
    if finie and R("fabSon") and PlaySound then
        pcall(PlaySound, (SOUNDKIT and SOUNDKIT.IG_QUEST_LIST_COMPLETE) or 878, "Master")
    end
    if barre then barre:Hide() end
end
Fabrication.arreter = arreter

local function montrer()
    if not (barre and serie) then return end
    habiller(barre)
    remplir(barre, serie.icone, serie.nom, serie.faits, serie.nombre)
    poserReperes(barre, serie.nombre, serie.faits, function(i) return Fabrication.repere(serie, i) end)
    cacherIncantation()
    barre:Show()
end

local function sortVise()
    local _, _, _, _, _, _, _, _, id = UnitCastingInfo("player")
    return id
end

-- Le jeu annonce un arrêt (fenêtre fermée, mouvement...) : la série peut
-- pourtant continuer ; on coupe seulement si plus rien ne s'incante.
local function arretAnnonce()
    local s = serie
    s.arret = GetTime()
    C_Timer.After(Fabrication.GRACE, function()
        if serie == s and s.arret and sortVise() ~= s.recette then arreter(false) end
    end)
end

local function surEvenement(_, e, _, _, sort)
    if not serie then return end
    if e == "UPDATE_TRADESKILL_CAST_STOPPED" then return arretAnnonce() end
    if sort ~= serie.recette then return end
    local maintenant = GetTime()
    if e == "UNIT_SPELLCAST_START" then
        local _, _, _, debutMs, finMs = UnitCastingInfo("player")
        Fabrication.debutIncantation(serie, maintenant, debutMs, finMs)
        poserReperes(barre, serie.nombre, serie.faits, function(i) return Fabrication.repere(serie, i) end)
        return
    end
    if e == "UNIT_SPELLCAST_SUCCEEDED" then
        if Fabrication.reussie(serie, maintenant) then return arreter(true) end
        montrer()
        if serie.arret then arretAnnonce() end
        return
    end
    -- Échec pendant que la même recette s'incante encore : sans effet.
    if e == "UNIT_SPELLCAST_FAILED" and sortVise() == serie.recette then return end
    arreter(false)
end

local function dureeIncantation(id)
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, i = pcall(C_Spell.GetSpellInfo, id)
        if ok and type(i) == "table" then return (i.castTime or 0) / 1000 end
    end
    if GetSpellInfo then
        local ok, _, _, _, ms = pcall(GetSpellInfo, id)
        if ok and ms then return ms / 1000 end
    end
    return 0
end

-- Lancement depuis la fenêtre de métier (« Créer », « Créer tout »).
local function surFabrication(recette, nombre)
    if R("fabActif") ~= true or not barre then return end
    local info
    if C_TradeSkillUI.GetRecipeInfo then
        local ok, i = pcall(C_TradeSkillUI.GetRecipeInfo, recette)
        if ok and type(i) == "table" then info = i end
    end
    nombre = tonumber(nombre) or 1
    -- Pas plus que ce que les composants permettent.
    if info and (info.numAvailable or 0) > 0 then nombre = math.min(nombre, info.numAvailable) end
    local nom, icone = info and info.name, info and info.icon
    if not nom and C_Spell and C_Spell.GetSpellInfo then
        local ok, i = pcall(C_Spell.GetSpellInfo, recette)
        if ok and type(i) == "table" then nom, icone = i.name, icone or i.iconID end
    end
    local s = Fabrication.nouvelle(recette, nombre, dureeIncantation(recette), GetTime(), nom, icone)
    if not s then return end
    arreter(false)
    serie = s
    for _, e in ipairs(EVENEMENTS) do ecoute:RegisterUnitEvent(e, "player") end
    ecoute:RegisterEvent("UPDATE_TRADESKILL_CAST_STOPPED")
    veille = C_Timer.NewTicker(1, function()
        if serie and Fabrication.perimee(serie, GetTime()) then arreter(false) end
    end)
    montrer()
end

local function image(self)
    if not serie then return end
    cacherIncantation()
    local maintenant = GetTime()
    local reste = Fabrication.restant(serie, maintenant)
    avancer(self, Fabrication.part(serie, maintenant), reste)
    majTitre(reste)
end

---------------------------------------------------------------------------
-- Aperçu, réglages, création
---------------------------------------------------------------------------

function Fabrication.vitrine()
    if not copie then
        copie = construire(nil)
        if apercu then montrerExemple(copie) end
    end
    return copie, "fabrication", true
end

function Fabrication.apercu(oui)
    apercu = oui and true or false
    if not copie then return end
    if apercu then montrerExemple(copie) else copie:Hide() end
end

function Fabrication.recentrer()
    if ns.Deplacement then ns.Deplacement.remettre("fabrication") end
end

-- Naowh Forever a son propre minuteur de série : deux barres pour la même
-- série, non. Le nôtre allumé : le sien est coupé (réglage de Naowh). Le
-- nôtre coupé : le sien revient, seulement si c'est nous qui l'avions coupé.
local function reglagesNaowh()
    local n = _G.NaowhForever
    local S = n and n.ProfessionSettings
    if type(S) == "table" and S.Get and S.Set then return S end
end

function Fabrication.accorderNaowh()
    local S = reglagesNaowh()
    if not S then return end
    local ok, sien = pcall(S.Get, "craftTimer")
    if not ok then return end
    if R("fabActif") == true then
        if sien and pcall(S.Set, "craftTimer", false) then SuperGuideDB.fabNaowhCoupe = true end
    elseif SuperGuideDB.fabNaowhCoupe then
        SuperGuideDB.fabNaowhCoupe = nil
        if not sien then pcall(S.Set, "craftTimer", true) end
    end
end

function Fabrication.appliquer(cle)
    if type(cle) ~= "string" or not cle:match("^fab") then return end
    if cle == "fabActif" then Fabrication.accorderNaowh() end
    if cle == "fabActif" and R("fabActif") ~= true then arreter(false) end
    if cle == "fabBarreNormale" then
        if R("fabBarreNormale") then rendreIncantation() elseif serie then cacherIncantation() end
    end
    if cle == "fabTitre" and not R("fabTitre") then majTitre(nil) end
    if barre and serie then montrer() end
    if copie and apercu then montrerExemple(copie) end
end

function Fabrication.creer()
    barre = construire("SuperGuideFabrication")
    habiller(barre)
    barre:SetScript("OnUpdate", image)
    ecoute = CreateFrame("Frame")
    ecoute:SetScript("OnEvent", surEvenement)
    if ns.Deplacement then
        ns.Deplacement.inscrire(barre, L["Fabrication"], "fabrication", { "TOP", 0, -150 })
    end
    Fabrication.accorderNaowh()
    if C_TradeSkillUI and C_TradeSkillUI.CraftRecipe then
        hooksecurefunc(C_TradeSkillUI, "CraftRecipe", surFabrication)
        if C_TradeSkillUI.StopRecipeRepeat then
            hooksecurefunc(C_TradeSkillUI, "StopRecipeRepeat", function() if serie then arreter(false) end end)
        end
    end
end
