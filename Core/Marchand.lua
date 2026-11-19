-- Marchand : chez un marchand, les objets gris partent et l'équipement est
-- réparé, sans clic. Maj enfoncé à l'ouverture : rien ne se fait.
-- Le jeu n'est appelé que par ns.Jeu.

local ADDON, ns = ...

local Marchand = {}
ns.Marchand = Marchand

local L = ns.L or setmetatable({}, { __index = function(_, k) return k end })
local function R(cle) return ns.Reglages.get(cle) end

Marchand.PAR_LOT = 10      -- objets vendus d'un coup
Marchand.PAUSE = 0.25      -- entre deux lots (le serveur n'aime pas les rafales)

local vente   -- { reste = { … }, total, nombre } pendant une vente

-- Répare tout si le marchand sait le faire. Rend le coût payé (0 sinon)
-- et true si c'est la guilde qui a payé.
function Marchand.reparer()
    local jeu = ns.Jeu
    if not R("marchandReparer") or not jeu.peutReparer() then return 0 end
    local cout = jeu.coutReparation()
    if cout <= 0 then return 0 end
    if R("marchandGuilde") and jeu.peutReparerGuilde() then
        jeu.reparer(true)
        return cout, true
    end
    if jeu.argent() < cout then
        jeu.message(L["Pas assez d'or pour tout réparer (%s)."]:format(jeu.texteArgent(cout)))
        return 0
    end
    jeu.reparer(false)
    return cout, false
end

local function finVente()
    local v = vente
    vente = nil
    if v and v.nombre > 0 and R("marchandMessage") then
        ns.Jeu.message(L["%d objet(s) gris vendu(s) : %s."]:format(v.nombre, ns.Jeu.texteArgent(v.total)))
    end
end

-- Un lot, puis le suivant un peu plus tard tant que le marchand est ouvert.
local function lot()
    local v = vente
    if not v then return end
    if not ns.Jeu.marchandOuvert() then return finVente() end
    for _ = 1, Marchand.PAR_LOT do
        local o = table.remove(v.reste, 1)
        if not o then break end
        ns.Jeu.vendre(o.sac, o.case)
        v.total, v.nombre = v.total + o.prix, v.nombre + 1
    end
    if #v.reste > 0 then ns.Jeu.plusTard(Marchand.PAUSE, lot) else finVente() end
end

-- Vend les objets gris. Rend leur nombre.
function Marchand.vendreGris()
    if not R("marchandVendre") or vente then return 0 end
    local gris = ns.Jeu.objetsGris()
    if #gris == 0 then return 0 end
    vente = { reste = gris, total = 0, nombre = 0 }
    lot()
    return #gris
end

function Marchand.surOuverture()
    if not R("marchandActif") then return end
    if ns.Jeu.majEnfonce() then return end
    local cout, guilde = Marchand.reparer()
    if cout > 0 and R("marchandMessage") then
        ns.Jeu.message((guilde and L["Réparé avec l'argent de la guilde : %s."] or L["Réparé : %s."]):format(ns.Jeu.texteArgent(cout)))
    end
    Marchand.vendreGris()
end

function Marchand.surFermeture() if vente then finVente() end end

Marchand.evenements = { MERCHANT_SHOW = Marchand.surOuverture, MERCHANT_CLOSED = Marchand.surFermeture }
