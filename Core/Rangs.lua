-- Auto Spell Ranks : garde les barres d'action sur le plus haut rang connu.
--
-- Décisions pures ; UI/Rangs.lua lit le grimoire et les barres, puis fait
-- les échanges hors combat.

local ADDON, ns = ...

local Rangs = {}
ns.Rangs = Rangs
local L = ns.L or setmetatable({}, { __index = function(_, k) return k end })

-- « Rang 4 », « Rank 4 »… -> 4 ; sort sans rang -> nil.
function Rangs.numero(texte)
    return texte and tonumber(texte:match("(%d+)")) or nil
end

-- sorts = { { id, nom, rang, texte } } -> nom -> { id, rang, texte } du plus haut rang.
function Rangs.meilleurs(sorts)
    local m = {}
    for _, s in ipairs(sorts) do
        if s.rang and (not m[s.nom] or s.rang > m[s.nom].rang) then
            m[s.nom] = { id = s.id, rang = s.rang, texte = s.texte }
        end
    end
    return m
end

-- boutons = { { slot, id, nom, rang } } (sorts simples seulement) ->
-- échanges { { slot, id } } et bilan par sort { { nom, texte, nombre } }.
-- Jamais vers un rang plus bas.
function Rangs.plan(boutons, meilleurs)
    local echanges, bilan, parNom = {}, {}, {}
    for _, b in ipairs(boutons) do
        local m = meilleurs[b.nom]
        if m and b.rang and m.rang > b.rang then
            echanges[#echanges + 1] = { slot = b.slot, id = m.id }
            local l = parNom[b.nom]
            if not l then
                l = { nom = b.nom, texte = m.texte, nombre = 0 }
                parNom[b.nom] = l
                bilan[#bilan + 1] = l
            end
            l.nombre = l.nombre + 1
        end
    end
    return echanges, bilan
end

function Rangs.message(l)
    return L[l.nombre > 1 and "%s → %s (%d boutons)" or "%s → %s (%d bouton)"]:format(l.nom, l.texte, l.nombre)
end
