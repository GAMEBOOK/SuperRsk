-- Usure : quand une pièce portée passe sous le seuil (20 % par défaut), un
-- petit widget le montre, avec un son et un message une seule fois. Il
-- disparaît après réparation. Affichage dans UI/Usure.lua.

local ADDON, ns = ...

local Usure = {}
ns.Usure = Usure

local L = ns.L or setmetatable({}, { __index = function(_, k) return k end })
local function R(cle) return ns.Reglages.get(cle) end

-- État de l'équipement : pièce la plus usée et pièces sous le seuil.
-- { pourcent = 0..100 ou nil sans pièce qui s'use, case, sous = { … } }
function Usure.etat(pieces, seuil)
    local e = { sous = {} }
    for _, p in ipairs(pieces or {}) do
        local pc = math.floor(p.actuel / p.max * 100 + 0.5)
        if not e.pourcent or pc < e.pourcent then e.pourcent, e.case = pc, p.case end
        if pc < seuil then e.sous[#e.sous + 1] = { case = p.case, pourcent = pc } end
    end
    table.sort(e.sous, function(a, b) return a.pourcent < b.pourcent end)
    return e
end

function Usure.seuil() return tonumber(R("usureSeuil")) or 20 end

-- Couleur selon l'état : rouge (cassé ou presque), orange, jaune.
function Usure.couleur(pourcent)
    if pourcent <= 5 then return "rouge" end
    if pourcent <= 15 then return "orange" end
    return "jaune"
end

local prevenu = false

-- Relit l'usure ; prévient (son, message) une fois en passant sous le seuil,
-- et de nouveau seulement après une réparation. Rend l'état.
function Usure.verifier()
    local e = Usure.etat(ns.Jeu.usure(), Usure.seuil())
    local alerte = R("usureActif") ~= false and #e.sous > 0
    if alerte and not prevenu then
        prevenu = true
        if R("usureMessage") ~= false then
            ns.Jeu.message(L["Équipement usé : %d %% sur la pièce la plus abîmée. Pense à réparer."]:format(e.pourcent))
        end
        if R("usureSon") ~= false and ns.Jeu.jouerSon then ns.Jeu.jouerSon("alerte") end
    elseif not alerte then
        prevenu = false
    end
    e.alerte = alerte
    Usure.dernier = e
    if Usure.afficher then Usure.afficher(e) end
    return e
end

Usure.EVENEMENTS = { "UPDATE_INVENTORY_DURABILITY", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_ENTERING_WORLD" }

function Usure.appliquer(cle)
    if type(cle) == "string" and cle:find("^usure") then Usure.verifier() end
end
