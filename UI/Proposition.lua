-- Fenêtre « Équiper [X] ? » Oui / Non : une proposition d'amélioration à la
-- fois (la file vit dans Core/Equipement.lua). Rien ne s'équipe sans clic.
-- Aperçu : une copie (même construction) dans la bannière du menu, avec un
-- exemple et des boutons sans effet ; la vraie fenêtre reste telle quelle.

local ADDON, ns = ...

local Proposition = {}
ns.Proposition = Proposition

local L = ns.L or setmetatable({}, { __index = function(_, k) return k end })

local LARGEUR, HAUTEUR = 320, 92

local cadre, copie, courante
local apercu = false

-- Fabrique une fenêtre : fond, titre, ligne, boutons Non / Oui, compteur.
-- Sans rappels (la copie) : rien ne réagit, les boutons sont des dessins.
local function construire(nom, surOui, surNon)
    local T, C = ns.Theme, ns.Controles
    local w = CreateFrame("Frame", nom, UIParent)
    w:SetSize(LARGEUR, HAUTEUR)
    w:SetFrameStrata("FULLSCREEN_DIALOG")
    T.fond(w, "panneau", 0.96, "bordFort")

    w.zone = CreateFrame("Frame", nil, w)
    w.zone:SetPoint("TOPLEFT", 12, -10)
    w.zone:SetPoint("TOPRIGHT", -12, -10)
    w.zone:SetHeight(18)
    w.titre = C.texte(w.zone, "texte", "texte")
    w.titre:SetAllPoints()
    w.titre:SetWordWrap(false)

    w.ligne = C.texte(w, "petit", "texteDoux")
    w.ligne:SetPoint("TOPLEFT", w.zone, "BOTTOMLEFT", 0, -6)
    w.ligne:SetPoint("TOPRIGHT", w.zone, "BOTTOMRIGHT", 0, -6)
    w.ligne:SetWordWrap(false)

    local non = C.bouton(w, L["Non"], "texteDoux", surNon, 90)
    non:SetPoint("BOTTOMRIGHT", -12, 10)
    local oui = C.bouton(w, L["Oui"], "vert", surOui, 90)
    oui:SetPoint("RIGHT", non, "LEFT", -8, 0)
    if not (surOui or surNon) then non:EnableMouse(false); oui:EnableMouse(false) end

    -- « +2 en attente » : d'autres fenêtres suivent.
    w.enAttente = C.texte(w, "petit", "accent")
    w.enAttente:SetPoint("BOTTOMLEFT", 12, 14)
    w:Hide()
    return w
end

function Proposition.creer()
    cadre = construire("SuperGuideProposition",
        function() ns.Equipement.repondre(true) end,
        function() ns.Equipement.repondre(false) end)
    cadre:SetPoint("TOP", UIParent, "TOP", 0, -160)
    cadre:EnableMouse(true)
    if ns.Deplacement then
        ns.Deplacement.inscrire(cadre, L["Proposition d'équipement"], "proposition", { "TOP", 0, -160 })
    end

    -- Titre : survol = info-bulle de l'objet proposé.
    local zone = cadre.zone
    zone:EnableMouse(true)
    zone:SetScript("OnEnter", function(self)
        if not courante then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetHyperlink(courante.objet.lien)
        GameTooltip:Show()
    end)
    zone:SetScript("OnLeave", function() GameTooltip:Hide() end)

    ns.File.ecouter(function()
        local n = ns.File.enAttente()
        cadre.enAttente:SetText(n > 0 and L["+%d en attente"]:format(n) or "")
    end)
    -- Fermée (oui, non, objet parti) : la fenêtre suivante prend la place.
    cadre:SetScript("OnHide", function() ns.File.fini("proposition") end)
end

-- p = { objet, emplacement, remplace, gain } ; nil cache la fenêtre.
-- Gain en pourcent, une décimale (« 1,4 % » en français), sans signe.
function Proposition.pourcent(gain)
    local fr = not GetLocale or GetLocale() == "frFR"
    local t = ns.BarreXP.pct(math.abs(gain) * 100, fr)
    return (t:gsub("[%.,]0( ?%%)$", "%1"))
end

-- Met le cadre w en forme avec la proposition p, et le montre.
local function rendre(w, p)
    w.titre:SetText(L["Équiper %s ?"]:format(p.objet.lien))
    local pct = Proposition.pourcent(p.gain or 0)
    if p.remplace then
        w.ligne:SetText(L["+%s · remplace %s"]:format(pct, p.remplace.lien))
    else
        w.ligne:SetText(L["+%s · emplacement vide"]:format(pct))
    end
    w:Show()
end

local function afficher(p)
    courante = p
    rendre(cadre, p)
end

-- Aperçu (page du module) : la copie avec un exemple.
local EXEMPLE = { objet = { lien = "|cff1eff00[Arc long renforcé]|r" }, gain = 0.124,
                  remplace = { lien = "|cffffffff[Arc court]|r" } }

-- Copie montrée dans la bannière d'aperçu du menu (la vraie reste en place).
function Proposition.vitrine()
    if not copie then copie = construire(nil) end
    return copie, "proposition", true
end

function Proposition.apercu(oui)
    apercu = oui and true or false
    if not copie then return end
    if apercu then rendre(copie, EXEMPLE) else copie:Hide() end
end

function Proposition.enApercu() return apercu end

-- Passe par la file d'attente des fenêtres : une seule question à la fois.
function Proposition.montrer(p)
    if not cadre then courante = p; return end
    if not p then
        courante = nil
        ns.File.retirer("proposition")
        if cadre:IsShown() then cadre:Hide() end
        return
    end
    ns.File.demander("proposition", function() afficher(p) end)
end

---------------------------------------------------------------------------
-- Infobulle des objets : « Auto Equip  +12 % » en vert, « -8 % » en rouge.
---------------------------------------------------------------------------

-- Seulement les infobulles qu'on survole : pas l'info-bulle cachée du scan
-- (Jeu.objet s'en sert, on bouclerait), ni les comparaisons du jeu.
local engraisses = {}   -- [infobulle] = { { ligne, police, taille, contour } } à rendre au vidage

local function visee(tt) return tt == GameTooltip or tt == ItemRefTooltip end

function Proposition.texteInfobulle(p)
    local T = ns.Theme
    local pct = Proposition.pourcent(p.gain)
    if math.abs(p.gain) < 0.0005 then return "|cff" .. T.hex.texteDoux .. "= " .. pct .. "|r" end
    if p.gain > 0 then
        local vide = p.remplace and "" or (" · " .. L["emplacement vide"])
        if p.niveau then
            return "|cff" .. T.hex.orange .. "+" .. pct .. " · " .. L["au niveau %d"]:format(p.niveau) .. "|r"
        end
        return "|cff" .. T.hex.vert .. "+" .. pct .. vide .. "|r"
    end
    return "|cff" .. T.hex.rouge .. "-" .. pct .. "|r"
end

local function surObjet(tt)
    if not visee(tt) or not tt.GetItem then return end
    local ok, p = pcall(function()
        local _, lien = tt:GetItem()
        return ns.Equipement.infobulle(lien)
    end)
    if not (ok and p) then return end
    tt:AddDoubleLine("|cff" .. ns.Theme.hex.accent .. "Auto Equip|r", Proposition.texteInfobulle(p))
    -- En gras (Archivo Bold) ; police d'origine rendue au vidage de l'infobulle.
    local n, nom = tt:NumLines(), tt:GetName()
    for _, cote in ipairs({ "TextLeft", "TextRight" }) do
        local f = nom and n and _G[nom .. cote .. n]
        if f and f.GetFont then
            local police, taille, contour = f:GetFont()
            if police then
                engraisses[tt] = engraisses[tt] or {}
                table.insert(engraisses[tt], { f, police, taille, contour })
                f:SetFont(ns.Theme.MEDIA .. "Polices\\Archivo-BoldCondensed.ttf", taille, contour or "")
            end
        end
    end
    tt:Show()
end

local function rendrePolices(tt)
    for _, e in ipairs(engraisses[tt] or {}) do e[1]:SetFont(e[2], e[3], e[4] or "") end
    engraisses[tt] = nil
end

function Proposition.brancherInfobulle()
    for _, tt in ipairs({ GameTooltip, ItemRefTooltip }) do
        if tt and tt.HookScript then tt:HookScript("OnTooltipCleared", rendrePolices) end
    end
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, surObjet)
    else
        for _, tt in ipairs({ GameTooltip, ItemRefTooltip }) do
            if tt and tt.HookScript then tt:HookScript("OnTooltipSetItem", surObjet) end
        end
    end
end
