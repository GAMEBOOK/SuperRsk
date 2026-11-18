-- Fenêtre « Équiper [X] ? » Oui / Non : une proposition d'amélioration à la
-- fois (la file vit dans Core/Equipement.lua). Rien ne s'équipe sans clic.

local ADDON, ns = ...

local Proposition = {}
ns.Proposition = Proposition

local L = ns.L or setmetatable({}, { __index = function(_, k) return k end })

local LARGEUR, HAUTEUR = 320, 92

local cadre, titre, ligne, courante

function Proposition.creer()
    local T, C = ns.Theme, ns.Controles
    cadre = CreateFrame("Frame", "SuperGuideProposition", UIParent)
    cadre:SetSize(LARGEUR, HAUTEUR)
    cadre:SetPoint("TOP", UIParent, "TOP", 0, -160)
    cadre:SetFrameStrata("FULLSCREEN_DIALOG")
    cadre:EnableMouse(true)
    T.fond(cadre, "panneau", 0.96, "bordFort")

    -- Titre : survol = info-bulle de l'objet proposé.
    local zone = CreateFrame("Frame", nil, cadre)
    zone:SetPoint("TOPLEFT", 12, -10)
    zone:SetPoint("TOPRIGHT", -12, -10)
    zone:SetHeight(18)
    zone:EnableMouse(true)
    titre = C.texte(zone, "texte", "texte")
    titre:SetAllPoints()
    titre:SetWordWrap(false)
    zone:SetScript("OnEnter", function(self)
        if not courante then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetHyperlink(courante.objet.lien)
        GameTooltip:Show()
    end)
    zone:SetScript("OnLeave", function() GameTooltip:Hide() end)

    ligne = C.texte(cadre, "petit", "texteDoux")
    ligne:SetPoint("TOPLEFT", zone, "BOTTOMLEFT", 0, -6)
    ligne:SetPoint("TOPRIGHT", zone, "BOTTOMRIGHT", 0, -6)
    ligne:SetWordWrap(false)

    local non = C.bouton(cadre, L["Non"], "texteDoux", function() ns.Equipement.repondre(false) end, 90)
    non:SetPoint("BOTTOMRIGHT", -12, 10)
    local oui = C.bouton(cadre, L["Oui"], "vert", function() ns.Equipement.repondre(true) end, 90)
    oui:SetPoint("RIGHT", non, "LEFT", -8, 0)

    cadre:Hide()
end

-- p = { objet, emplacement, remplace, gain } ; nil cache la fenêtre.
-- Gain en pourcent, une décimale (« 1,4 % » en français), sans signe.
function Proposition.pourcent(gain)
    local fr = not GetLocale or GetLocale() == "frFR"
    local t = ns.BarreXP.pct(math.abs(gain) * 100, fr)
    return (t:gsub("[%.,]0( ?%%)$", "%1"))
end

function Proposition.montrer(p)
    courante = p
    if not cadre then return end
    if not p then cadre:Hide(); return end
    titre:SetText(L["Équiper %s ?"]:format(p.objet.lien))
    local pct = Proposition.pourcent(p.gain or 0)
    if p.remplace then
        ligne:SetText(L["+%s · remplace %s"]:format(pct, p.remplace.lien))
    else
        ligne:SetText(L["+%s · emplacement vide"]:format(pct))
    end
    cadre:Show()
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
