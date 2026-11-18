-- Auto Shot / Wand : calculs purs de la zone d'arrêt.
--
-- La fin du cycle de tir à distance est l'armement du tir : bouger pendant
-- ce temps retarde le tir. Sa durée réelle se mesure en jeu (bug de la bêta
-- Forever : ~0,1 s au lieu de 0,5 s), donc la zone suit Blizzard toute seule.
-- UI/Tir.lua lit le jeu et dessine sur la barre de tir native.

local ADDON, ns = ...

local Tir = {}
ns.Tir = Tir
local L = ns.L or setmetatable({}, { __index = function(_, k) return k end })

local ARMEMENT_DEFAUT = 0.5 -- durée prévue par Blizzard, tant qu'on n'a pas mesuré
local MIN_MESURES, MAX_MESURES = 3, 7
local GIGUE, PLANCHER, PLAFOND = 0.05, 0.02, 1

-- Secondes depuis le début du tir où la zone commence : assez tôt pour que
-- l'arrêt arrive au serveur avant l'armement.
function Tir.debutZone(duree, armement, latence, avance)
    return math.max(0, duree - (armement + (latence or 0) + (avance or 0)))
end

-- Arrêt (ou lancement du tir auto, immobile) à t0, tir reçu à t1 : l'arrêt
-- met un demi aller-retour à arriver, le tir un autre à revenir.
function Tir.mesure(t0, t1, allerRetour)
    local v = t1 - t0 - (allerRetour or 0)
    if v < -GIGUE or v > PLAFOND then return nil end
    return math.max(PLANCHER, v)
end

function Tir.ajouterMesure(mesures, v)
    if not v then return end
    mesures[#mesures + 1] = v
    while #mesures > MAX_MESURES do table.remove(mesures, 1) end
end

local function mediane(t)
    local c = {}
    for i, v in ipairs(t) do c[i] = v end
    table.sort(c)
    local n = #c
    if n % 2 == 1 then return c[(n + 1) / 2] end
    return (c[n / 2] + c[n / 2 + 1]) / 2
end

-- reglage : "auto" (médiane des mesures) ou une durée imposée.
function Tir.armement(mesures, reglage)
    if reglage ~= "auto" then return reglage end
    if #mesures < MIN_MESURES then return ARMEMENT_DEFAUT end
    return mediane(mesures)
end

function Tir.texteArmement(mesures)
    if #mesures == 0 then return nil end
    return L["%s s (%d mesures)"]:format(("%.2f"):format(mediane(mesures)):gsub("%.", ","), #mesures)
end
