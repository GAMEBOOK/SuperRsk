-- Points de vol : icônes sur la carte du monde (fournisseur de données de la
-- carte, comme ceux de Blizzard). Connu = icône d'origine, orange = à découvrir.
-- Données : bibliothèque FlightMasterData (Libs/), choix dans Core/Vols.lua.

local ADDON, ns = ...

local Vols = ns.Vols
local L = ns.L or setmetatable({}, { __index = function(_, k) return k end })
local function R(cle) return ns.Reglages.get(cle) end

local MODELE = "SuperGuideVolPinTemplate" -- UI/Vols.xml
local ICONE = "Interface\\Minimap\\Tracking\\FlightMaster"
local CONNU, INCONNU = { 1, 1, 1 }, { 1, 0.6, 0.15 } -- blanc = couleurs d'origine
-- Tours JcJ, bateaux, zeppelins : nos icônes (Media/Icones), sans vol à apprendre.
local GENRE = { 1, 1, 1 } -- couleurs dans l'image
local function texteGenre(g)
    if g == "tour" then return L["Tour JcJ : pas de maître de vol à découvrir."] end
    if g == "bateau" then return L["Bateau : pas de maître de vol à découvrir."] end
    return L["Zeppelin : pas de maître de vol à découvrir."]
end

local fournisseur

-- Points connus de ce personnage : { [nodeID] = true }.
local function connus()
    SuperGuideCharDB.volsConnus = SuperGuideCharDB.volsConnus or {}
    return SuperGuideCharDB.volsConnus
end

---------------------------------------------------------------------------
-- Icône (modèle XML UI/Vols.xml). La carte du jeu se charge après nous :
-- MapCanvasPinTemplate n'existe pas encore, on ne l'hérite donc pas ; ses
-- méthodes (MapCanvasPinMixin) sont ajoutées aux nôtres à l'accrochage.
---------------------------------------------------------------------------

local Icone = {}
SuperGuideVolPinMixin = Icone

function Icone:OnLoad()
    if self.UseFrameLevelType then pcall(self.UseFrameLevelType, self, "PIN_FRAME_LEVEL_FLIGHT_POINT") end
    if self.SetScalingLimits then self:SetScalingLimits(1, 1.0, 1.2) end
    -- Survol seulement : les clics vont à la carte.
    if self.SetMouseClickEnabled then self:SetMouseClickEnabled(false) end
end

function Icone:OnAcquired(p)
    self.point = p
    self:SetPosition(p.x, p.y)
    if p.genre then
        self.Icone:SetTexture(ns.Theme.icone(p.genre))
        self.Icone:SetVertexColor(unpack(GENRE))
    else
        self.Icone:SetTexture(ICONE)
        self.Icone:SetVertexColor(unpack(p.connu and CONNU or INCONNU))
    end
end

function Icone:OnMouseEnter()
    local p = self.point
    if not p then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(p.nom or "?")
    local c = p.connu and CONNU or INCONNU
    if p.genre then
        GameTooltip:AddLine(texteGenre(p.genre), 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
        return
    end
    GameTooltip:AddLine(p.connu and L["Point de vol connu"] or L["Point de vol à découvrir"], c[1], c[2], c[3])
    GameTooltip:Show()
end

function Icone:OnMouseLeave() GameTooltip:Hide() end

---------------------------------------------------------------------------
-- Carte
---------------------------------------------------------------------------

-- Pose les icônes de la carte affichée (carte = WorldMapFrame ou équivalent).
function Vols.poser(carte)
    carte:RemoveAllPinsByTemplate(MODELE)
    if not R("volsCarte") then return end
    local id = carte:GetMapID()
    -- Si la carte du jeu sait ce qui est découvert, on le retient aussi.
    if id and C_TaxiMap and C_TaxiMap.GetTaxiNodesForMap then
        local ok, noeuds = pcall(C_TaxiMap.GetTaxiNodesForMap, id)
        if ok then Vols.noterDecouverts(connus(), noeuds) end
    end
    for _, p in ipairs(Vols.points(_G.FlightMasterData_API, id, connus(), R("volsAvecConnus"))) do
        carte:AcquirePin(MODELE, p)
    end
end

local function rafraichir()
    if fournisseur and fournisseur.GetMap and fournisseur:GetMap() then fournisseur:RefreshAllData() end
end

---------------------------------------------------------------------------
-- Vol en cours : destination et temps (appris par trajet, pour tout le compte)
---------------------------------------------------------------------------

local prevu, enCours

local function durees()
    SuperGuideDB.volsDurees = SuperGuideDB.volsDurees or {}
    return SuperGuideDB.volsDurees
end

-- Trajet choisi chez le maître de vol (TakeTaxiNode) ; il commence quand on
-- est vraiment sur le taxi.
function Vols.decollage(origine, destination, nom)
    prevu = { o = origine, d = destination, nom = nom }
end

-- Appelé à chaque image de la flèche : { ecoule, restant?, destination? } en
-- vol, sinon nil. À l'atterrissage, la durée du trajet est retenue.
function Vols.enVol()
    local now = GetTime()
    if ns.Jeu.surTaxi() then
        if not enCours then enCours, prevu = { debut = now, trajet = prevu }, nil end
        local tr = enCours.trajet
        local ecoule = now - enCours.debut
        local duree = tr and Vols.dureeConnue(durees(), tr.o, tr.d)
        return { ecoule = ecoule, restant = duree and duree - ecoule or nil, destination = tr and tr.nom }
    end
    if enCours then
        local tr = enCours.trajet
        if tr then Vols.apprendre(durees(), tr.o, tr.d, now - enCours.debut) end
        enCours = nil
    end
end

-- TakeTaxiNode(emplacement) : on retrouve le départ (nœud « actuel ») et
-- l'arrivée sur la carte du maître de vol.
local function surTakeTaxiNode(emplacement)
    if not (C_TaxiMap and C_TaxiMap.GetAllTaxiNodes) then return end
    local carte = (GetTaxiMapID and GetTaxiMapID()) or (C_Map and C_Map.GetBestMapForUnit("player"))
    local ok, noeuds = pcall(C_TaxiMap.GetAllTaxiNodes, carte)
    if not ok then return end
    local actuel = Enum and Enum.FlightPathState and Enum.FlightPathState.Current or 0
    local o, d
    for _, n in ipairs(noeuds or {}) do
        if n.state == actuel then o = n end
        if n.slotIndex == emplacement then d = n end
    end
    if d then Vols.decollage(o and o.nodeID, d.nodeID, d.name) end
end

local function etat(nom, defaut)
    return Enum and Enum.FlightPathState and Enum.FlightPathState[nom] or defaut
end

-- Carte d'un maître de vol ouverte : on note ce que ce personnage connaît.
function Vols.surCarteVol()
    if not (C_TaxiMap and C_TaxiMap.GetAllTaxiNodes) then return end
    local carte = (GetTaxiMapID and GetTaxiMapID()) or (C_Map and C_Map.GetBestMapForUnit("player"))
    local ok, noeuds = pcall(C_TaxiMap.GetAllTaxiNodes, carte)
    if not ok then return end
    Vols.noterConnus(connus(), noeuds, etat("Unreachable", 2))
    rafraichir()
end

local REACTIONS = { TAXIMAP_OPENED = function() Vols.surCarteVol() end }

function Vols.surEvenement(e)
    if REACTIONS[e] then REACTIONS[e]() end
end

function Vols.appliquer(cle)
    if cle:find("^vols") then rafraichir() end
end

-- S'accroche à la carte du monde si elle est chargée ; true une fois fait.
function Vols.attacher()
    if fournisseur then return true end
    if not (WorldMapFrame and WorldMapFrame.AddDataProvider and CreateFromMixins and MapCanvasDataProviderMixin) then
        return false
    end
    -- Méthodes de Blizzard d'abord, les nôtres par-dessus.
    SuperGuideVolPinMixin = CreateFromMixins(MapCanvasPinMixin or {}, Icone)
    fournisseur = CreateFromMixins(MapCanvasDataProviderMixin)
    function fournisseur:RemoveAllData() self:GetMap():RemoveAllPinsByTemplate(MODELE) end
    function fournisseur:RefreshAllData() Vols.poser(self:GetMap()) end
    WorldMapFrame:AddDataProvider(fournisseur)
    return true
end

-- Carte pas encore chargée : on attend les chargements d'addons de Blizzard.
function Vols.creer()
    if hooksecurefunc and TakeTaxiNode then hooksecurefunc("TakeTaxiNode", surTakeTaxiNode) end
    -- TAXIMAP_OPENED arrive par Core/Init.lua (Vols.surCarteVol).
    if Vols.attacher() then return end
    local attente = CreateFrame("Frame")
    attente:RegisterEvent("ADDON_LOADED")
    attente:SetScript("OnEvent", function(self)
        if Vols.attacher() then self:UnregisterEvent("ADDON_LOADED") end
    end)
end
