-- Poubelle : sacs pleins pendant le ramassage, on propose de jeter l'objet
-- gris qui vaut le moins (d'abord ceux sans valeur). Rien n'est jeté sans
-- le clic du joueur ; juste avant, on revérifie que l'objet est toujours là.
-- Affichage dans UI/Poubelle.lua. Le jeu n'est appelé que par ns.Jeu.

local ADDON, ns = ...

local Poubelle = {}
ns.Poubelle = Poubelle

local L = ns.L or setmetatable({}, { __index = function(_, k) return k end })
local function R(cle) return ns.Reglages.get(cle) end

Poubelle.RAPPEL = 30   -- « rien à jeter » au plus toutes les 30 s

-- Ce que vaut l'objet : le plus haut du prix marchand et du prix à l'HV
-- (on ne propose pas de jeter un gris qui se vend bien à l'hôtel des ventes).
function Poubelle.valeur(o) return math.max(o.prix or 0, o.hv or 0) end

-- L'objet à proposer : celui qui vaut le moins (gris ou blanc, c'est le
-- prix qui compte : un gris peut valoir plus qu'un blanc). À valeur égale,
-- le gris d'abord, puis la plus petite pile.
local function avant(o, v, choix, vChoix)
    if v ~= vChoix then return v < vChoix end
    if (o.commun or false) ~= (choix.commun or false) then return not o.commun end
    return o.nombre < choix.nombre
end
function Poubelle.candidat(liste)
    local choix, vChoix
    for _, o in ipairs(liste or {}) do
        local v = Poubelle.valeur(o)
        if not choix or avant(o, v, choix, vChoix) then
            choix, vChoix = o, v
        end
    end
    return choix
end

-- « Marchand : 12 pc · HV : 1 pa » (HV : « pas de scan » sans prix).
function Poubelle.textePrix(c)
    local jeu = ns.Jeu
    local m = c.prix > 0 and jeu.texteArgent(c.prix) or L["sans valeur"]
    local h = c.hv and jeu.texteArgent(c.hv) or L["pas de scan"]
    return L["Marchand : %s · HV : %s"]:format(m, h)
end

local dernierRien = -1000

-- Sacs pleins : on propose ce qui coûte le moins à perdre.
--   1. un objet sans valeur (gris ou blanc) : on le jette, il ne vaut rien ;
--   2. sinon des objets de quête finis : le ménage (ils ne servent plus) ;
--   3. sinon l'objet, gris ou blanc, qui vaut le moins.
-- Les blancs écartent nourriture, potions, réactifs, munitions, quête…
function Poubelle.surPlein()
    if R("butinPoubelle") == false then return nil end
    local tous = {}
    for _, o in ipairs(ns.Jeu.objetsMediocres()) do tous[#tous + 1] = o end
    for _, o in ipairs(ns.Jeu.objetsCommuns and ns.Jeu.objetsCommuns() or {}) do tous[#tous + 1] = o end
    local c = Poubelle.candidat(tous)
    local n = ns.Menage and R("menageActif") ~= false and ns.Menage.nbSurs() or 0
    if n > 0 and not (c and Poubelle.valeur(c) == 0) then c = { menage = n } end
    if c then
        if Poubelle.proposer then Poubelle.proposer(c) end
        return c
    end
    local t = GetTime and GetTime() or 0
    if t - dernierRien >= Poubelle.RAPPEL then
        dernierRien = t
        ns.Jeu.message(L["Sacs pleins, et rien que l'on puisse jeter sans risque."])
    end
    return nil
end

-- Clic sur « Jeter » : seulement si c'est toujours le même objet au même endroit.
function Poubelle.jeter(c)
    if not c or ns.Jeu.lienSac(c.sac, c.case) ~= c.lien then
        ns.Jeu.message(L["L'objet a bougé dans tes sacs : rien n'a été jeté."])
        return false
    end
    return ns.Jeu.jeter(c.sac, c.case) and true or false
end

-- Le joueur a confirmé la destruction dans la fenêtre du jeu.
function Poubelle.confirmer(c)
    ns.Jeu.message(L["Jeté : %s (%s)."]:format(c.lien, Poubelle.textePrix(c)))
end
