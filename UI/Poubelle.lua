-- Poubelle : petite fenêtre « Sacs pleins : jeter … ? » (déplaçable par le
-- mode Déplacer). Le bouton Jeter est le clic du joueur ; la fenêtre se
-- ferme seule au bout de 20 s. Décisions dans Core/Poubelle.lua.
-- Aperçu : une copie (même construction) dans la bannière du menu, avec un
-- exemple ; la vraie fenêtre garde son rôle (elle s'ouvre si les sacs se
-- remplissent pendant le réglage).

local ADDON, ns = ...

local Poubelle = ns.Poubelle
local L = ns.L or setmetatable({}, { __index = function(_, k) return k end })

local cadre, copie, courant, choix, rang
Poubelle.DUREE = 20

local function fermer()
    courant, choix, rang = nil, nil, nil
    if cadre then cadre:Hide() end
end

-- Met la fenêtre w en forme pour l'objet c (n objets au choix, c au rang r).
local function rendre(w, c, n, r)
    w.prec:SetShown(n > 1)
    w.suiv:SetShown(n > 1)
    w.compte:SetText(n > 1 and ("%d/%d"):format(r, n) or "")
    if c.menage then
        -- Pas de gris : on propose le ménage des objets de quête finis.
        w.titre:SetText(L["Sacs pleins : des objets de quête ne servent plus"])
        w.icone:SetTexture("Interface\\Icons\\INV_Misc_Note_01")
        w.nom:SetText(L["%d objets de quête terminés"]:format(c.menage))
        w.valeur:SetText(L["Leurs quêtes sont finies : de la place à gagner"])
        w.oui.texte:SetText(L["Voir"])
        w.oui.texte:SetTextColor(ns.Theme.rgb("accent"))
    else
        w.titre:SetText(c.commun and L["Sacs pleins : jeter l'objet qui vaut le moins ?"]
            or L["Sacs pleins : jeter l'objet gris le moins cher ?"])
        w.icone:SetTexture(c.icone or "Interface\\Icons\\INV_Misc_QuestionMark")
        w.nom:SetText(c.lien .. (c.nombre > 1 and (" x" .. c.nombre) or ""))
        w.valeur:SetText(Poubelle.textePrix(c))
        w.oui.texte:SetText(L["Jeter"])
        w.oui.texte:SetTextColor(ns.Theme.rgb("rouge"))
    end
    -- Largeur au plus juste : icône + texte le plus long + boutons, sans
    -- descendre sous la largeur du titre.
    local texte = math.max(w.nom:GetStringWidth() or 0, w.valeur:GetStringWidth() or 0)
    local boutons = n > 1 and 178 or 118
    local l = math.max((w.titre:GetStringWidth() or 0) + 20 + (n > 1 and 40 or 0), 46 + texte + 12 + boutons)
    w:SetWidth(math.min(480, math.ceil(l)))
    w.nom:SetWidth(w:GetWidth() - 46 - boutons - 6)
    w.valeur:SetWidth(w:GetWidth() - 46 - boutons - 6)
    w:Show()
end

local function afficher(c)
    courant = c
    cadre.jusqua = (GetTime and GetTime() or 0) + Poubelle.DUREE
    rendre(cadre, c, choix and #choix or 1, rang)
end

-- Passe par la file d'attente des fenêtres : une seule question à la fois.
function Poubelle.proposer(c)
    if not cadre then return end
    ns.File.demander("poubelle", function()
        choix, rang = c.choix, 1
        if not choix or #choix == 0 then choix = { c } end
        afficher(choix[1])
    end)
end

-- Flèches : un autre objet de la liste (le délai repart à zéro).
local function changer(sens)
    if not choix or #choix < 2 then return end
    rang = (rang - 1 + sens) % #choix + 1
    afficher(choix[rang])
end

-- Aperçu (page du module) : la copie avec un exemple, sans bouton actif
-- (les flèches passent d'un exemple à l'autre).
local EXEMPLE = { lien = "|cff9d9d9d[Os brisé]|r", icone = "Interface\\Icons\\INV_Misc_Bone_01", prix = 3, hv = 12, nombre = 2 }
local EXEMPLE2 = { lien = "|cff9d9d9d[Croc ébréché]|r", icone = "Interface\\Icons\\INV_Misc_Bone_08", prix = 7, hv = 20, nombre = 1 }
local EXEMPLES = { EXEMPLE, EXEMPLE2 }
local enApercu, rangCopie = false, 1

local function rendreCopie()
    if not copie then return end
    if enApercu then rendre(copie, EXEMPLES[rangCopie], #EXEMPLES, rangCopie) else copie:Hide() end
end

-- La fenêtre et ses boutons ; actions = { fermer, jeter, changer(sens) }.
local function construire(nom, actions)
    local T, C = ns.Theme, ns.Controles
    local w = CreateFrame("Frame", nom, UIParent)
    w:SetSize(320, 74)
    w:SetFrameStrata("DIALOG")
    w:SetClampedToScreen(true)
    T.fond(w, "panneau", 0.96, "bordFort")
    local titre = C.texte(w, "petit", "orange")
    titre:SetPoint("TOPLEFT", 10, -8)
    titre:SetText(L["Sacs pleins : jeter l'objet gris le moins cher ?"])
    w.titre = titre
    w.icone = w:CreateTexture(nil, "ARTWORK")
    w.icone:SetSize(28, 28)
    w.icone:SetPoint("TOPLEFT", 10, -26)
    w.icone:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    w.nom = C.texte(w, "petit", "texte")
    w.nom:SetPoint("TOPLEFT", w.icone, "TOPRIGHT", 8, -1)
    w.nom:SetWidth(150)
    w.nom:SetJustifyH("LEFT")
    w.nom:SetWordWrap(false)
    w.valeur = C.texte(w, "petit", "texteDoux")
    w.valeur:SetPoint("TOPLEFT", w.nom, "BOTTOMLEFT", 0, -3)
    w.valeur:SetWidth(150)
    w.valeur:SetJustifyH("LEFT")
    w.valeur:SetWordWrap(false)
    local non = C.bouton(w, "X", "texteDoux", actions.fermer, 24)
    non:SetPoint("BOTTOMRIGHT", -8, 10)
    local oui = C.bouton(w, L["Jeter"], "rouge", actions.jeter, 80)
    oui:SetPoint("RIGHT", non, "LEFT", -6, 0)
    w.oui = oui
    -- ‹ 2/5 › : choisir un autre objet que celui proposé.
    local suiv = C.bouton(w, "›", "texte", function() actions.changer(1) end, 22)
    suiv:SetPoint("RIGHT", oui, "LEFT", -8, 0)
    local compte = C.texte(w, "petit", "texteDoux")
    compte:SetPoint("BOTTOM", suiv, "TOP", -14, 3)
    local prec = C.bouton(w, "‹", "texte", function() actions.changer(-1) end, 22)
    prec:SetPoint("RIGHT", suiv, "LEFT", -4, 0)
    w.prec, w.suiv, w.compte = prec, suiv, compte
    C.infobulle(suiv, L["Objet suivant"], L["Pas celui-là ? Les flèches proposent un autre objet, du moins cher au plus cher."])
    C.infobulle(prec, L["Objet précédent"], L["Pas celui-là ? Les flèches proposent un autre objet, du moins cher au plus cher."])
    C.infobulle(oui, L["Jeter"], L["Met l'objet dans ta main : clique ensuite dans le vide puis sur Oui, le jeu le détruit (seule façon permise par le jeu)."])
    w:Hide()
    return w
end

-- Copie montrée dans la bannière d'aperçu du menu (la vraie reste en place).
function Poubelle.vitrine()
    if not copie then
        copie = construire(nil, {
            fermer = function() end,
            jeter = function() end,
            changer = function(sens)
                rangCopie = (rangCopie - 1 + sens) % #EXEMPLES + 1
                rendreCopie()
            end,
        })
        copie:EnableMouse(false)
        rendreCopie()
    end
    return copie, "poubelle", true
end

function Poubelle.apercu(oui)
    enApercu = oui and true or false
    rangCopie = 1
    rendreCopie()
end

function Poubelle.creer()
    local C = ns.Controles
    cadre = construire("SuperGuidePoubelle", {
        fermer = fermer,
        jeter = function()
            local c = courant
            fermer()
            if c and c.menage then
                if ns.Menage and ns.Menage.ouvrir then ns.Menage.ouvrir() end
                return
            end
            if Poubelle.jeter(c) then
                C.aideJeter(function() return ns.Jeu.lienSac(c.sac, c.case) ~= c.lien end,
                    function() Poubelle.confirmer(c) end)
            end
        end,
        changer = changer,
    })
    -- Survol de l'icône : l'info-bulle de l'objet.
    local survol = CreateFrame("Frame", nil, cadre)
    survol:SetAllPoints(cadre.icone)
    survol:EnableMouse(true)
    survol:SetScript("OnEnter", function(self)
        if not (courant and courant.sac and courant.case) then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        if GameTooltip.SetBagItem then GameTooltip:SetBagItem(courant.sac, courant.case) end
        GameTooltip:Show()
    end)
    survol:SetScript("OnLeave", function() GameTooltip:Hide() end)
    cadre:SetScript("OnUpdate", function(self)
        if self.jusqua and (GetTime and GetTime() or 0) > self.jusqua then fermer() end
    end)
    -- « +2 en attente » : d'autres fenêtres suivent.
    local enAttente = C.texte(cadre, "petit", "accent")
    enAttente:SetPoint("BOTTOMLEFT", 10, 6)
    ns.File.ecouter(function()
        local n = ns.File.enAttente()
        enAttente:SetText(n > 0 and L["+%d en attente"]:format(n) or "")
    end)
    -- Fermée (jeter, X, délai) : la fenêtre suivante prend la place.
    cadre:SetScript("OnHide", function() ns.File.fini("poubelle") end)
    -- Les sacs viennent de se remplir (achat, quête, échange…) : même
    -- proposition que lorsqu'un butin ne rentre plus.
    local libresAvant
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("BAG_UPDATE_DELAYED")
    ev:SetScript("OnEvent", function()
        local n = ns.Jeu.placesLibres()
        if n == 0 and libresAvant and libresAvant > 0 and not InCombatLockdown() then Poubelle.surPlein() end
        libresAvant = n
    end)
    if ns.Deplacement then
        ns.Deplacement.inscrire(cadre, L["Poubelle (sacs pleins)"], "poubelle", { "TOP", 0, -220 })
    end
end
