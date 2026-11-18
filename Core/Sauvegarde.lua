-- Sauvegarde des réglages en texte, pour les copier sur un autre compte WoW
-- ou les retrouver après une réinstallation.
--
-- Format « SuperGuide1: » suivi d'une valeur : T / F (booléens), n<nombre>;,
-- s<longueur>:<octets>, {clé valeur clé valeur …}. Lu par un petit lecteur
-- maison : un texte collé n'est jamais exécuté.

local ADDON, ns = ...

local Sauvegarde = {}
ns.Sauvegarde = Sauvegarde

local PREFIXE = "SuperGuide1:"
local PROFONDEUR_MAX = 10

-- Hors réglages du menu : positions et tailles, mesures du tir.
Sauvegarde.EN_PLUS = { fenetre = true, fleche = true, largeur = true, minimapAngle = true,
                       positions = true, tirMesures = true, volsDurees = true, marqueursListe = true }

local function nombre(v)
    local s = ("%.14g"):format(v)
    if tonumber(s) ~= v then s = ("%.17g"):format(v) end
    return "n" .. s .. ";"
end

local function triees(t)
    local cles = {}
    for k in pairs(t) do cles[#cles + 1] = k end
    table.sort(cles, function(a, b)
        if type(a) ~= type(b) then return type(a) == "number" end
        return a < b
    end)
    return cles
end

local function valeur(v, morceaux)
    local genre = type(v)
    if genre == "boolean" then
        morceaux[#morceaux + 1] = v and "T" or "F"
    elseif genre == "number" then
        morceaux[#morceaux + 1] = nombre(v)
    elseif genre == "string" then
        morceaux[#morceaux + 1] = "s" .. #v .. ":" .. v
    elseif genre == "table" then
        morceaux[#morceaux + 1] = "{"
        for _, k in ipairs(triees(v)) do
            valeur(k, morceaux)
            valeur(v[k], morceaux)
        end
        morceaux[#morceaux + 1] = "}"
    end
end

function Sauvegarde.ecrire(t)
    local morceaux = { PREFIXE }
    valeur(t, morceaux)
    return table.concat(morceaux)
end

-- Lit une valeur à la position i ; rend valeur, position suivante, ou nil, erreur.
local function lireValeur(s, i, prof)
    local c = s:sub(i, i)
    if c == "T" then return true, i + 1 end
    if c == "F" then return false, i + 1 end
    if c == "n" then
        local fin = s:find(";", i + 1, true)
        local v = fin and tonumber(s:sub(i + 1, fin - 1))
        if not v then return nil, "nombre illisible" end
        return v, fin + 1
    end
    if c == "s" then
        local n, debut = s:match("^s(%d+):()", i)
        n = tonumber(n)
        if not n or debut + n - 1 > #s then return nil, "texte coupé" end
        return s:sub(debut, debut + n - 1), debut + n
    end
    if c == "{" then
        if prof >= PROFONDEUR_MAX then return nil, "trop imbriqué" end
        local t = {}
        i = i + 1
        while s:sub(i, i) ~= "}" do
            if i > #s then return nil, "table coupée" end
            local k, v
            k, i = lireValeur(s, i, prof + 1)
            if type(k) ~= "string" and type(k) ~= "number" then return nil, i or "clé illisible" end
            v, i = lireValeur(s, i, prof + 1)
            if v == nil then return nil, i end
            t[k] = v
        end
        return t, i + 1
    end
    return nil, "caractère inattendu"
end

-- Texte collé -> table, ou nil et la raison.
function Sauvegarde.lire(texte)
    texte = (texte or ""):match("^%s*(.-)%s*$")
    if texte:sub(1, #PREFIXE) ~= PREFIXE then return nil, "pas un texte de SuperRsk" end
    local t, fin = lireValeur(texte, #PREFIXE + 1, 0)
    if type(t) ~= "table" then return nil, type(fin) == "string" and fin or "texte abîmé" end
    if fin ~= #texte + 1 then return nil, "texte abîmé" end
    return t
end

-- Chaque réglage du menu avec sa valeur actuelle (défaut compris : l'import
-- remplace tout), plus EN_PLUS ; le reste (cache…) n'est pas exporté.
function Sauvegarde.exporter(db, defauts)
    db = db or {}
    local t = {}
    for k, d in pairs(defauts) do
        if db[k] == nil then t[k] = d else t[k] = db[k] end
    end
    for k in pairs(Sauvegarde.EN_PLUS) do t[k] = db[k] end
    return Sauvegarde.ecrire(t)
end

-- Type attendu de chaque clé EN_PLUS.
local TYPES = { fenetre = "table", fleche = "table", largeur = "number", minimapAngle = "number",
                positions = "table", tirMesures = "table", volsDurees = "table", marqueursListe = "table" }

-- Applique une sauvegarde lue : les réglages du menu passent par
-- Reglages.set (valeurs bornées ou refusées), le reste est vérifié par type ;
-- les clés inconnues sont ignorées. Rend le nombre de valeurs reprises.
-- Les positions ne servent qu'au prochain chargement : l'appelant recharge
-- l'interface.
function Sauvegarde.importer(t)
    local R = ns.Reglages
    local n = 0
    for k, v in pairs(t) do
        if type(k) ~= "string" then
            -- clé illisible : ignorée
        elseif R.option(k) then
            if R.set(k, v) then n = n + 1 end
        elseif Sauvegarde.EN_PLUS[k] and type(v) == TYPES[k] then
            SuperGuideDB = SuperGuideDB or {}
            SuperGuideDB[k] = v
            n = n + 1
        end
    end
    return n
end
