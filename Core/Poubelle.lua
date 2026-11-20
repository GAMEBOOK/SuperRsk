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

-- L'objet à proposer : celui qui vaut le moins, puis la plus petite pile.
function Poubelle.candidat(liste)
    local choix, vChoix
    for _, o in ipairs(liste or {}) do
        local v = Poubelle.valeur(o)
        if not choix or v < vChoix or (v == vChoix and o.nombre < choix.nombre) then
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

-- Sacs pleins : propose le candidat (ou dit qu'il n'y a rien à jeter).
function Poubelle.surPlein()
    if R("butinPoubelle") == false then return nil end
    local c = Poubelle.candidat(ns.Jeu.objetsMediocres())
    if c then
        if Poubelle.proposer then Poubelle.proposer(c) end
        return c
    end
    local t = GetTime and GetTime() or 0
    if t - dernierRien >= Poubelle.RAPPEL then
        dernierRien = t
        local n = ns.Menage and R("menageActif") ~= false and ns.Menage.nbSurs() or 0
        if n > 0 then
            ns.Jeu.message(L["Sacs pleins, aucun gris à jeter, mais %d objets de quête ne servent plus : /sg menage."]:format(n))
        else
            ns.Jeu.message(L["Sacs pleins, et aucun objet gris à jeter."])
        end
    end
    return nil
end

-- Clic sur « Jeter » : seulement si c'est toujours le même objet au même endroit.
function Poubelle.jeter(c)
    if not c or ns.Jeu.lienSac(c.sac, c.case) ~= c.lien then
        ns.Jeu.message(L["L'objet a bougé dans tes sacs : rien n'a été jeté."])
        return false
    end
    if not ns.Jeu.jeter(c.sac, c.case) then return false end
    ns.Jeu.message(L["Jeté : %s (%s)."]:format(c.lien, Poubelle.textePrix(c)))
    return true
end
