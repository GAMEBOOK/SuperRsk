-- Usure : le widget d'alerte (déplaçable par le mode Déplacer). Trois
-- styles : icône de la pièce + pourcentage, barre, texte seul. Taille
-- réglable. Décisions dans Core/Usure.lua.
-- Aperçu : une copie (même construction) dans la bannière du menu, avec un
-- exemple ; le vrai widget reste à sa place et suit les réglages en direct.

local ADDON, ns = ...

local Usure = ns.Usure
local L = ns.L or setmetatable({}, { __index = function(_, k) return k end })
local function R(cle) return ns.Reglages.get(cle) end

local widget, copie
local apercu = false
local EXEMPLE = { pourcent = 14, case = 5, sous = { { case = 5, pourcent = 14 }, { case = 7, pourcent = 18 } }, alerte = true }

local function couleur(pc)
    local T = ns.Theme
    if pc >= Usure.seuil() then return T.rgb("vert") end
    return T.rgb(Usure.couleur(pc) == "jaune" and "orange" or Usure.couleur(pc))
end

local function infobulle(self)
    local e = Usure.dernier
    if not e then return end
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(L["Équipement usé"], 1, 0.82, 0)
    for _, p in ipairs(e.sous or {}) do
        local lien = ns.Jeu.lienPiece(p.case) or ("#" .. p.case)
        local r, g, b = couleur(p.pourcent)
        GameTooltip:AddDoubleLine(lien, p.pourcent .. " %", 1, 1, 1, r, g, b)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L["Répare chez un marchand (le module Auto Sell & Repair le fait seul)."], 0.6, 0.6, 0.6, true)
    GameTooltip:Show()
end

-- Met le cadre w en forme pour l'état e (vrai widget ou copie de l'aperçu).
local function rendre(w, e, exemple)
    local style = R("usureStyle") or "icone"
    local r, g, b = couleur(e.pourcent)
    if w == widget then w:SetScale(tonumber(R("usureTaille")) or 1) end
    w.texte:SetText(e.pourcent .. " %")
    w.texte:SetTextColor(r, g, b)
    w.icone:SetTexture(ns.Jeu.iconePiece(e.case) or "Interface\\Icons\\INV_Chest_Plate06")
    w.icone:SetShown(style ~= "texte")
    w.barre:SetShown(style == "barre")
    w.fondBarre:SetShown(style == "barre")
    w.titre:SetShown(style == "texte")
    w.fondTex:SetAlpha(tonumber(R("usureFond")) or 0.92)
    w.bordTex:SetAlpha(tonumber(R("usureFond")) or 0.92)
    -- Nom de la pièce la plus usée, à droite (styles icône et barre).
    local nom = R("usureNom") and style ~= "texte" and (ns.Jeu.lienPiece(e.case) or ""):match("%[(.-)%]")
    if exemple and R("usureNom") and style ~= "texte" and not nom then nom = L["Plastron"] end
    w.nom:SetText(nom or "")
    w.nom:SetShown(nom ~= nil and nom ~= false)
    local extra = (nom and nom ~= false) and math.min(160, (w.nom:GetStringWidth() or 0)) + 10 or 0
    w.texte:ClearAllPoints()
    w.nom:ClearAllPoints()
    if style == "texte" then
        -- Libellé au choix (ou aucun : seulement le pourcentage).
        local libre = R("usureTexteLibelle")
        local avecLibelle = R("usureLibelle") ~= false
        w.titre:SetText((type(libre) == "string" and libre ~= "") and libre or L["Équipement"])
        w.titre:SetShown(avecLibelle)
        w.titre:SetPoint("LEFT", 10, 0)
        local lt = avecLibelle and (w.titre:GetStringWidth() or 60) + 10 or 0
        local lp = w.texte:GetStringWidth() or 40
        w:SetSize(math.max(56, lt + lp + 20), 26)
        if avecLibelle then w.texte:SetPoint("RIGHT", -10, 0) else w.texte:SetPoint("CENTER") end
    elseif style == "barre" then
        w:SetSize(150 + extra, 34)
        w.texte:SetPoint("TOPLEFT", w.icone, "TOPRIGHT", 8, 0)
        w.nom:SetPoint("LEFT", w.icone, "RIGHT", 112, 0)
        w.barre:SetWidth(math.max(1, 96 * e.pourcent / 100))
        w.barre:SetColorTexture(r, g, b)
    else
        w:SetSize(86 + extra, 34)
        w.texte:SetPoint("LEFT", w.icone, "RIGHT", 8, 0)
        w.nom:SetPoint("LEFT", w.icone, "RIGHT", 58, 0)
    end
    w:Show()
end

-- Le vrai widget pour l'état e (visible s'il y a lieu, l'aperçu n'y touche
-- pas) et la copie de l'aperçu avec l'exemple.
function Usure.afficher(e)
    if not widget then return end
    if R("usureActif") == false or not (e and e.pourcent) or not (e.alerte or R("usureToujours")) then
        widget:Hide()
    else
        rendre(widget, e, false)
    end
    if copie then
        if apercu then rendre(copie, EXEMPLE, true) else copie:Hide() end
    end
end

local function construire(nom)
    local T, C = ns.Theme, ns.Controles
    local w = CreateFrame("Frame", nom, UIParent)
    w:SetSize(86, 34)
    w:SetFrameStrata("MEDIUM")
    w:SetClampedToScreen(true)
    w.fondTex, w.bordTex = T.fond(w, "panneau", 1, "bordFort")
    w.icone = w:CreateTexture(nil, "ARTWORK")
    w.icone:SetSize(26, 26)
    w.icone:SetPoint("LEFT", 4, 0)
    w.icone:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    w.texte = w:CreateFontString(nil, "OVERLAY")
    w.texte:SetFont(T.MEDIA .. "Polices\\Archivo-BoldCondensed.ttf", 16, "")
    w.nom = C.texte(w, "petit", "texte")
    w.nom:SetWidth(160)
    w.nom:SetJustifyH("LEFT")
    w.nom:SetWordWrap(false)
    w.titre = C.texte(w, "petit", "texteDoux")
    w.titre:SetText(L["Équipement"])
    w.fondBarre = w:CreateTexture(nil, "ARTWORK")
    w.fondBarre:SetColorTexture(T.rgb("sombre"))
    w.fondBarre:SetSize(96, 5)
    w.fondBarre:SetPoint("BOTTOMLEFT", w.icone, "BOTTOMRIGHT", 8, 2)
    w.barre = w:CreateTexture(nil, "OVERLAY")
    w.barre:SetHeight(5)
    w.barre:SetPoint("LEFT", w.fondBarre, "LEFT")
    w:Hide()
    return w
end

-- Copie montrée dans la bannière d'aperçu du menu (le vrai reste en place).
function Usure.vitrine()
    if not copie then
        copie = construire(nil)
        copie:EnableMouse(false)
        if apercu then rendre(copie, EXEMPLE, true) end
    end
    return copie, "usure", true
end

-- Aperçu en direct depuis la page du module.
function Usure.apercu(oui)
    apercu = oui and true or false
    Usure.afficher(Usure.dernier)
end

function Usure.creer()
    widget = construire("SuperGuideUsure")
    widget:SetScript("OnEnter", infobulle)
    widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
    if ns.Deplacement then
        ns.Deplacement.inscrire(widget, L["Usure de l'équipement"], "usure", { "TOP", 220, -14 })
    end
    Usure.verifier()
end
