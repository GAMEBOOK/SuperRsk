-- Fabrication : une barre pour toute une série d'objets fabriqués (« Créer
-- 10 »). Ici le calcul pur : la série, le temps total qui se recale sur les
-- vraies incantations et les pauses, les repères de chaque objet.
-- La barre et les événements du jeu sont dans UI/Fabrication.lua.

local ADDON, ns = ...

local Fabrication = {}
ns.Fabrication = Fabrication

Fabrication.MIN_SERIE = 2          -- un seul objet : la barre d'incantation suffit
Fabrication.PAUSE = 0.3            -- pause entre deux objets, avant de la mesurer
Fabrication.INCANTATION_DEVINEE = 3
Fabrication.RETARD = 5             -- série dépassée de 5 s sans nouvelle : finie
Fabrication.GRACE = 1              -- arrêt annoncé : on attend 1 s avant de couper

-- « 1:05 » (jamais négatif).
function Fabrication.horloge(s)
    s = math.max(0, math.floor((s or 0) + 0.5))
    return ("%d:%02d"):format(math.floor(s / 60), s % 60)
end

-- Temps total de la série, depuis son début : l'écoulé, le reste de
-- l'incantation en cours, puis les objets suivants (incantation + pause).
function Fabrication.recaler(s, maintenant, resteIncantation)
    local apres = s.nombre - s.faits - 1
    s.total = (maintenant - s.debut) + math.max(0, resteIncantation)
        + math.max(0, apres) * (s.incantation + s.pause)
end

-- Nouvelle série, ou nil si elle ne compte qu'un objet.
-- incantation : durée prévue d'un objet, en secondes (0 ou nil : devinée).
function Fabrication.nouvelle(recette, nombre, incantation, maintenant, nom, icone)
    nombre = math.floor(tonumber(nombre) or 1)
    if nombre < Fabrication.MIN_SERIE then return nil end
    local inc = tonumber(incantation) or 0
    if inc <= 0 then inc = Fabrication.INCANTATION_DEVINEE end
    local s = { recette = recette, nom = nom, icone = icone, nombre = nombre, faits = 0, fins = {},
                incantation = inc, pause = Fabrication.PAUSE, debut = maintenant }
    Fabrication.recaler(s, maintenant, inc)
    return s
end

-- Une incantation de la série commence : vraie durée (en ms, comme le jeu)
-- et vraie pause depuis l'objet précédent.
function Fabrication.debutIncantation(s, maintenant, debutMs, finMs)
    s.arret = nil
    if s.derniereFin then s.pause = maintenant - s.derniereFin end
    if not (debutMs and finMs) then return end
    s.incantation = (finMs - debutMs) / 1000
    Fabrication.recaler(s, maintenant, finMs / 1000 - maintenant)
end

-- Un objet est fabriqué. Renvoie true quand la série est finie.
function Fabrication.reussie(s, maintenant)
    s.faits = s.faits + 1
    if s.faits >= s.nombre then return true end
    s.derniereFin = maintenant
    s.fins[s.faits] = maintenant - s.debut
    Fabrication.recaler(s, maintenant, s.pause + s.incantation)
    return false
end

-- Avancement (0 à 1) et secondes restantes.
function Fabrication.part(s, maintenant)
    if s.total <= 0 then return 1 end
    return math.min(1, math.max(0, (maintenant - s.debut) / s.total))
end

function Fabrication.restant(s, maintenant)
    return s.total - (maintenant - s.debut)
end

-- Position (0 à 1) du repère après l'objet i : réelle s'il est fait, sinon prévue.
function Fabrication.repere(s, i)
    if s.total <= 0 then return i / s.nombre end
    local t = s.fins[i] or (s.total - (s.nombre - i) * (s.incantation + s.pause))
    return math.min(1, math.max(0, t / s.total))
end

-- Série dépassée sans nouvelle du jeu (incantation perdue) : à arrêter.
function Fabrication.perimee(s, maintenant)
    return maintenant > s.debut + s.total + Fabrication.RETARD
end

-- Titre de la fenêtre de métier avec le temps restant : on retire d'abord
-- notre ajout précédent (le jeu peut avoir changé le titre entre-temps).
local SUFFIXE = "  |cff4fd8ff%s|r"
function Fabrication.titre(texte, reste)
    local base = (texte or ""):gsub("  |cff4fd8ff[%d:]+|r$", "")
    if not reste then return base end
    return base .. SUFFIXE:format(Fabrication.horloge(reste))
end
