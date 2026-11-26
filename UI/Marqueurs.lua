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
-- Swap layer en groupe : le bouton sous le panneau de LayerSwap (ou sous sa barre),
-- et sa touche (Raccourcis > SuperRsk). Décisions dans Core/Marqueurs.lua.
---------------------------------------------------------------------------

local Swap = ns.SwapGroupe
local barre, b1, b2

local TEXTES = { quitter = L["Quitter le groupe"], demander = L["Swap layer"] }
local AIDES = {
    demander = L["Demande un swap à LayerSwap (valide ensuite avec Entrée si la demande part dans la discussion)."],
}

-- Infobulle du bouton de gauche en groupe : groupe de l'hôte ou de la team.
local function aideQuitter()
    if Swap.swapDemande() then
        return L["Tu es sur la bonne couche : quitte le groupe de l'hôte, puis invite ta team."]
    end
    return L["Quitte le groupe : ta team est prévenue et part aussi. Ensuite, clique sur Swap layer."]
end

-- Infobulle du bouton « Inviter la team » : qui sera invité.
local function aideInviter()
    local noms = Swap.aInviter()
    if #noms == 0 then
        return L["Aucun perso à inviter : ajoute tes persos dans la liste des Marqueurs (ou clique sur « Swap layer » quand tu es groupé avec eux)."]
    end
    return L["Invite ta team, qui accepte seule :"] .. "\n" .. table.concat(noms, "\n")
end

-- « 12 min », « 45 s » : temps avant la nouvelle heure de swaps.
local function duree(s)
    s = math.max(0, math.floor(s or 0))
    if s < 60 then return ("%d s"):format(s) end
    return ("%d min"):format(math.ceil(s / 60))
end

-- Compteur de swaps à droite des boutons : « 3/10 », en orange à partir de
-- 7, en rouge à 10 avec le temps d'attente.
local function majCompteur(w, c)
    local t = w.compteur
    if not t then return end
    if R("swapCompteur") == false or not c then t:Hide(); return end
    local texte = c.utilises .. "/" .. c.max
    local couleur = "texteDoux"
    if c.attente > 0 then
        texte, couleur = texte .. "  " .. duree(c.attente), "rouge"
    elseif c.utilises >= c.max - 3 then
        couleur = "orange"
    elseif c.utilises > 0 then
        couleur = "texte"
    end
    t:SetText(texte)
    t:SetTextColor(ns.Theme.rgb(couleur))
    t:Show()
end

-- Ligne de l'infobulle : swaps de l'heure et nouvelle heure.
local function ligneCompteur()
    if R("swapCompteur") == false then return end
    local c = Swap.compteur()
    local l1 = L["Swaps cette heure : %d sur %d."]:format(c.utilises, c.max)
    if c.attente > 0 then
        l1 = l1 .. " " .. L["Prochain swap possible dans %s."]:format(duree(c.attente))
    elseif c.fin then
        l1 = l1 .. " " .. L["Compteur remis à zéro dans %s."]:format(duree(c.fin))
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(l1, 1, 0.82, 0, true)
    GameTooltip:AddLine(L["Le jeu limite les changements de couche (10 par heure, mesuré par LayerSwap, qui compte tes swaps)."], 0.6, 0.6, 0.6, true)
end

local function aide(b, titre, texte)
    b:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(self.titre or titre)
        local t = self.aide or texte
        if type(t) == "function" then t = t() end
        GameTooltip:AddLine(t, 1, 1, 1, true)
        if self == b1 then ligneCompteur() end
        GameTooltip:AddLine(L["Glisser : déplacer."], 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    b:HookScript("OnLeave", function() GameTooltip:Hide() end)
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

local copieSwap, apercuSwap = nil, false
local construireBarre

-- Copie montrée dans la bannière d'aperçu du menu (la vraie reste en place) :
-- purement visuelle, boutons ordinaires sans effet ni souris.
function Swap.vitrine()
    if not copieSwap then copieSwap = construireBarre(nil, false) end
    return copieSwap, "swap", true
end

-- La copie montre l'exemple (Swap layer puis Quitter le groupe, en boucle) ;
-- la vraie barre n'est pas touchée.
function Swap.apercu(oui)
    apercuSwap = oui and true or false
    if not copieSwap then return end
    local w = copieSwap
    if apercuSwap then
        w:Show()
        local debut = GetTime()
        w:SetScript("OnUpdate", function()
            local quitter = math.floor((GetTime() - debut) / 1.6) % 2 == 0
            w.b1.texte:SetText(quitter and TEXTES.quitter or TEXTES.demander)
            w.b2.texte:SetText(L["Inviter la team (%d)"]:format(math.max(2, Swap.nombreAlts())))
            w.b2:SetAlpha(1)
            majCompteur(w, { utilises = 3, max = Swap.LIMITE, attente = 0 })
        end)
    else
        w:SetScript("OnUpdate", nil)
        w:Hide()
    end
end

function Swap.rafraichir()
    if not barre then return end
    brancherLayerSwap()
    if R("swapGroupeActif") == false or not Swap.layerSwap() then
        if not InCombatLockdown() then barre:Hide() end
        return
    end
    local e = Swap.etape()
    b1.texte:SetText(TEXTES[e])
    b1.titre, b1.aide = TEXTES[e], e == "quitter" and aideQuitter or AIDES.demander
    local n = Swap.nombreAlts()
    b2.texte:SetText(n > 0 and L["Inviter la team (%d)"]:format(n) or L["Inviter la team"])
    b2.titre, b2.aide = L["Inviter la team"], aideInviter
    b2:SetAlpha(n > 0 and 1 or 0.5)
    majCompteur(barre, Swap.compteur())
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

-- Position : par le mode Déplacer (ancienne position de la barre reprise).
local function placer()
    if not ns.Deplacement then
        barre:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 29, 234)
        return
    end
    ns.Deplacement.inscrire(barre, L["Swap layer en groupe"], "swap", { "BOTTOMLEFT", 29, 234 })
    SuperGuideDB = SuperGuideDB or {}
    if SuperGuideDB.swapPos then
        ns.Deplacement.reprendre("swap", SuperGuideDB.swapPos)
        SuperGuideDB.swapPos = nil
    end
end

-- Les boutons couvrent la barre : les glisser déplace la barre (même
-- enregistrement que le mode Déplacer).
local function glissable(b)
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnDragStart", function()
        local f = barre:GetScript("OnDragStart")
        if f then f(barre) else barre:StartMoving() end
    end)
    b:SetScript("OnDragStop", function()
        local f = barre:GetScript("OnDragStop")
        if f then f(barre) else barre:StopMovingOrSizing() end
    end)
end

-- Fabrique une barre à deux boutons. Vraie (reelle) : b1 lance le swap, b2
-- est sécurisé et nommé (sa touche le clique). Copie : deux boutons
-- ordinaires, sans rappel ni souris, rien de sécurisé.
construireBarre = function(nom, reelle)
    local C = ns.Controles
    local w = CreateFrame("Frame", nom, UIParent)
    w:SetSize(296, 24)
    w:SetClampedToScreen(true)
    w:SetFrameStrata("HIGH")
    w.b1 = C.bouton(w, TEXTES.demander, "accent", reelle and function() Swap.cliquer() end or nil, 128)
    w.b1:SetPoint("LEFT")
    if reelle then
        -- Nommé : sa touche (Raccourcis > SuperRsk) le clique, même barre cachée.
        w.b2 = boutonSecurise(w, "SuperGuideSwapValider", "vert", 160)
    else
        w.b2 = C.bouton(w, "", "vert", nil, 160)
        w.b1:EnableMouse(false)
        w.b2:EnableMouse(false)
    end
    w.b2:SetPoint("LEFT", w.b1, "RIGHT", 8, 0)
    w.compteur = C.texte(w, "petit", "texteDoux")
    w.compteur:SetPoint("LEFT", w.b2, "RIGHT", 8, 0)
    w:Hide()
    return w
end

function Swap.creer()
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        pcall(C_ChatInfo.RegisterAddonMessagePrefix, Swap.PREFIXE)
    end
    Swap.charger()
    barre = construireBarre("SuperGuideSwapBarre", true)
    barre:SetMovable(true)
    placer()
    b1, b2 = barre.b1, barre.b2
    b2:HookScript("OnClick", function() Swap.cliquerValider() end)
    aide(b1, TEXTES.demander, AIDES.demander)
    aide(b2, L["Inviter la team"], aideInviter)
    glissable(b1); glissable(b2)
    -- Le compteur suit l'heure qui passe (une fois par seconde).
    local ecoule = 0
    barre:SetScript("OnUpdate", function(_, dt)
        ecoule = ecoule + (dt or 0)
        if ecoule < 1 then return end
        ecoule = 0
        majCompteur(barre, Swap.compteur())
    end)

    -- Touches (Raccourcis > SuperRsk), même barre cachée.
    local t = CreateFrame("Button", "SuperGuideSwapGroupe", UIParent)
    t:RegisterForClicks("AnyDown")
    t:SetScript("OnClick", function() Swap.cliquer() end)
    t:Hide()
    _G["BINDING_NAME_CLICK SuperGuideSwapGroupe:LeftButton"] = L["Swap layer (ou quitter le groupe)"]
    _G["BINDING_NAME_CLICK SuperGuideSwapValider:LeftButton"] = L["Inviter la team"]

    Swap.rafraichir()
end

function Swap.appliquer(cle)
    if cle == "swapGroupeActif" or cle == "swapCompteur" then Swap.rafraichir() end
end
