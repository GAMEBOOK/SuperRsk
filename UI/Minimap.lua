-- Bouton rond sur le bord de la minicarte : clic gauche = menu principal,
-- glisser = le déplacer autour.
-- Angle gardé dans SuperGuideDB.minimapAngle ; réglage « Bouton sur la minicarte ».

local ADDON, ns = ...

local Minimap_ = {}
ns.Minimap = Minimap_
local L = ns.L or setmetatable({}, { __index = function(_, k) return k end })

local ANGLE = 225   -- position par défaut : en bas à gauche
local RAYON = 80
local bouton

-- Décalage depuis le centre de la minicarte pour un angle en degrés.
function Minimap_.position(angle, rayon)
    local a = math.rad(angle)
    return math.cos(a) * rayon, math.sin(a) * rayon
end

-- Angle (0 à 360) d'un point vu depuis le centre.
function Minimap_.angle(dx, dy)
    return math.deg((math.atan2 or math.atan)(dy, dx)) % 360
end

local function placer()
    local x, y = Minimap_.position(SuperGuideDB.minimapAngle or ANGLE, RAYON)
    bouton:ClearAllPoints()
    bouton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function suivreCurseur()
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local s = Minimap:GetEffectiveScale()
    SuperGuideDB.minimapAngle = Minimap_.angle(cx / s - mx, cy / s - my)
    placer()
end

-- EllesmereUI (Minimap) range tous les boutons de la minicarte dans son
-- menu, sauf ceux de sa liste « dégroupés » (le sien et BugSack sur
-- Forever). On s'y inscrit une seule fois : si tu le regroupes ensuite
-- dans ses options, on ne revient pas dessus.
local function sortirDuGroupeEllesmere()
    if SuperGuideDB.ellesmereDegroupe then return end
    local db = _G._EMM_DB
    local mp = db and db.profile and db.profile.minimap
    if type(mp) ~= "table" then return end
    if type(mp.ungroupedButtons) ~= "table" then mp.ungroupedButtons = {} end
    local ug = mp.ungroupedButtons
    if not ug.SuperGuideMinimap then
        local max = 0
        for _, ordre in pairs(ug) do
            if type(ordre) == "number" and ordre > max then max = ordre end
        end
        ug.SuperGuideMinimap = max + 1
        local refaire = _G._EMM_FullRebuildMinimap or _G._EMM_ApplyMinimap
        if refaire then pcall(refaire) end
    end
    SuperGuideDB.ellesmereDegroupe = true
end

function Minimap_.creer()
    if bouton or not Minimap then return end
    local T = ns.Theme
    bouton = CreateFrame("Button", "SuperGuideMinimap", Minimap)
    bouton:SetSize(31, 31)
    bouton:SetFrameStrata("MEDIUM")
    bouton:SetFrameLevel(8)
    bouton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    bouton:RegisterForDrag("LeftButton")
    bouton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local fond = bouton:CreateTexture(nil, "BACKGROUND")
    fond:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    fond:SetSize(20, 20)
    fond:SetPoint("TOPLEFT", 7, -5)
    local icone = bouton:CreateTexture(nil, "ARTWORK")
    icone:SetTexture(T.icone("boussole"))
    icone:SetVertexColor(T.rgb("accent"))
    icone:SetSize(15, 15)
    icone:SetPoint("TOPLEFT", 9, -8)
    local bord = bouton:CreateTexture(nil, "OVERLAY")
    bord:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    bord:SetSize(53, 53)
    bord:SetPoint("TOPLEFT")
    -- Au survol : la boussole fait un tour, une lueur s'allume.
    ns.Controles.animerLogo(icone, bouton, 34, false)

    bouton:SetScript("OnClick", function(_, b)
        ns.Menu.basculer()
    end)
    bouton:SetScript("OnDragStart", function(self)
        if ns.Deplacement.bloque() then return end
        self:SetScript("OnUpdate", suivreCurseur)
    end)
    bouton:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    bouton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("SuperRsk", 1, 1, 1)
        GameTooltip:AddLine(L["Clic gauche : menu principal"], 0.7, 0.75, 0.8)
        GameTooltip:AddLine(L["Glisser : déplacer ce bouton"], 0.7, 0.75, 0.8)
        GameTooltip:Show()
    end)
    bouton:SetScript("OnLeave", function() GameTooltip:Hide() end)

    placer()
    if ns.Reglages.get("minimapCache") then bouton:Hide() end
    -- Après le premier passage d'EllesmereUI sur la minicarte.
    C_Timer.After(2, sortirDuGroupeEllesmere)
    ns.Reglages.ecouter(function(cle, v)
        if cle == "minimapCache" then
            if v then bouton:Hide() else bouton:Show() end
        elseif cle == "positions" then
            placer()
        end
    end)
end
