-- Poubelle : petite fenêtre « Sacs pleins : jeter … ? » (déplaçable par le
-- mode Déplacer). Le bouton Jeter est le clic du joueur ; la fenêtre se
-- ferme seule au bout de 20 s. Décisions dans Core/Poubelle.lua.

local ADDON, ns = ...

local Poubelle = ns.Poubelle
local L = ns.L or setmetatable({}, { __index = function(_, k) return k end })

local cadre, courant
Poubelle.DUREE = 20

local function fermer()
    courant = nil
    if cadre then cadre:Hide() end
end

local function afficher(c)
    courant = c
    cadre.icone:SetTexture(c.icone or "Interface\\Icons\\INV_Misc_QuestionMark")
    cadre.nom:SetText(c.lien .. (c.nombre > 1 and (" x" .. c.nombre) or ""))
    cadre.valeur:SetText(Poubelle.textePrix(c))
    cadre.jusqua = (GetTime and GetTime() or 0) + Poubelle.DUREE
    cadre:Show()
end

-- Passe par la file d'attente des fenêtres : une seule question à la fois.
function Poubelle.proposer(c)
    if not cadre then return end
    ns.File.demander("poubelle", function() afficher(c) end)
end

-- Aperçu (page du module) : la fenêtre avec un exemple, sans bouton actif.
local EXEMPLE = { lien = "|cff9d9d9d[Os brisé]|r", icone = "Interface\\Icons\\INV_Misc_Bone_01", prix = 3, hv = 12, nombre = 2 }
local enApercu = false

function Poubelle.vitrine() return cadre, "poubelle" end

function Poubelle.apercu(oui)
    if oui then
        enApercu = true
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
    cadre:SetSize(360, 74)
    cadre:SetFrameStrata("DIALOG")
    cadre:SetClampedToScreen(true)
    T.fond(cadre, "panneau", 0.96, "bordFort")
    local titre = C.texte(cadre, "petit", "orange")
    titre:SetPoint("TOPLEFT", 10, -8)
    titre:SetText(L["Sacs pleins : jeter l'objet gris le moins cher ?"])
    cadre.icone = cadre:CreateTexture(nil, "ARTWORK")
    cadre.icone:SetSize(28, 28)
    cadre.icone:SetPoint("TOPLEFT", 10, -26)
    cadre.icone:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    cadre.nom = C.texte(cadre, "petit", "texte")
    cadre.nom:SetPoint("TOPLEFT", cadre.icone, "TOPRIGHT", 8, -1)
    cadre.nom:SetWidth(190)
    cadre.nom:SetJustifyH("LEFT")
    cadre.nom:SetWordWrap(false)
    cadre.valeur = C.texte(cadre, "petit", "texteDoux")
    cadre.valeur:SetPoint("TOPLEFT", cadre.nom, "BOTTOMLEFT", 0, -3)
    cadre.valeur:SetWidth(190)
    cadre.valeur:SetJustifyH("LEFT")
    cadre.valeur:SetWordWrap(false)
    local non = C.bouton(cadre, "X", "texteDoux", fermer, 24)
    non:SetPoint("BOTTOMRIGHT", -8, 10)
    local oui = C.bouton(cadre, L["Jeter"], "rouge", function()
        if enApercu then return end
        local c = courant
        fermer()
        Poubelle.jeter(c)
    end, 80)
    oui:SetPoint("RIGHT", non, "LEFT", -6, 0)
    C.infobulle(oui, L["Jeter"], L["Détruit cet objet pour de bon et libère une place dans tes sacs."])
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
    cadre:Hide()
    if ns.Deplacement then
        ns.Deplacement.inscrire(cadre, L["Poubelle (sacs pleins)"], "poubelle", { "TOP", 0, -220 })
    end
end
