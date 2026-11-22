-- Poubelle : petite fenêtre « Sacs pleins : jeter … ? » (déplaçable par le
-- mode Déplacer). Le bouton Jeter est le clic du joueur ; la fenêtre se
-- ferme seule au bout de 20 s. Décisions dans Core/Poubelle.lua.

local ADDON, ns = ...

local Poubelle = ns.Poubelle
local L = ns.L or setmetatable({}, { __index = function(_, k) return k end })

local cadre, courant, choix, rang
Poubelle.DUREE = 20

local function fermer()
    courant, choix, rang = nil, nil, nil
    if cadre then cadre:Hide() end
end

local function afficher(c)
    courant = c
    local n = choix and #choix or 1
    cadre.prec:SetShown(n > 1)
    cadre.suiv:SetShown(n > 1)
    cadre.compte:SetText(n > 1 and ("%d/%d"):format(rang, n) or "")
    if c.menage then
        -- Pas de gris : on propose le ménage des objets de quête finis.
        cadre.titre:SetText(L["Sacs pleins : des objets de quête ne servent plus"])
        cadre.icone:SetTexture("Interface\\Icons\\INV_Misc_Note_01")
        cadre.nom:SetText(L["%d objets de quête terminés"]:format(c.menage))
        cadre.valeur:SetText(L["Leurs quêtes sont finies : de la place à gagner"])
        cadre.oui.texte:SetText(L["Voir"])
        cadre.oui.texte:SetTextColor(ns.Theme.rgb("accent"))
    else
        cadre.titre:SetText(c.commun and L["Sacs pleins : jeter l'objet qui vaut le moins ?"]
            or L["Sacs pleins : jeter l'objet gris le moins cher ?"])
        cadre.icone:SetTexture(c.icone or "Interface\\Icons\\INV_Misc_QuestionMark")
        cadre.nom:SetText(c.lien .. (c.nombre > 1 and (" x" .. c.nombre) or ""))
        cadre.valeur:SetText(Poubelle.textePrix(c))
        cadre.oui.texte:SetText(L["Jeter"])
        cadre.oui.texte:SetTextColor(ns.Theme.rgb("rouge"))
    end
    -- Largeur au plus juste : icône + texte le plus long + boutons, sans
    -- descendre sous la largeur du titre.
    local texte = math.max(cadre.nom:GetStringWidth() or 0, cadre.valeur:GetStringWidth() or 0)
    local boutons = n > 1 and 178 or 118
    local l = math.max((cadre.titre:GetStringWidth() or 0) + 20 + (n > 1 and 40 or 0), 46 + texte + 12 + boutons)
    cadre:SetWidth(math.min(480, math.ceil(l)))
    cadre.nom:SetWidth(cadre:GetWidth() - 46 - boutons - 6)
    cadre.valeur:SetWidth(cadre:GetWidth() - 46 - boutons - 6)
    cadre.jusqua = (GetTime and GetTime() or 0) + Poubelle.DUREE
    cadre:Show()
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

-- Aperçu (page du module) : la fenêtre avec un exemple, sans bouton actif.
local EXEMPLE = { lien = "|cff9d9d9d[Os brisé]|r", icone = "Interface\\Icons\\INV_Misc_Bone_01", prix = 3, hv = 12, nombre = 2 }
local EXEMPLE2 = { lien = "|cff9d9d9d[Croc ébréché]|r", icone = "Interface\\Icons\\INV_Misc_Bone_08", prix = 7, hv = 20, nombre = 1 }
local enApercu = false

function Poubelle.vitrine() return cadre, "poubelle" end

function Poubelle.apercu(oui)
    if oui then
        enApercu = true
        choix, rang = { EXEMPLE, EXEMPLE2 }, 1
        afficher(EXEMPLE)
        cadre.jusqua = false   -- pas de fermeture automatique pendant l'aperçu
    else
        fermer()
        enApercu = false
    end
end

function Poubelle.creer()
    local T, C = ns.Theme, ns.Controles
    cadre = CreateFrame("Frame", "SuperGuidePoubelle", UIParent)
    cadre:SetSize(320, 74)
    cadre:SetFrameStrata("DIALOG")
    cadre:SetClampedToScreen(true)
    T.fond(cadre, "panneau", 0.96, "bordFort")
    local titre = C.texte(cadre, "petit", "orange")
    titre:SetPoint("TOPLEFT", 10, -8)
    titre:SetText(L["Sacs pleins : jeter l'objet gris le moins cher ?"])
    cadre.titre = titre
    cadre.icone = cadre:CreateTexture(nil, "ARTWORK")
    cadre.icone:SetSize(28, 28)
    cadre.icone:SetPoint("TOPLEFT", 10, -26)
    cadre.icone:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    cadre.nom = C.texte(cadre, "petit", "texte")
    cadre.nom:SetPoint("TOPLEFT", cadre.icone, "TOPRIGHT", 8, -1)
    cadre.nom:SetWidth(150)
    cadre.nom:SetJustifyH("LEFT")
    cadre.nom:SetWordWrap(false)
    cadre.valeur = C.texte(cadre, "petit", "texteDoux")
    cadre.valeur:SetPoint("TOPLEFT", cadre.nom, "BOTTOMLEFT", 0, -3)
    cadre.valeur:SetWidth(150)
    cadre.valeur:SetJustifyH("LEFT")
    cadre.valeur:SetWordWrap(false)
    local non = C.bouton(cadre, "X", "texteDoux", fermer, 24)
    non:SetPoint("BOTTOMRIGHT", -8, 10)
    local oui = C.bouton(cadre, L["Jeter"], "rouge", function()
        if enApercu then return end
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
    end, 80)
    oui:SetPoint("RIGHT", non, "LEFT", -6, 0)
    cadre.oui = oui
    -- ‹ 2/5 › : choisir un autre objet que celui proposé.
    local suiv = C.bouton(cadre, "›", "texte", function() changer(1) end, 22)
    suiv:SetPoint("RIGHT", oui, "LEFT", -8, 0)
    local compte = C.texte(cadre, "petit", "texteDoux")
    compte:SetPoint("BOTTOM", suiv, "TOP", -14, 3)
    local prec = C.bouton(cadre, "‹", "texte", function() changer(-1) end, 22)
    prec:SetPoint("RIGHT", suiv, "LEFT", -4, 0)
    cadre.prec, cadre.suiv, cadre.compte = prec, suiv, compte
    C.infobulle(suiv, L["Objet suivant"], L["Pas celui-là ? Les flèches proposent un autre objet, du moins cher au plus cher."])
    C.infobulle(prec, L["Objet précédent"], L["Pas celui-là ? Les flèches proposent un autre objet, du moins cher au plus cher."])
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
    C.infobulle(oui, L["Jeter"], L["Met l'objet dans ta main : clique ensuite dans le vide puis sur Oui, le jeu le détruit (seule façon permise par le jeu)."])
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
    cadre:SetScript("OnHide", function() if not enApercu then ns.File.fini("poubelle") end end)
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
    cadre:Hide()
    if ns.Deplacement then
        ns.Deplacement.inscrire(cadre, L["Poubelle (sacs pleins)"], "poubelle", { "TOP", 0, -220 })
    end
end
