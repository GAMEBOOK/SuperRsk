-- Auto Equip dans les sacs : flèche verte sur les objets qui sont une
-- amélioration, flèche dorée avec le niveau sur ceux qui le seront plus tard.
--
-- Sacs pris en charge : EllesmereUIBags (RegisterItemOverlayIcon), Baganator
-- (RegisterUpgradePlugin : sa propre flèche, améliorations immédiates
-- seulement) et les sacs du jeu. L'état vient de Equipement.etats, calculé
-- à chaque vérification (objet ramassé, combat fini, niveau gagné…).

local ADDON, ns = ...

local Fleches = {}
ns.FlechesSacs = Fleches

local TAILLE = 15
local marques = setmetatable({}, { __mode = "k" })   -- [bouton] = { fleche, niveau }
local cadresJeu = {}

local function atlasExiste(nom)
    return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(nom) ~= nil
end

-- Flèche (texture) et niveau (texte) dans un parent donné.
local function creerVisuel(parent, ancre)
    local f = parent:CreateTexture(nil, "OVERLAY", nil, 7)
    f:SetSize(TAILLE, TAILLE)
    if ancre then f:SetPoint("TOPLEFT", ancre, "TOPLEFT", 1, -1) else f:SetPoint("CENTER") end
    if atlasExiste("bags-greenarrow") then
        f:SetAtlas("bags-greenarrow")
    else
        f:SetTexture("Interface\\PetBattles\\BattleBar-AbilityBadge-Strong")
    end
    local n = parent:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    n:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 1, 2)
    n:SetTextColor(1, 0.82, 0.1)
    return { fleche = f, niveau = n }
end

local function marque(btn, parent)
    if not marques[btn] then marques[btn] = creerVisuel(parent or btn, btn) end
    return marques[btn]
end

-- Habille le visuel selon l'état ; faux si l'objet n'a pas de flèche.
local function habiller(m, e)
    if not e then m.fleche:Hide(); m.niveau:Hide(); return false end
    m.fleche:Show()
    if e.niveau then
        m.fleche:SetDesaturated(true)
        m.fleche:SetVertexColor(1, 0.82, 0.1)
        m.niveau:SetText(e.niveau)
        m.niveau:Show()
    else
        m.fleche:SetDesaturated(false)
        m.fleche:SetVertexColor(1, 1, 1)
        m.niveau:Hide()
    end
    return true
end

-- Pose (ou retire) la flèche d'un bouton d'après le lien de son objet.
function Fleches.peindre(btn, lien, parent)
    local e = lien and ns.Equipement.etat(lien)
    if not e then
        local m = marques[btn]
        if m then m.fleche:Hide(); m.niveau:Hide() end
        return
    end
    habiller(marque(btn, parent), e)
end

-- Sacs du jeu ---------------------------------------------------------------

local function lienDe(bag, slot)
    return bag and slot and C_Container and C_Container.GetContainerItemLink(bag, slot)
end

local function peindreCadreJeu(f)
    if not (f and f:IsShown()) then return end
    if f.EnumerateValidItems then
        for _, b in f:EnumerateValidItems() do
            local bag = b.GetBagID and b:GetBagID() or f:GetID()
            Fleches.peindre(b, lienDe(bag, b:GetID()))
        end
    elseif f.size and f.GetName and f:GetName() then
        for i = 1, f.size do
            local b = _G[f:GetName() .. "Item" .. i]
            if b then Fleches.peindre(b, lienDe(f:GetID(), b:GetID())) end
        end
    end
end

local function brancherJeu()
    local liste = { _G.ContainerFrameCombinedBags }
    for i = 1, (NUM_CONTAINER_FRAMES or 13) do liste[#liste + 1] = _G["ContainerFrame" .. i] end
    for _, f in pairs(liste) do
        if f and f.UpdateItems then
            hooksecurefunc(f, "UpdateItems", peindreCadreJeu)
            cadresJeu[#cadresJeu + 1] = f
        end
    end
    if #cadresJeu == 0 and type(ContainerFrame_Update) == "function" then
        hooksecurefunc("ContainerFrame_Update", peindreCadreJeu)
        for i = 1, (NUM_CONTAINER_FRAMES or 13) do
            local f = _G["ContainerFrame" .. i]
            if f then cadresJeu[#cadresJeu + 1] = f end
        end
    end
end

-- EllesmereUIBags et Baganator ----------------------------------------------

local function brancherEllesmere()
    local E = _G.EUI_Bags
    if not (E and E.RegisterItemOverlayIcon) then return end
    E.RegisterItemOverlayIcon("SuperRsk", function(btn, data)
        Fleches.peindre(btn, data and data.itemLink, btn._textOverlay)
    end)
end

-- Baganator : une icône de coin (en haut à droite par défaut, déplaçable
-- dans ses réglages « Icônes »), plus le module d'amélioration pour ses
-- catégories et sa recherche.
local function brancherBaganator()
    local B = _G.Baganator
    if not (B and B.API) then return end
    if B.API.RegisterCornerWidget then
        B.API.RegisterCornerWidget("SuperRsk : Auto Equip", "superrsk_auto_equip",
            function(cadre, details)
                return habiller(cadre.visuel, details and details.itemLink and ns.Equipement.etat(details.itemLink))
            end,
            function(bouton)
                local cadre = CreateFrame("Frame", nil, bouton)
                cadre:SetSize(TAILLE, TAILLE)
                cadre.visuel = creerVisuel(cadre)
                cadre.padding = 0
                return cadre
            end,
            { corner = "top_right", priority = 1 })
    end
    if B.API.RegisterUpgradePlugin then
        B.API.RegisterUpgradePlugin("SuperRsk (Auto Equip)", "superrsk", function(lien)
            local e = lien and ns.Equipement.etat(lien)
            return e ~= nil and not e.niveau
        end)
    end
end

-- Les améliorations ont changé : on redessine les sacs ouverts.
function Fleches.rafraichir()
    for _, f in ipairs(cadresJeu) do peindreCadreJeu(f) end
    local E = _G.EUI_Bags
    if E and E.IsShown and E:IsShown() and E.RefreshInventory then pcall(E.RefreshInventory, E) end
    local B = _G.Baganator
    if B and B.API and B.API.RequestItemButtonsRefresh then pcall(B.API.RequestItemButtonsRefresh) end
end

function Fleches.creer()
    for _, f in ipairs({ brancherJeu, brancherEllesmere, brancherBaganator }) do pcall(f) end
    ns.Equipement.surEtats = Fleches.rafraichir
end
