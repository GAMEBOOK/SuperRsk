-- Usure : le widget d'alerte (déplaçable par le mode Déplacer). Trois
-- styles : icône de la pièce + pourcentage, barre, texte seul. Taille
-- réglable. Aperçu : visible avec un exemple tant que la page du module est
-- ouverte. Décisions dans Core/Usure.lua.

local ADDON, ns = ...

local Usure = ns.Usure
local L = ns.L or setmetatable({}, { __index = function(_, k) return k end })
local function R(cle) return ns.Reglages.get(cle) end

local widget
local apercu = false
local EXEMPLE = { pourcent = 14, case = 5, sous = { { case = 5, pourcent = 14 }, { case = 7, pourcent = 18 } }, alerte = true }

local function couleur(pc)
    local T = ns.Theme
    if pc >= Usure.seuil() then return T.rgb("vert") end
    return T.rgb(Usure.couleur(pc) == "jaune" and "orange" or Usure.couleur(pc))
end

local function infobulle(self)
    local e = apercu and EXEMPLE or Usure.dernier
    if not e then return end
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(L["Équipement usé"], 1, 0.82, 0)
    for _, p in ipairs(e.sous or {}) do
        local lien = ns.Jeu.lienPiece(p.case) or ("#" .. p.case)
        local r, g, b = couleur(p.pourcent)
        GameTooltip:AddDoubleLine(lien, p.pourcent .. " %", 1, 1, 1, r, g, b)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L["Répare chez un marchand (le module Marchand le fait seul)."], 0.6, 0.6, 0.6, true)
    GameTooltip:Show()
end

-- Met le widget en forme pour l'état e (ou le cache).
function Usure.afficher(e)
    if not widget then return end
    if apercu then e = EXEMPLE end
    if not apercu and R("usureActif") == false then widget:Hide(); return end
    if not (e and e.pourcent) or not (e.alerte or R("usureToujours")) then widget:Hide(); return end
    local style = R("usureStyle") or "icone"
    local r, g, b = couleur(e.pourcent)
    widget:SetScale(tonumber(R("usureTaille")) or 1)
    widget.texte:SetText(e.pourcent .. " %")
    widget.texte:SetTextColor(r, g, b)
    widget.icone:SetTexture(ns.Jeu.iconePiece(e.case) or "Interface\\Icons\\INV_Chest_Plate06")
    widget.icone:SetShown(style ~= "texte")
    widget.barre:SetShown(style == "barre")
    widget.fondBarre:SetShown(style == "barre")
    widget.titre:SetShown(style == "texte")
    widget.fondTex:SetAlpha(tonumber(R("usureFond")) or 0.92)
    widget.bordTex:SetAlpha(tonumber(R("usureFond")) or 0.92)
    -- Nom de la pièce la plus usée, à droite (styles icône et barre).
    local nom = R("usureNom") and style ~= "texte" and (ns.Jeu.lienPiece(e.case) or ""):match("%[(.-)%]")
    if apercu and R("usureNom") and style ~= "texte" and not nom then nom = L["Plastron"] end
    widget.nom:SetText(nom or "")
    widget.nom:SetShown(nom ~= nil and nom ~= false)
    local extra = (nom and nom ~= false) and math.min(160, (widget.nom:GetStringWidth() or 0)) + 10 or 0
    widget.texte:ClearAllPoints()
    widget.nom:ClearAllPoints()
    if style == "texte" then
        -- Libellé au choix (ou aucun : seulement le pourcentage).
        local libre = R("usureTexteLibelle")
        local avecLibelle = R("usureLibelle") ~= false
        widget.titre:SetText((type(libre) == "string" and libre ~= "") and libre or L["Équipement"])
        widget.titre:SetShown(avecLibelle)
        widget.titre:SetPoint("LEFT", 10, 0)
        local lt = avecLibelle and (widget.titre:GetStringWidth() or 60) + 10 or 0
        local lp = widget.texte:GetStringWidth() or 40
        widget:SetSize(math.max(56, lt + lp + 20), 26)
        if avecLibelle then widget.texte:SetPoint("RIGHT", -10, 0) else widget.texte:SetPoint("CENTER") end
    elseif style == "barre" then
        widget:SetSize(150 + extra, 34)
        widget.texte:SetPoint("TOPLEFT", widget.icone, "TOPRIGHT", 8, 0)
        widget.nom:SetPoint("LEFT", widget.icone, "RIGHT", 112, 0)
        widget.barre:SetWidth(math.max(1, 96 * e.pourcent / 100))
        widget.barre:SetColorTexture(r, g, b)
    else
        widget:SetSize(86 + extra, 34)
        widget.texte:SetPoint("LEFT", widget.icone, "RIGHT", 8, 0)
        widget.nom:SetPoint("LEFT", widget.icone, "RIGHT", 58, 0)
    end
    widget:Show()
end

-- Cadre montré dans la bannière d'aperçu du menu, et sa clé de position.
function Usure.vitrine() return widget, "usure" end

-- Aperçu en direct depuis la page du module.
function Usure.apercu(oui)
    apercu = oui and true or false
    Usure.afficher(Usure.dernier)
end

function Usure.creer()
    local T, C = ns.Theme, ns.Controles
    widget = CreateFrame("Frame", "SuperGuideUsure", UIParent)
    widget:SetSize(86, 34)
    widget:SetFrameStrata("MEDIUM")
    widget:SetClampedToScreen(true)
    widget.fondTex, widget.bordTex = T.fond(widget, "panneau", 1, "bordFort")
    widget.icone = widget:CreateTexture(nil, "ARTWORK")
    widget.icone:SetSize(26, 26)
    widget.icone:SetPoint("LEFT", 4, 0)
    widget.icone:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    widget.texte = widget:CreateFontString(nil, "OVERLAY")
    widget.texte:SetFont(T.MEDIA .. "Polices\\Archivo-BoldCondensed.ttf", 16, "")
    widget.nom = C.texte(widget, "petit", "texte")
    widget.nom:SetWidth(160)
    widget.nom:SetJustifyH("LEFT")
    widget.nom:SetWordWrap(false)
    widget.titre = C.texte(widget, "petit", "texteDoux")
    widget.titre:SetText(L["Équipement"])
    widget.fondBarre = widget:CreateTexture(nil, "ARTWORK")
    widget.fondBarre:SetColorTexture(T.rgb("sombre"))
    widget.fondBarre:SetSize(96, 5)
    widget.fondBarre:SetPoint("BOTTOMLEFT", widget.icone, "BOTTOMRIGHT", 8, 2)
    widget.barre = widget:CreateTexture(nil, "OVERLAY")
    widget.barre:SetHeight(5)
    widget.barre:SetPoint("LEFT", widget.fondBarre, "LEFT")
    widget.etiquette = C.texte(widget, "petit", "accent")
    widget.etiquette:SetPoint("BOTTOM", widget, "TOP", 0, 3)
    widget.etiquette:SetText(L["APERÇU"])
    widget:SetScript("OnEnter", infobulle)
    widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
    widget:Hide()
    if ns.Deplacement then
        ns.Deplacement.inscrire(widget, L["Usure de l'équipement"], "usure", { "TOP", 220, -14 })
    end
    Usure.verifier()
end
