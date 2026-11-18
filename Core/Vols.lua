-- Points de vol : tous les maîtres de vol sur la carte du monde, connus ou
-- non. Les données viennent de la bibliothèque FlightMasterData (Libs/) ;
-- les points connus sont notés par personnage chez les maîtres de vol.
-- Ici, les choix purs ; UI/Vols.lua pose les icônes.

local ADDON, ns = ...

local Vols = {}
ns.Vols = Vols

-- Points à poser sur la carte uiMapID. api = FlightMasterData_API (nil si
-- absente) ; connus = { [nodeID] = true } ; avecConnus = afficher aussi ceux-là.
-- Visibilité inconnue (nil : condition illisible) : on affiche.
function Vols.points(api, carte, connus, avecConnus)
    local l = {}
    if not (api and carte) then return l end
    for id in api.IterateNodes() do
        local connu = connus[id] == true
        if (avecConnus or not connu) and api.IsNodeVisible(id) ~= false then
            local pos = api.GetNodeMapPosition(id, carte)
            if pos then
                l[#l + 1] = { id = id, x = pos.x, y = pos.y, nom = api.GetNodeName(id), connu = connu }
            end
        end
    end
    return l
end

-- Carte d'un maître de vol (C_TaxiMap.GetAllTaxiNodes) : tout nœud qui n'est
-- pas « injoignable » est connu de ce personnage.
function Vols.noterConnus(connus, noeuds, injoignable)
    for _, n in ipairs(noeuds or {}) do
        if n.nodeID and n.state ~= injoignable then connus[n.nodeID] = true end
    end
end

-- Carte du monde (C_TaxiMap.GetTaxiNodesForMap) : isUndiscovered == false
-- veut dire découvert ; absent, on ne conclut rien.
function Vols.noterDecouverts(connus, noeuds)
    for _, n in ipairs(noeuds or {}) do
        if n.nodeID and n.isUndiscovered == false then connus[n.nodeID] = true end
    end
end

---------------------------------------------------------------------------
-- Temps de vol : appris par trajet (origine > destination, en nodeID)
---------------------------------------------------------------------------

local VOL_MIN = 10 -- un « vol » plus court est un aller-retour annulé

local function cle(a, b) return a .. ">" .. b end

function Vols.apprendre(durees, a, b, d)
    if not (a and b and d) or d < VOL_MIN then return end
    durees[cle(a, b)] = math.floor(d + 0.5)
end

function Vols.dureeConnue(durees, a, b)
    if not (a and b) then return nil end
    return durees[cle(a, b)]
end

-- « m:ss » : le temps restant s'il est connu (jamais négatif), sinon l'écoulé.
function Vols.texteVol(restant, ecoule)
    local s = restant and math.max(0, restant) or ecoule or 0
    s = math.floor(s + 0.5)
    return ("%d:%02d"):format(math.floor(s / 60), s % 60)
end

---------------------------------------------------------------------------
-- Vol automatique (.fly <lieu>) : les guides écrivent le lieu en anglais
---------------------------------------------------------------------------

local ICONE_TAXI = 132057 -- Interface\GossipFrame\TaxiGossipIcon

-- Option « Montre-moi où je peux voler » d'un dialogue (C_GossipInfo.GetOptions).
function Vols.optionTaxi(options)
    for _, o in ipairs(options or {}) do
        if o.icon == ICONE_TAXI or o.type == "taxi" then return o.gossipOptionID end
    end
end

local function contient(nom, lieu)
    return nom ~= nil and nom:lower():find(lieu:lower(), 1, true) ~= nil
end

-- Nœud de la carte du maître de vol (C_TaxiMap.GetAllTaxiNodes) dont le nom
-- anglais contient le lieu du guide, parmi ceux qu'on peut rejoindre.
function Vols.noeudPour(lieu, noeuds, anglais, joignable)
    if not lieu then return nil end
    for _, n in ipairs(noeuds or {}) do
        if n.state == joignable and contient(anglais[n.nodeID] or n.name, lieu) then return n end
    end
end

-- Nom du lieu dans la langue du client (FlightMasterData), nil si inconnu.
function Vols.nomLocal(lieu, api, anglais)
    if not (lieu and api) then return nil end
    local ids = {}
    for id in pairs(anglais) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        if contient(anglais[id], lieu) then return api.GetNodeName(id) end
    end
end
