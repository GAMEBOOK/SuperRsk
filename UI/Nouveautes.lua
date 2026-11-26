-- Nouveautés : après une mise à jour, les joueurs qui avaient déjà SuperRsk
-- voient en une fenêtre ce qui est arrivé depuis leur dernière version,
-- avec la case pour l'allumer et un bouton « Voir ». Rien ne s'allume sans
-- eux : on montre, on ne force pas.
-- Une seule fois par version (SuperGuideDB.versionVue). Un nouveau joueur a
-- la fenêtre de bienvenue à la place. /sg nouveautes la rouvre.
-- Méthode de travail : une nouveauté qui compte a sa ligne dans LISTE (la
-- plus récente en haut) ; une simple correction n'en a pas.

local ADDON, ns = ...

local Nouveautes = {}
ns.Nouveautes = Nouveautes

local L = ns.L or setmetatable({}, { __index = function(_, k) return k end })

-- Avant cette fenêtre, on ne savait pas ce que le joueur avait vu : on
-- part de la 1.0.15 (avant la barre de réputation).
Nouveautes.DEPART = "1.0.15"

local function ouvrirMenu(nom)
    return function() if ns.Menu then ns.Menu.ouvrir(nom) end end
end

-- { version, nom, texte, cle (réglage à cocher, facultatif), voir (facultatif) }
Nouveautes.LISTE = {
    { version = "1.0.23", nom = L["Swap layer : combien de swaps il te reste"], cle = "swapCompteur",
      texte = L["Le jeu limite les changements de couche à 10 par heure. À côté des boutons du swap : tes swaps de l'heure, et l'attente quand c'est plein."],
      voir = ouvrirMenu("module:swapGroupe") },
    { version = "1.0.23", nom = L["Aperçus en direct"],
      texte = L["En haut de chaque page du menu, l'aperçu est une copie : ton vrai élément reste à sa place et suit tes réglages en direct."] },
    { version = "1.0.23", nom = L["Monnaies : ton or et tes monnaies"], cle = "monnaiesActif",
      texte = L["Un widget à placer où tu veux : ton or, ton honneur, tes réals... Tu coches les monnaies, tu choisis la taille et la disposition."],
      voir = ouvrirMenu("module:monnaies") },
    { version = "1.0.23", nom = L["Météo et effets : la pluie s'en va"], cle = "meteoActif",
      texte = L["Gouttes coupées, bruit de la pluie en option, et d'autres effets à couper un par un. Macro anti-brume (gourmande en FPS)."],
      voir = ouvrirMenu("module:meteo") },
    { version = "1.0.21", nom = L["Auto Sets : ton équipement revient"],
      texte = L["Ton équipement normal revient toujours, même après une reconnexion en selle. Et Auto Sets marche maintenant dans toutes les langues du jeu."] },
    { version = "1.0.21", nom = L["Poubelle : choisis l'objet"], cle = "butinPoubelle",
      texte = L["Sacs pleins : les flèches ‹ › proposent un autre objet. Tes matériaux d'artisanat (cuir, étoffes, minerais) ne sont plus jamais proposés."] },
    { version = "1.0.18", nom = L["Outils de métier protégés"],
      texte = L["Pioche, couteau à dépecer, marteau, cannes à pêche... ne sont plus jamais proposés à la vente ni à la poubelle."] },
    { version = "1.0.17", nom = "Auto Sets", cle = "tenuesActif",
      texte = L["Des tenues qui se mettent seules : en selle, à la récolte, au métier, contre un boss... puis ton équipement revient."],
      voir = function() if ns.TenuesUI then ns.TenuesUI.basculer() end end },
    { version = "1.0.16", nom = L["Cadenas"],
      texte = L["En haut du menu, à côté de Déplacer : verrouille barres et fenêtres. Maj enfoncée, tu les bouges quand même."],
      voir = ouvrirMenu("accueil") },
    { version = "1.0.15", nom = L["Barre de réputation"], cle = "barreRep",
      texte = L["Ta faction suivie dans sa propre barre : rang, progression, réputation par heure."],
      voir = ouvrirMenu("module:barreRep") },
}

-- « 1.0.19 » → { 1, 0, 19 } ; a plus récente que b ?
local function parties(v)
    local t = {}
    for n in tostring(v or ""):gmatch("%d+") do t[#t + 1] = tonumber(n) end
    return t
end
function Nouveautes.plusRecente(a, b)
    local x, y = parties(a), parties(b)
    for i = 1, math.max(#x, #y) do
        local p, q = x[i] or 0, y[i] or 0
        if p ~= q then return p > q end
    end
    return false
end

-- Ce qui est arrivé après la version vue (tout, sans version vue).
function Nouveautes.depuis(vue)
    local r = {}
    for _, n in ipairs(Nouveautes.LISTE) do
        if not vue or Nouveautes.plusRecente(n.version, vue) then r[#r + 1] = n end
    end
    return r
end

function Nouveautes.version()
    local f = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    return f and f(ADDON, "Version") or "0"
end

---------------------------------------------------------------------------
-- Fenêtre
---------------------------------------------------------------------------

local LARGEUR = 540
local cadre, contenu, lignes = nil, nil, {}
local enAttente   -- liste à montrer après le combat

local function T() return ns.Theme end
local function C() return ns.Controles end

local function enCombat()
    return InCombatLockdown() or (UnitAffectingCombat and UnitAffectingCombat("player"))
end

local function creer()
    local Th = T()
    cadre = CreateFrame("Frame", "SuperGuideNouveautes", UIParent)
    cadre:SetSize(LARGEUR, 300)
    cadre:SetPoint("CENTER", 0, 60)
    cadre:SetFrameStrata("DIALOG")
    cadre:SetClampedToScreen(true)
    cadre:EnableMouse(true)
    cadre:SetMovable(true)
    cadre:RegisterForDrag("LeftButton")
    cadre:SetScript("OnDragStart", cadre.StartMoving)
    cadre:SetScript("OnDragStop", cadre.StopMovingOrSizing)
    Th.fond(cadre, "panneau", 0.98, "bordFort")
    if UISpecialFrames then table.insert(UISpecialFrames, "SuperGuideNouveautes") end

    local bandeau = CreateFrame("Frame", nil, cadre)
    bandeau:SetPoint("TOPLEFT")
    bandeau:SetPoint("TOPRIGHT")
    bandeau:SetHeight(58)
    local b = C().marque(bandeau, bandeau, 6)
    b.logo:SetPoint("LEFT", 26, 0)
    local trait = bandeau:CreateTexture(nil, "ARTWORK")
    trait:SetColorTexture(Th.rgb("bordFort"))
    trait:SetHeight(1)
    trait:SetPoint("BOTTOMLEFT", 20, 0)
    trait:SetPoint("BOTTOMRIGHT", -20, 0)

    cadre.titre = C().texte(cadre, "grand", "texte")
    cadre.titre:SetPoint("TOPLEFT", 28, -72)
    cadre.sous = C().texte(cadre, "texte", "texteDoux")
    cadre.sous:SetPoint("TOPLEFT", cadre.titre, "BOTTOMLEFT", 0, -6)

    contenu = CreateFrame("Frame", nil, cadre)
    contenu:SetPoint("TOPLEFT", 28, -128)
    contenu:SetPoint("RIGHT", -28, 0)
    contenu:SetHeight(10)

    local ok = C().bouton(cadre, L["Compris"], "accent", function() cadre:Hide() end, 130)
    ok.texte:SetTextColor(Th.rgb("accent"))
    ok:SetPoint("BOTTOMRIGHT", -20, 20)
    local menu = C().bouton(cadre, L["Ouvrir le menu"], "texte", function()
        cadre:Hide()
        if ns.Menu then ns.Menu.ouvrir("accueil") end
    end, 130)
    menu:SetPoint("RIGHT", ok, "LEFT", -8, 0)

    local fermer = CreateFrame("Button", nil, cadre)
    fermer:SetSize(22, 22)
    fermer:SetPoint("TOPRIGHT", -10, -10)
    local x = fermer:CreateTexture(nil, "ARTWORK")
    x:SetTexture(Th.icone("fermer"))
    x:SetSize(12, 12)
    x:SetPoint("CENTER")
    x:SetVertexColor(Th.rgb("texteDoux"))
    fermer:SetFrameLevel(bandeau:GetFrameLevel() + 10)
    fermer:RegisterForClicks("LeftButtonUp")
    fermer:SetScript("OnClick", function() cadre:Hide() end)
    fermer:SetScript("OnEnter", function() x:SetVertexColor(Th.rgb("rouge")) end)
    fermer:SetScript("OnLeave", function() x:SetVertexColor(Th.rgb("texteDoux")) end)
    cadre:Hide()
end

-- Une ligne : la case (ou le nom), la phrase dessous, « Voir » à droite.
local function ligne(n, y)
    local Th = T()
    local f = CreateFrame("Frame", nil, contenu)
    f:SetPoint("TOPLEFT", 0, y)
    f:SetPoint("RIGHT")
    local tete
    if n.cle then
        local o = ns.Reglages.option(n.cle) or { cle = n.cle, type = "case" }
        tete = C().case(f, { cle = o.cle, type = "case", inverse = o.inverse, libelle = n.nom, info = n.texte }, 300)
        f.maj = tete.maj
        if tete.maj then tete.maj() end
    else
        tete = C().texte(f, "texte", "accent")
        tete:SetText(n.nom)
    end
    tete:SetPoint("TOPLEFT")
    local d = C().texte(f, "petit", "texteDoux")
    d:SetPoint("TOPLEFT", 0, -24)
    d:SetWidth(LARGEUR - 56 - 90)
    d:SetWordWrap(true)
    d:SetSpacing(2)
    d:SetText(n.texte)
    if n.voir then
        local v = C().bouton(f, L["Voir"], "texte", function()
            cadre:Hide()
            n.voir()
        end, 76)
        v:SetPoint("TOPRIGHT", 0, -2)
    end
    local h = 24 + math.max(16, d:GetStringHeight() or 16) + 14
    f:SetHeight(h)
    return f, h
end

function Nouveautes.ouvrir(liste)
    liste = liste or Nouveautes.depuis(nil)
    if #liste == 0 then return end
    if enCombat() then enAttente = liste; return end
    enAttente = nil
    if not cadre then creer() end
    if ns.Menu and ns.Menu.ouvert and ns.Menu.ouvert() then ns.Menu.fermer() end
    for _, l in ipairs(lignes) do l:Hide() end
    lignes = {}
    cadre.titre:SetText(L["Quoi de neuf ?"])
    cadre.sous:SetText(L["SuperRsk %s : ce qui est arrivé depuis ta dernière version."]:format(Nouveautes.version()))
    local y = 0
    for i, n in ipairs(liste) do
        if i > 6 then break end
        local f, h = ligne(n, y)
        lignes[#lignes + 1] = f
        y = y - h
    end
    contenu:SetHeight(-y)
    cadre:SetHeight(128 - y + 64)
    cadre:Show()
end

-- À l'arrivée en jeu : la fenêtre si une nouveauté est arrivée depuis la
-- dernière version vue. Vue une fois, même fermée sans lire.
function Nouveautes.demarrer()
    SuperGuideDB = SuperGuideDB or {}
    local db = SuperGuideDB
    local actuelle = Nouveautes.version()
    if not db.bienvenueVue then
        db.versionVue = actuelle   -- nouveau joueur : la bienvenue suffit
        return
    end
    local liste = Nouveautes.depuis(db.versionVue or Nouveautes.DEPART)
    db.versionVue = actuelle
    if #liste > 0 then ns.Jeu.plusTard(6, function() Nouveautes.ouvrir(liste) end) end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:SetScript("OnEvent", function()
    if enAttente then Nouveautes.ouvrir(enAttente) end
end)
