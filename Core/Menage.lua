-- Ménage des objets de quête : les objets de quête de tes sacs qui ne servent
-- plus, à jeter sur demande. Rien n'est jeté sans ton clic.
--
--   sûr       Questie connaît l'objet et toutes ses quêtes sont terminées
--             (coché d'office)
--   probable  Questie ne le connaît pas (ou n'est pas là) et aucune quête de
--             ton journal ne le nomme (pas coché : à toi de voir)
--
-- Un objet lié à une quête en cours, ou à une quête pas encore faite (suite
-- d'une chaîne, objet qui commence une quête), est gardé.
-- Fenêtre dans UI/Menage.lua. Le jeu n'est appelé que par ns.Jeu.

local ADDON, ns = ...

local Menage = {}
ns.Menage = Menage

local L = ns.L or setmetatable({}, { __index = function(_, k) return k end })
local function R(cle) return ns.Reglages.get(cle) end

-- Texte comparable : minuscules (accents majuscules compris), sans codes de
-- couleur ni de lien, une seule forme d'apostrophe, espaces simples.
local MAJUSCULES = { ["À"] = "à", ["Â"] = "â", ["Ä"] = "ä", ["Ç"] = "ç", ["É"] = "é", ["È"] = "è",
                     ["Ê"] = "ê", ["Ë"] = "ë", ["Î"] = "î", ["Ï"] = "ï", ["Ô"] = "ô", ["Ö"] = "ö",
                     ["Ù"] = "ù", ["Û"] = "û", ["Ü"] = "ü", ["Œ"] = "œ" }
function Menage.normaliser(t)
    if type(t) ~= "string" then return "" end
    t = t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h", ""):gsub("|h", "")
    t = t:gsub("\226\128\153", "'"):gsub("\226\128\152", "'"):gsub("`", "'")
    for maj, min in pairs(MAJUSCULES) do t = t:gsub(maj, min) end
    return (t:lower():gsub("%s+", " "))
end

-- Tri d'un objet, du plus sûr au moins sûr ; au moindre doute, gardé.
--   1. une quête en cours le nomme : gardé (ton journal fait foi)
--   2. il commence une quête : gardé tant qu'elle n'est pas faite
--   3. Questie le connaît : gardé si une de ses quêtes est en cours ou pas
--      faite, sûr si toutes sont terminées
--   4. rien de tout ça : probable (pas coché)
-- infos = { quetes(id) -> {questID}|nil, faite(q), enCours(q), texte
-- (normalisé) }. Rend nil (gardé) ou { sur, raison }, et le motif.
function Menage.juger(o, infos)
    local nom = Menage.normaliser(o.nom)
    if nom ~= "" and infos.texte:find(nom, 1, true) then return nil, "nommé par une quête en cours" end
    local q = infos.objetsEnCours and infos.objetsEnCours[o.id]
    if q then return nil, "utilisé par la quête " .. q .. " en cours (Questie)" end
    local quetes = {}
    if o.queteDebut then quetes[#quetes + 1] = o.queteDebut end
    for _, q in ipairs(infos.quetes(o.id) or {}) do quetes[#quetes + 1] = q end
    if #quetes > 0 then
        for _, q in ipairs(quetes) do
            if infos.enCours(q) then return nil, "quête " .. q .. " en cours" end
            if not infos.faite(q) then return nil, "quête " .. q .. " pas encore faite" end
        end
        return { sur = true, raison = #quetes > 1 and L["toutes ses quêtes sont terminées"] or L["sa quête est terminée"] },
            "quêtes terminées : " .. table.concat(quetes, ", ")
    end
    return { sur = false, raison = L["aucune quête en cours n'en parle"] }, "inconnu de Questie, nommé par aucune quête"
end

-- Objets à proposer, les sûrs d'abord : { { objet, sur, raison } }.
function Menage.analyser(objets, infos)
    local liste = {}
    for _, o in ipairs(objets) do
        local j = Menage.juger(o, infos)
        if j then liste[#liste + 1] = { objet = o, sur = j.sur, raison = j.raison } end
    end
    table.sort(liste, function(a, b)
        if a.sur ~= b.sur then return a.sur end
        return (a.objet.nom or "") < (b.objet.nom or "")
    end)
    return liste
end

function Menage.infosJeu()
    local jeu = ns.Jeu
    local texte, journal = jeu.texteQuetesEnCours()
    journal = journal or {}
    return { quetes = jeu.quetesObjet, faite = jeu.queteFaite,
             enCours = function(q) return journal[q] or jeu.queteEnCours(q) end,
             objetsEnCours = jeu.objetsQuetesEnCours and jeu.objetsQuetesEnCours(journal) or {},
             texte = Menage.normaliser(texte) }
end

function Menage.liste() return Menage.analyser(ns.Jeu.objetsQuete(), Menage.infosJeu()) end

-- /sg menage ? : chaque objet de quête des sacs et pourquoi il est gardé
-- ou proposé (diagnostic).
function Menage.expliquer()
    local infos, lignes = Menage.infosJeu(), {}
    if ns.Jeu.etatIndexQuestie then lignes[1] = "index Questie : " .. ns.Jeu.etatIndexQuestie() end
    for _, o in ipairs(ns.Jeu.objetsQuete()) do
        local j, motif = Menage.juger(o, infos)
        local verdict = not j and "gardé" or (j.sur and "sûr" or "probable")
        lignes[#lignes + 1] = ("%s : %s (%s)"):format(o.lien, verdict, motif)
    end
    if #ns.Jeu.objetsQuete() == 0 then lignes[#lignes + 1] = L["Aucun objet de quête dans tes sacs."] end
    return lignes
end

-- Jette les objets cochés, chacun seulement s'il est toujours à sa place.
-- Rend le nombre d'objets jetés.
function Menage.jeter(selection)
    local jeu, n = ns.Jeu, 0
    for _, e in ipairs(selection) do
        local o = e.objet
        if jeu.lienSac(o.sac, o.case) == o.lien and jeu.jeter(o.sac, o.case) then n = n + 1 end
    end
    if n > 0 then
        jeu.message(L["Ménage : %d objets de quête jetés."]:format(n))
    elseif #selection > 0 then
        jeu.message(L["Les objets ont bougé dans tes sacs : rien n'a été jeté. Rouvre le ménage."])
    end
    return n
end

-- Après une quête rendue : les objets devenus sûrement inutiles, signalés
-- une fois chacun.
local signales = {}
Menage.enAttente = false
function Menage.verifier()
    if R("menageActif") == false then return end
    if ns.Jeu.enCombat() then Menage.enAttente = true; return end
    Menage.enAttente = false
    local nouveaux = {}
    for _, e in ipairs(Menage.liste()) do
        if e.sur and not signales[e.objet.lien] then
            signales[e.objet.lien] = true
            nouveaux[#nouveaux + 1] = e.objet.lien
        end
    end
    if #nouveaux > 0 then
        ns.Jeu.message(L["Ne sert plus (quête terminée) : %s. /sg menage pour faire le ménage."]:format(table.concat(nouveaux, ", ")))
    end
    return nouveaux
end

-- Nombre d'objets sûrement inutiles (pour la Poubelle, sacs pleins).
function Menage.nbSurs()
    local n = 0
    for _, e in ipairs(Menage.liste()) do if e.sur then n = n + 1 end end
    return n
end
