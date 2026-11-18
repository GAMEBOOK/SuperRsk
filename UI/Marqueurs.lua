-- Marqueurs : bouton sécurisé (invisible) qui pose les symboles voulus, le
-- mien et ceux de la liste. Le jeu interdit à un addon de poser un symbole
-- tout seul (SetRaidTarget) : il faut une action du joueur, donc une touche
-- (Raccourcis > SuperRsk) ou la macro « SG Symboles ».
-- Décisions dans Core/Marqueurs.lua.

local ADDON, ns = ...

local Marqueurs = ns.Marqueurs
local L = ns.L or setmetatable({}, { __index = function(_, k) return k end })
local function R(cle) return ns.Reglages.get(cle) end

local NOM_MACRO = "SG Symboles"
local bouton
local enAttente = false

function Marqueurs.personnes()
    SuperGuideDB = SuperGuideDB or {}
    SuperGuideDB.marqueursListe = Marqueurs.liste(SuperGuideDB.marqueursListe)
    return SuperGuideDB.marqueursListe
end

local function texte()
    return R("marqueursActif") and Marqueurs.macro(R("marqueurMoi"), Marqueurs.personnes()) or ""
end

-- Une macro du jeu tient en 255 caractères : on garde les lignes entières
-- qui y entrent (moi d'abord). Vide : une ligne inerte, le jeu refuse une macro vide.
local function corpsMacro()
    local corps = ""
    for ligne in texte():gmatch("[^\n]+") do
        local suite = corps == "" and ligne or (corps .. "\n" .. ligne)
        if #suite > 255 then break end
        corps = suite
    end
    return corps ~= "" and corps or "#showtooltip"
end

-- Le bouton et la macro suivent les réglages ; rien ne change en combat
-- (mise à jour à la sortie).
function Marqueurs.maj()
    if not bouton then return end
    if InCombatLockdown() then enAttente = true; return end
    enAttente = false
    bouton:SetAttribute("macrotext", texte())
    local i = GetMacroIndexByName and GetMacroIndexByName(NOM_MACRO)
    if i and i > 0 then EditMacro(i, NOM_MACRO, nil, corpsMacro()) end
end

function Marqueurs.appliquer(cle)
    if cle == "marqueursActif" or cle == "marqueurMoi" or cle == "marqueursListe" then Marqueurs.maj() end
end

-- Macro de personnage avec les lignes « /tm » elles-mêmes (un « /click »
-- vers le bouton ne part pas selon le réglage d'appui des touches), mise
-- sur le curseur ; réécrite à chaque changement de réglage.
function Marqueurs.creerMacro()
    if InCombatLockdown() then
        ns.Jeu.message(L["Impossible en combat : réessaie après le combat."])
        return
    end
    local corps = corpsMacro()
    local i = GetMacroIndexByName(NOM_MACRO)
    if i and i > 0 then
        EditMacro(i, NOM_MACRO, nil, corps)
    else
        local ok, n = pcall(CreateMacro, NOM_MACRO, "INV_MISC_QUESTIONMARK", corps, true)
        if not ok or not n then
            ns.Jeu.message(L["Plus de place pour une macro de personnage : libères-en une et réessaie."])
            return
        end
        i = n
    end
    if PickupMacro then PickupMacro(i) end
    ns.Jeu.message(L["Macro « SG Symboles » prête : elle est sur ton curseur, pose-la sur ta barre. Un appui pose tes symboles."])
end

function Marqueurs.creer()
    bouton = CreateFrame("Button", "SuperGuideMarqueurs", UIParent, "SecureActionButtonTemplate")
    bouton:SetAttribute("type", "macro")
    bouton:RegisterForClicks("AnyUp", "AnyDown")
    bouton:Hide()
    _G["BINDING_NAME_CLICK SuperGuideMarqueurs:LeftButton"] = L["Poser mes symboles"]

    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    f:SetScript("OnEvent", function() if enAttente then Marqueurs.maj() end end)
    Marqueurs.maj()
end

---------------------------------------------------------------------------
-- Swap groupé : le bouton sous le panneau de LayerSwap (ou sous sa barre),
-- et sa touche (Raccourcis > SuperRsk). Décisions dans Core/Marqueurs.lua.
---------------------------------------------------------------------------

local Swap = ns.SwapGroupe
local barre, b1, b2

local TEXTES = { quitter = L["Quitter + swap"], demander = L["Swap !"] }
local AIDES = {
    quitter = L["Retient tes persos du groupe, les prévient et quitte le groupe. Reclique pour demander le swap."],
    demander = L["Demande un swap à LayerSwap (valide ensuite avec Entrée si la demande part dans la discussion)."],
}

local function aide(b, titre, texte)
    b:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(self.titre or titre)
        GameTooltip:AddLine(self.aide or texte, 1, 1, 1, true)
        GameTooltip:AddLine(L["Glisser : déplacer."], 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    b:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Bouton 2 sécurisé : en mode « symboles », sa macro pose les symboles
-- (comme la touche des Marqueurs) ; sinon il ne fait que notre clic.
-- Ses attributs ne changent pas en combat (repris à la sortie).
local attenteCombat = false
local function modeSecurise(mode)
    if InCombatLockdown() then attenteCombat = true; return end
    attenteCombat = false
    if mode == "symboles" then
        b2:SetAttribute("type", "macro")
        b2:SetAttribute("macrotext", texte())
    else
        b2:SetAttribute("type", nil)
    end
end

-- Les demandes faites par LayerSwap lui-même comptent aussi (une seule fois).
local branche = {}
local function brancherLayerSwap()
    if not hooksecurefunc then return end
    if not branche.slash and SlashCmdList and SlashCmdList.LAYERSWAP then
        branche.slash = true
        hooksecurefunc(SlashCmdList, "LAYERSWAP", function(m)
            if type(m) == "string" and m:lower():match("^%s*swap") then Swap.noterDemande() end
        end)
    end
    local b = _G.LayerSwapPanelSwapButton
    if not branche.bouton and b and b.HookScript then
        branche.bouton = true
        b:HookScript("OnClick", function() Swap.noterDemande() end)
    end
end

function Swap.rafraichir()
    if not barre then return end
    brancherLayerSwap()
    local e2 = Swap.etape2()
    if b2.mode ~= e2 or attenteCombat then modeSecurise(e2) end
    b2.mode = e2
    if R("swapGroupeActif") == false or not Swap.layerSwap() then
        if not InCombatLockdown() then barre:Hide() end
        return
    end
    local e = Swap.etape()
    b1.texte:SetText(TEXTES[e]); b1.titre, b1.aide = TEXTES[e], AIDES[e]
    if e2 == "symboles" then
        b2.texte:SetText(L["Remettre les symboles"])
        b2.titre, b2.aide = L["Remettre les symboles"], L["Clique quand tes persos ont rejoint le groupe : pose ton symbole et ceux de ta liste."]
        b2:SetAlpha(1)
    else
        local n = Swap.nombreAlts()
        b2.texte:SetText(n > 0 and L["Valider mon layer (%d)"]:format(n) or L["Valider mon layer"])
        b2.titre, b2.aide = L["Valider mon layer"], L["Tu es sur la bonne couche : quitte le groupe de l'hôte et réinvite tes persos, qui acceptent seuls."]
        b2:SetAlpha(n > 0 and 1 or 0.5)
    end
    if not InCombatLockdown() then barre:Show() end
end

-- Bouton à liseré comme Controles.bouton, mais sécurisé (macro possible).
local function boutonSecurise(parent, nom, couleur, largeur)
    local b = CreateFrame("Button", nom, parent, "SecureActionButtonTemplate")
    b:SetSize(largeur, 24)
    local _, bord = ns.Theme.fond(b, "flot", 1, "bordFort")
    b.texte = ns.Controles.texte(b, "petit", couleur)
    b.texte:SetPoint("CENTER")
    b.texte:SetJustifyH("CENTER")
    b:HookScript("OnEnter", function() bord:SetVertexColor(ns.Theme.rgb(couleur)) end)
    b:HookScript("OnLeave", function() bord:SetVertexColor(ns.Theme.rgb("bordFort")) end)
    b:RegisterForClicks("AnyUp")
    return b
end

local function placer()
    local pos = SuperGuideDB and SuperGuideDB.swapPos
    barre:ClearAllPoints()
    if type(pos) == "table" and pos.point then
        barre:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
    else
        barre:SetPoint("TOP", UIParent, "TOP", 0, -146)
    end
end

local function glissable(b)
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnDragStart", function() barre:StartMoving() end)
    b:SetScript("OnDragStop", function()
        barre:StopMovingOrSizing()
        local point, _, _, x, y = barre:GetPoint()
        SuperGuideDB = SuperGuideDB or {}
        SuperGuideDB.swapPos = { point = point, x = x, y = y }
    end)
end

function Swap.creer()
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        pcall(C_ChatInfo.RegisterAddonMessagePrefix, Swap.PREFIXE)
    end
    Swap.charger()
    local C = ns.Controles
    barre = CreateFrame("Frame", "SuperGuideSwapBarre", UIParent)
    barre:SetSize(296, 24)
    barre:SetMovable(true)
    barre:SetClampedToScreen(true)
    barre:SetFrameStrata("HIGH")
    placer()
    b1 = C.bouton(barre, TEXTES.quitter, "accent", function() Swap.cliquer() end, 128)
    b1:SetPoint("LEFT")
    -- Nommé : sa touche (Raccourcis > SuperRsk) le clique, même barre cachée.
    b2 = boutonSecurise(barre, "SuperGuideSwapValider", "vert", 160)
    b2:SetPoint("LEFT", b1, "RIGHT", 8, 0)
    b2:HookScript("OnClick", function(self)
        if self.mode == "symboles" then Swap.symbolesPoses(); Swap.rafraichir()
        else Swap.cliquerValider() end
    end)
    aide(b1, TEXTES.quitter, AIDES.quitter)
    aide(b2, L["Valider mon layer"], "")
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    f:SetScript("OnEvent", function() if attenteCombat then Swap.rafraichir() end end)
    glissable(b1); glissable(b2)
    barre:Hide()

    -- Touches (Raccourcis > SuperRsk), même barre cachée.
    local t = CreateFrame("Button", "SuperGuideSwapGroupe", UIParent)
    t:RegisterForClicks("AnyDown")
    t:SetScript("OnClick", function() Swap.cliquer() end)
    t:Hide()
    _G["BINDING_NAME_CLICK SuperGuideSwapGroupe:LeftButton"] = L["Quitter le groupe + swap"]
    _G["BINDING_NAME_CLICK SuperGuideSwapValider:LeftButton"] = L["Valider mon layer, puis remettre les symboles"]

    Swap.rafraichir()
end

function Swap.appliquer(cle)
    if cle == "swapGroupeActif" then Swap.rafraichir() end
end
