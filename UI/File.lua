-- File d'attente des fenêtres de question (proposition d'Auto Equip,
-- Poubelle, et celles à venir) : une seule à la fois, les autres attendent
-- leur tour dans l'ordre d'arrivée. Quand celle affichée se ferme, la
-- suivante s'ouvre. Une source qui redemande met à jour sa place (pas de
-- doublon). Chaque fenêtre peut afficher « +N en attente ».
--
--   File.demander(id, ouvrir)  ouvrir() affiche la fenêtre de cette source
--   File.fini(id)              la fenêtre de cette source vient de se fermer
--   File.retirer(id)           la source n'a plus rien à demander
--   File.enAttente()           nombre de fenêtres qui attendent
--   File.ecouter(f)            f() à chaque changement (compteurs)

local ADDON, ns = ...

local File = {}
ns.File = File

local actif            -- { id, ouvrir } affiché
local attente = {}     -- { { id, ouvrir }, … } dans l'ordre d'arrivée
local ecouteurs = {}

local function prevenir() for _, f in ipairs(ecouteurs) do pcall(f) end end

function File.ecouter(f) ecouteurs[#ecouteurs + 1] = f end
function File.enAttente() return #attente end
function File.actif() return actif and actif.id or nil end

local function ouvrirSuivant()
    actif = table.remove(attente, 1)
    if actif then actif.ouvrir() end
    prevenir()
end

function File.demander(id, ouvrir)
    if actif and actif.id == id then
        -- Déjà affichée : la fenêtre se met à jour sur place.
        actif.ouvrir = ouvrir
        ouvrir()
        prevenir()
        return "affichee"
    end
    for _, e in ipairs(attente) do
        if e.id == id then e.ouvrir = ouvrir; prevenir(); return "attente" end
    end
    if actif then
        attente[#attente + 1] = { id = id, ouvrir = ouvrir }
        prevenir()
        return "attente"
    end
    actif = { id = id, ouvrir = ouvrir }
    ouvrir()
    prevenir()
    return "affichee"
end

function File.fini(id)
    if not (actif and actif.id == id) then return end
    ouvrirSuivant()
end

function File.retirer(id)
    for i = #attente, 1, -1 do
        if attente[i].id == id then table.remove(attente, i) end
    end
    prevenir()
end

-- Pour les tests : file vide.
function File.vider() actif, attente = nil, {} end
