-- Monnaies : le widget (déplaçable par le mode Déplacer), dans l'esprit de
-- celui des victoires honorables. Une ligne par monnaie cochée : icône,
-- montant, nom au choix ; en colonne ou en ligne ; taille et fond réglables.
-- Survol : toutes les monnaies du jeu avec leur montant. Données dans
-- Core/Monnaies.lua.
-- Aperçu : une copie (même construction) dans la bannière du menu, avec un
-- exemple ; le vrai widget reste à sa place et suit les réglages en direct.

local ADDON, ns = ...

local Monnaies = ns.Monnaies
local L = ns.L or setmetatable({}, { __index = function(_, k) return k end })
local function R(cle) return ns.Reglages.get(cle) end

local widget, copie
local apercu = false
local POLICE = "Polices\\Archivo-BoldCondensed.ttf"

local function infobulle(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(L["Monnaies"], 1, 0.82, 0)
    -- Chaque ligne a son icône (même taille, bords rognés) : noms alignés.
    local function icone(chemin) return "|T" .. chemin .. ":14:14:0:0:64:64:5:59:5:59|t " end
    GameTooltip:AddDoubleLine(icone(Monnaies.ICONE_OR) .. L["Or"], ns.Jeu.texteArgent(ns.Jeu.argent() or 0), 1, 1, 1, 1, 1, 1)
    for _, c in ipairs(Monnaies.liste()) do
        local frais = Monnaies.info(c.id) or c
        -- À 0 : toute la ligne en gris, nom et montant.
        local v = frais.quantite == 0 and 0.55 or 1
        GameTooltip:AddDoubleLine(icone(c.icone or Monnaies.ICONE_VIDE) .. c.nom, Monnaies.nombre(frais.quantite), v, v, v, v, v, v)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L["Choisis les monnaies affichées dans /sg > Monnaies."], 0.6, 0.6, 0.6, true)
    GameTooltip:Show()
end

local function ligne(w, i)
    local lignes = w.lignes
    if lignes[i] then return lignes[i] end
    local T = ns.Theme
    local f = CreateFrame("Frame", nil, w)
    f.icone = f:CreateTexture(nil, "ARTWORK")
    f.icone:SetSize(16, 16)
    f.icone:SetPoint("LEFT")
    f.icone:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.texte = f:CreateFontString(nil, "OVERLAY")
    f.texte:SetFont(T.MEDIA .. POLICE, 14, "")
    f.texte:SetTextColor(T.rgb("texte"))
    f.nom = f:CreateFontString(nil, "OVERLAY")
    f.nom:SetFont(T.MEDIA .. POLICE, 12, "")
    f.nom:SetTextColor(T.rgb("texteDoux"))
    f.nom:SetWordWrap(false)
    lignes[i] = f
    return f
end

-- Met le cadre w en forme : exemple (copie de l'aperçu) ou vraies valeurs.
local function rendre(w, exemple)
    local lignes = w.lignes
    local donnees = Monnaies.lignes(exemple)
    local icones, noms = R("monnaiesIcones") ~= false, R("monnaiesNoms") == true
    local enLigne = R("monnaiesSens") == "ligne"
    if w == widget then w:SetScale(tonumber(R("monnaiesTaille")) or 1) end
    local a = tonumber(R("monnaiesFond")) or 0.92
    w.fondTex:SetAlpha(a)
    w.bordTex:SetAlpha(a)
    w.vide:SetShown(#donnees == 0)
    local PAD, H, ECART = 10, 20, 12
    -- Largeur des noms alignée en colonne.
    local largeurNom = 0
    for i, d in ipairs(donnees) do
        local f = ligne(w, i)
        f.nom:SetText(d.nom)
        if noms then largeurNom = math.max(largeurNom, math.min(140, f.nom:GetStringWidth() or 0)) end
    end
    local x, y, largeurMax = PAD, -PAD, 0
    for i, d in ipairs(donnees) do
        local f = ligne(w, i)
        f.icone:SetTexture(d.icone)
        f.icone:SetShown(icones)
        f.texte:SetText(Monnaies.texte(d))
        f.nom:SetShown(noms)
        f.nom:ClearAllPoints()
        f.texte:ClearAllPoints()
        local gauche = icones and 20 or 0
        local wNom = noms and (enLigne and math.min(140, f.nom:GetStringWidth() or 0) or largeurNom) or 0
        if noms then
            f.nom:SetPoint("LEFT", gauche, 0)
            f.nom:SetWidth(wNom)
            f.nom:SetJustifyH("LEFT")
            gauche = gauche + wNom + 6
        end
        f.texte:SetPoint("LEFT", gauche, 0)
        -- Le jeu compte mal les icônes dans un texte (pièces de l'or) : marge en plus.
        local _, icTexte = Monnaies.texte(d):gsub("|T", "")
        local larg = gauche + (f.texte:GetStringWidth() or 30) + 4 * icTexte
        f:SetSize(larg, H)
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", w, "TOPLEFT", x, y)
        f:Show()
        if enLigne then x = x + larg + ECART else y = y - H; largeurMax = math.max(largeurMax, larg) end
    end
    for i = #donnees + 1, #lignes do lignes[i]:Hide() end
    if #donnees == 0 then
        w:SetSize(math.max(60, (w.vide:GetStringWidth() or 50) + 2 * PAD), H + 2 * PAD)
    elseif enLigne then
        w:SetSize(x - ECART + PAD, H + 2 * PAD)
    else
        w:SetSize(largeurMax + 2 * PAD, -y + PAD)
    end
    w:Show()
end

-- Le vrai widget (visible si le module est allumé) et la copie de l'aperçu.
function Monnaies.afficher()
    if not widget then return end
    if R("monnaiesActif") == true then
        rendre(widget, false)
        if GameTooltip:IsOwned(widget) then infobulle(widget) end
    else
        widget:Hide()
    end
    if copie then
        if apercu then rendre(copie, true) else copie:Hide() end
    end
end

local function construire(nom)
    local T, C = ns.Theme, ns.Controles
    local w = CreateFrame("Frame", nom, UIParent)
    w.lignes = {}
    w:SetSize(110, 36)
    w:SetFrameStrata("MEDIUM")
    w:SetClampedToScreen(true)
    w.fondTex, w.bordTex = T.fond(w, "panneau", 0.92, "bordFort")
    w.vide = C.texte(w, "petit", "texteDoux")
    w.vide:SetPoint("CENTER")
    w.vide:SetText(L["Aucune monnaie cochée"])
    w:Hide()
    return w
end

-- Copie montrée dans la bannière d'aperçu du menu (le vrai reste en place).
function Monnaies.vitrine()
    if not copie then
        copie = construire(nil)
        -- Le menu allume l'aperçu avant de demander la copie : la remplir.
        if apercu then Monnaies.afficher() end
    end
    return copie, "monnaies", true
end

function Monnaies.apercu(oui)
    apercu = oui and true or false
    Monnaies.afficher()
end

function Monnaies.recentrer()
    if widget and ns.Deplacement then ns.Deplacement.remettre("monnaies"); Monnaies.afficher() end
end

-- Un montant a changé (événement du jeu) : au plus une mise à jour par image.
local demande = false
function Monnaies.surEvenement()
    if not widget or demande then return end
    demande = true
    C_Timer.After(0, function()
        demande = false
        Monnaies.inscrireCases()
        Monnaies.afficher()
    end)
end

function Monnaies.appliquer(cle)
    if type(cle) == "string" and cle:match("^monnaie") then Monnaies.afficher() end
end

function Monnaies.creer()
    Monnaies.inscrireCases()
    widget = construire("SuperGuideMonnaies")
    widget:EnableMouse(true)
    widget:SetScript("OnEnter", infobulle)
    widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
    if ns.Deplacement then
        ns.Deplacement.inscrire(widget, L["Monnaies"], "monnaies", { "TOPLEFT", 417, -350 })
    end
    Monnaies.afficher()
end
