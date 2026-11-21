-- Barre de réputation : calculs purs (aucun appel au jeu), testés hors jeu.
-- Le relevé d'une faction vient de Jeu.factionSuivie().
local ADDON, ns = ...

local BarreRep = {}
ns.BarreRep = BarreRep

-- Avancée dans le rang : (fait, total). Au rang maximum (pas de palier
-- suivant), la barre est pleine : (1, 1) et auMax.
function BarreRep.progression(f)
    local total = (f.max or 0) - (f.min or 0)
    if total <= 0 then return 1, 1, true end
    local fait = math.max(0, math.min((f.valeur or 0) - (f.min or 0), total))
    return fait, total, false
end

-- Réputation gagnée entre deux relevés de la même faction, nil sinon (autre
-- faction suivie, ou baisse).
function BarreRep.gain(avant, apres)
    if not avant or not apres then return nil end
    if (avant.id or avant.nom) ~= (apres.id or apres.nom) then return nil end
    local g = (apres.absolu or 0) - (avant.absolu or 0)
    if g < 0 then return nil end
    return g
end

-- Couleur d'un rang : celle du jeu (FACTION_BAR_COLORS), parangon en bleu.
local REPLI = {
    { 0.8, 0.13, 0.13 }, { 0.8, 0.13, 0.13 }, { 0.75, 0.27, 0 }, { 0.9, 0.7, 0 },
    { 0, 0.6, 0.1 }, { 0, 0.6, 0.1 }, { 0, 0.6, 0.1 }, { 0, 0.6, 0.1 },
}
function BarreRep.couleur(f, jeu)
    if f.parangon then return 0.2, 0.6, 1 end
    local c = jeu and jeu[f.reaction]
    if c and c.r then return c.r, c.g, c.b end
    local r = REPLI[f.reaction] or REPLI[4]
    return r[1], r[2], r[3]
end

-- Lignes de texte selon le réglage « Textes » (0 aucun, 1 essentiel, 2
-- tout) : bas1 = gagné pendant la session, bas2 = rang suivant et rythme.
-- Au rang maximum, rien sous la barre.
function BarreRep.lignesVisibles(textes, auMax)
    return { haut = false, bas1 = textes >= 2 and not auMax, bas2 = textes >= 1 and not auMax }
end
