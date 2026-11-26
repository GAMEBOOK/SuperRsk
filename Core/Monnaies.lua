-- Monnaies : un widget déplaçable avec l'or et les monnaies que le joueur
-- coche (honneur, réals...). Le jeu donne lui-même la liste, les noms (dans
-- la langue du client) et les icônes : rien n'est écrit à la main, une
-- monnaie ajoutée par Blizzard apparaît seule. Éteint par défaut.
-- Ici : la liste et ce qu'il faut afficher ; le widget est dans UI/Monnaies.lua.

local ADDON, ns = ...

local Monnaies = {}
ns.Monnaies = Monnaies

local L = ns.L or setmetatable({}, { __index = function(_, k) return k end })
local function R(cle) return ns.Reglages.get(cle) end

-- Jusqu'où chercher les monnaies du jeu (Forever en a moins de 4000).
Monnaies.MAX_ID = 5000
Monnaies.ICONE_OR = "Interface\\Icons\\INV_Misc_Coin_01"
Monnaies.ICONE_VIDE = "Interface\\Icons\\INV_Misc_QuestionMark"
Monnaies.EVENEMENTS = { "PLAYER_MONEY", "CURRENCY_DISPLAY_UPDATE", "HONOR_CURRENCY_UPDATE", "PLAYER_ENTERING_WORLD" }

-- Réglage de la case d'une monnaie.
function Monnaies.cle(id) return "monnaie" .. id end

-- Infos d'une monnaie : { id, nom, icone, quantite } ou nil.
function Monnaies.info(id)
    local api = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo
    if not api then return nil end
    local ok, c = pcall(api, id)
    if not ok or type(c) ~= "table" or type(c.name) ~= "string" or c.name == "" then return nil end
    -- Sans icône (le jeu rend 0 pour les renoms) : point d'interrogation,
    -- pour garder les noms alignés.
    local icone = c.iconFileID
    if not icone or icone == 0 or icone == "" then icone = Monnaies.ICONE_VIDE end
    return { id = id, nom = c.name, icone = icone, quantite = tonumber(c.quantity) or 0 }
end

-- Monnaies internes de Blizzard (« [DNT] ... », « [PH] ... ») : cachées.
function Monnaies.interne(nom) return type(nom) ~= "string" or nom:match("^%s*%[") ~= nil end

local liste
-- Toutes les monnaies du jeu, triées par nom (cherchées une fois).
function Monnaies.liste()
    if liste then return liste end
    local l = {}
    for id = 1, Monnaies.MAX_ID do
        local c = Monnaies.info(id)
        if c and not Monnaies.interne(c.nom) then l[#l + 1] = c end
    end
    table.sort(l, function(a, b) return a.nom < b.nom end)
    -- Rien trouvé (jeu pas encore prêt) : on recherchera plus tard.
    if #l > 0 then liste = l end
    return l
end
function Monnaies.oublier() liste = nil end

-- Ce que montre le widget, dans l'ordre : l'or puis les monnaies cochées.
-- { { id = "or" | n, nom, icone, quantite } }
function Monnaies.lignes(exemple)
    local t = {}
    if R("monnaieOr") ~= false then
        t[1] = { id = "or", nom = L["Or"], icone = Monnaies.ICONE_OR,
                 quantite = exemple and 1523410 or (ns.Jeu.argent() or 0) }
    end
    local zero = R("monnaiesZero") ~= false
    for _, c in ipairs(Monnaies.liste()) do
        if R(Monnaies.cle(c.id)) then
            local q = c.quantite
            local frais = Monnaies.info(c.id)
            if frais then q = frais.quantite end
            if exemple and q == 0 then q = 37 end
            if zero or q > 0 then t[#t + 1] = { id = c.id, nom = c.nom, icone = c.icone, quantite = q } end
        end
    end
    return t
end

-- « 12 450 » : espaces fines entre les milliers.
function Monnaies.nombre(n)
    local s = tostring(math.floor(tonumber(n) or 0))
    local signe, chiffres = s:match("^(-?)(%d+)$")
    if not chiffres then return s end
    return signe .. chiffres:reverse():gsub("(%d%d%d)", "%1 "):reverse():gsub("^ ", "")
end

-- L'or selon le format choisi : « complet » (po pa pc) ou « or » (po seules).
function Monnaies.texteOr(cuivre)
    cuivre = math.floor(tonumber(cuivre) or 0)
    if R("monnaiesOrFormat") == "or" then
        local po = math.floor(cuivre / 10000)
        local tex = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t"
        return Monnaies.nombre(po) .. tex
    end
    return ns.Jeu.texteArgent(cuivre)
end

function Monnaies.texte(ligne)
    if ligne.id == "or" then return Monnaies.texteOr(ligne.quantite) end
    return Monnaies.nombre(ligne.quantite)
end

-- Une case par monnaie du jeu dans la carte « Monnaies » du module (à la
-- connexion : avant, le jeu ne connaît pas encore les noms).
-- Honneur (1792) coché par défaut : repéré par son ID, jamais par son nom.
local DEFAUT_COCHEES = { [1792] = true }
local cases = false
function Monnaies.inscrireCases()
    if cases or not ns.Reglages.ajouterOption then return end
    local l = Monnaies.liste()
    if #l == 0 then return end
    cases = true
    for _, c in ipairs(l) do
        local icone = c.icone and ("|T" .. c.icone .. ":16:16:0:0|t ") or ""
        ns.Reglages.ajouterOption("monnaies", 2, {
            cle = Monnaies.cle(c.id), type = "case", libelle = icone .. c.nom,
        }, DEFAUT_COCHEES[c.id] == true)
    end
end
