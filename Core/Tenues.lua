-- Auto Sets : des tenues qui se mettent toutes seules (monture, récolte,
-- métier, nage, ville, champ de bataille, donjon) et ton équipement qui
-- revient ensuite.
--
-- Une tenue = une catégorie (ce qu'on cherche dans les info-bulles : « vitesse
-- de la monture », « +5 Herboristerie »…), une condition (quand la mettre) et
-- des pièces par emplacement. Les pièces se choisissent toutes seules (le
-- meilleur bonus de tes sacs et de ton équipement) ; une pièce choisie à la
-- main est épinglée et n'est plus changée. Seuls les emplacements de la
-- tenue changent ; ce qu'ils portaient avant est retenu et remis.
--
-- Jamais en combat, pendant une incantation, mort ou pendant Auto Fishing :
-- on attend. Données par personnage : SuperGuideCharDB.tenues (la liste,
-- dans l'ordre de priorité) et SuperGuideCharDB.tenuesEtat (tenue mise et
-- pièces d'avant).

local ADDON, ns = ...

local Tenues = {}
ns.Tenues = Tenues

local L = ns.L or setmetatable({}, { __index = function(_, k) return k end })
local function R(cle) return ns.Reglages.get(cle) end

---------------------------------------------------------------------------
-- Catégories : ce qu'on cherche et quand la tenue se met par défaut.
---------------------------------------------------------------------------

-- Objets et enchantements reconnus par leur numéro, dans toutes les langues :
-- { id = objet, valeur } ou { enchant = numéro, valeur }.
local MONTURE_IDS = {
    { id = 11122, valeur = 3 },      -- Carotte au bout d'un bâton
    { id = 25653, valeur = 10 },     -- Cravache
    { id = 32863, valeur = 10 },     -- Fouet de Brise-ciel
    { enchant = 464, valeur = 4 },   -- Éperons en mithril
    { enchant = 930, valeur = 2 },   -- Gants : monte
}

local MONTURE = {
    "vitesse de votre monture", "vitesse de la monture", "vitesse des montures", "vitesse de monture",
    "vitesse en monture", "vitesse de monte", "compétence de monte",
    "mount speed", "mounted movement speed", "mounted speed", "riding skill",
    "reittiertempo", "reitgeschwindigkeit", "velocidad de montura", "velocidad con montura",
    "скорость передвижения верхом", "скорость верховой езды", "velocidade montado", "velocità in sella",
    { "éperons en mithril", seul = true }, { "mithril spurs", seul = true },
}

-- recolte : métier de récolte (condition au survol) ; metier : la tenue se
-- met quand la fenêtre de ce métier est ouverte.
Tenues.TYPES = {
    { cle = "monture", nom = L["Monture"], quand = "monture", mots = MONTURE, ids = MONTURE_IDS,
      aide = L["Carotte au bout d'un bâton, éperons, gants de monte : en selle, plus vite."] },
    { cle = "herbes", nom = L["Herboristerie"], quand = "herbes", recolte = true,
      mots = { "herboristerie", "herbalism" }, aide = L["Au survol d'une plante."] },
    { cle = "minage", nom = L["Minage"], quand = "minage", recolte = true,
      mots = { "minage", "mining" }, aide = L["Au survol d'un filon."] },
    { cle = "depecage", nom = L["Dépeçage"], quand = "depecage", recolte = true,
      mots = { "dépeçage", "skinning" }, aide = L["Au survol d'un corps à dépecer."] },
    { cle = "nage", nom = L["Nage"], quand = "nage",
      mots = { "vitesse de nage", "swim speed", "respirer sous l'eau", "respiration aquatique",
               "water breathing", "underwater breathing", "schwimmgeschwindigkeit", "unter wasser atmen",
               "velocidad de nado", "respirar bajo el agua", "скорость плавания", "дышать под водой",
               "velocidade de natação", "velocità di nuoto" }, aide = L["Dans l'eau."] },
    { cle = "forge", nom = L["Forge"], quand = "metier", metier = true, mots = { "forge", "blacksmithing" } },
    { cle = "cuir", nom = L["Travail du cuir"], quand = "metier", metier = true, mots = { "travail du cuir", "leatherworking" } },
    { cle = "couture", nom = L["Couture"], quand = "metier", metier = true, mots = { "couture", "tailoring" } },
    { cle = "alchimie", nom = L["Alchimie"], quand = "metier", metier = true, mots = { "alchimie", "alchemy" } },
    { cle = "ingenierie", nom = L["Ingénierie"], quand = "metier", metier = true, mots = { "ingénierie", "engineering" } },
    { cle = "enchantement", nom = L["Enchantement"], quand = "metier", metier = true, mots = { "enchantement", "enchanting" } },
    { cle = "cuisine", nom = L["Cuisine"], quand = "metier", metier = true, mots = { "cuisine", "cooking" } },
    { cle = "secourisme", nom = L["Secourisme"], quand = "metier", metier = true, mots = { "secourisme", "first aid" } },
    -- Résistances : pour un boss ou une zone (Cœur du Magma, Onyxia…).
    -- Pas de création proposée : beaucoup d'objets en ont un peu.
    { cle = "feu", nom = L["Résistance au feu"], quand = "manuel", sansProposer = true, ecole = 2,
      mots = { "résistance au feu", "fire resistance", "toutes les résistances", "all resistances" },
      aide = L["Choisis « Quand je cible… » ou « Dans une zone… » (Ragnaros, Cœur du Magma)."] },
    { cle = "nature", nom = L["Résistance à la nature"], quand = "manuel", sansProposer = true, ecole = 3,
      mots = { "résistance à la nature", "nature resistance", "toutes les résistances", "all resistances" },
      aide = L["Choisis « Quand je cible… » ou « Dans une zone… »."] },
    { cle = "givre", nom = L["Résistance au givre"], quand = "manuel", sansProposer = true, ecole = 4,
      mots = { "résistance au givre", "frost resistance", "toutes les résistances", "all resistances" },
      aide = L["Choisis « Quand je cible… » ou « Dans une zone… »."] },
    { cle = "ombre", nom = L["Résistance à l'ombre"], quand = "manuel", sansProposer = true, ecole = 5,
      mots = { "résistance à l'ombre", "shadow resistance", "toutes les résistances", "all resistances" },
      aide = L["Choisis « Quand je cible… » ou « Dans une zone… »."] },
    { cle = "arcanes", nom = L["Résistance aux arcanes"], quand = "manuel", sansProposer = true, ecole = 6,
      mots = { "résistance aux arcanes", "arcane resistance", "toutes les résistances", "all resistances" },
      aide = L["Choisis « Quand je cible… » ou « Dans une zone… »."] },
    { cle = "boss", nom = L["Contre un boss"], quand = "cible",
      aide = L["Cible le boss avant le combat : ta tenue se met. Prends ta cible avec le bouton."] },
    { cle = "zone", nom = L["Dans une zone"], quand = "zone",
      aide = L["Entre dans la zone : ta tenue se met. Prends ta zone avec le bouton."] },
    { cle = "jcj", nom = L["JcJ en extérieur"], quand = "joueur",
      aide = L["Quand tu cibles un joueur ennemi, hors combat."] },
    { cle = "ville", nom = L["En ville"], quand = "ville", aide = L["En ville et à l'auberge (zone de repos)."] },
    { cle = "bg", nom = L["Champ de bataille"], quand = "bg", aide = L["En champ de bataille et en arène."] },
    { cle = "donjon", nom = L["Donjon et raid"], quand = "donjon", aide = L["En donjon et en raid."] },
    { cle = "perso", nom = L["Personnalisée"], quand = "manuel", aide = L["Mise d'un clic, quand tu veux."] },
}

local PAR_CLE = {}
for _, t in ipairs(Tenues.TYPES) do PAR_CLE[t.cle] = t end
function Tenues.type(cle) return PAR_CLE[cle] end

-- Noms des métiers dans les langues des clients (en plus de ceux que le jeu
-- donne lui-même, voir Tenues.motsType) : de, es, ru, pt, it, ko, zh. En russe
-- avec la majuscule : le jeu ne met pas le cyrillique en minuscules.
local METIERS = {
    herbes = { "kräuterkunde", "herboristería", "Травничество", "herborismo", "erbalismo", "약초채집", "草药学", "草藥學" },
    minage = { "bergbau", "minería", "Горное дело", "mineração", "estrazione", "채광", "采矿", "採礦" },
    depecage = { "kürschnerei", "desuello", "Снятие шкур", "esfolamento", "scuoiatura", "무두질", "剥皮", "剝皮" },
    forge = { "schmiedekunst", "herrería", "Кузнечное дело", "ferraria", "forgiatura", "대장기술", "锻造", "鍛造" },
    cuir = { "lederverarbeitung", "peletería", "Кожевничество", "couraria", "conciatura", "가죽세공", "制皮", "製皮" },
    couture = { "schneiderei", "sastrería", "Портняжное дело", "alfaiataria", "sartoria", "재봉술", "裁缝", "裁縫" },
    alchimie = { "alchimie", "alquimia", "Алхимия", "alchimia", "연금술", "炼金术", "鍊金術" },
    ingenierie = { "ingenieurskunst", "ingeniería", "Инженерное дело", "engenharia", "ingegneria", "기계공학", "工程学", "工程學" },
    enchantement = { "verzauberkunst", "encantamiento", "Наложение чар", "encantamento", "incantamento", "마법부여", "附魔" },
    cuisine = { "kochkunst", "cocina", "Кулинария", "culinária", "cucina", "요리", "烹饪", "烹飪" },
    secourisme = { "erste hilfe", "primeros auxilios", "Первая помощь", "primeiros socorros", "primo soccorso", "응급치료", "急救" },
}

-- Tous les mots d'une catégorie : les nôtres, les traductions, et ce que le
-- jeu donne dans sa langue (métiers, résistances). Gardé une fois trouvé.
local locaux = {}
function Tenues.motsType(ty)
    if not ty then return {} end
    if locaux[ty.cle] then return locaux[ty.cle] end
    local l, vu, duJeu = {}, {}, false
    local function ajouter(m)
        if type(m) == "table" then l[#l + 1] = m; return end
        if type(m) ~= "string" then return end
        m = m:lower()
        if m ~= "" and not vu[m] then vu[m] = true; l[#l + 1] = m end
    end
    for _, m in ipairs(ty.mots or {}) do ajouter(m) end
    for _, m in ipairs(METIERS[ty.cle] or {}) do ajouter(m) end
    local jeu = ns.Jeu
    if (ty.recolte or ty.metier) and jeu and jeu.nomsMetier then
        for _, n in ipairs(jeu.nomsMetier(ty.cle)) do ajouter(n); duJeu = true end
    end
    if ty.ecole and jeu and jeu.nomsResistance then
        for _, n in ipairs(jeu.nomsResistance(ty.ecole)) do ajouter(n); duJeu = true end
    end
    if duJeu or not (ty.recolte or ty.metier or ty.ecole) then locaux[ty.cle] = l end
    return l
end

-- Conditions, dans l'ordre du choix « Quand ».
Tenues.CONDITIONS = {
    { cle = "monture", nom = L["En selle"] },
    { cle = "herbes", nom = L["Au survol d'une plante"] },
    { cle = "minage", nom = L["Au survol d'un filon"] },
    { cle = "depecage", nom = L["Au survol d'un corps à dépecer"] },
    { cle = "metier", nom = L["Fenêtre du métier ouverte"] },
    { cle = "nage", nom = L["Dans l'eau"] },
    { cle = "ville", nom = L["En ville (zone de repos)"] },
    { cle = "bg", nom = L["En champ de bataille"] },
    { cle = "donjon", nom = L["En donjon ou en raid"] },
    { cle = "cible", nom = L["Quand je cible…"], valeur = "cible" },
    { cle = "zone", nom = L["Dans une zone…"], valeur = "zone" },
    { cle = "joueur", nom = L["En ciblant un joueur ennemi"] },
    { cle = "manuel", nom = L["À la main"] },
}
function Tenues.nomCondition(cle)
    for _, c in ipairs(Tenues.CONDITIONS) do if c.cle == cle then return c.nom end end
    return cle
end

-- Condition avec sa valeur (« Quand je cible Ragnaros »).
function Tenues.texteCondition(t)
    if t.quand == "cible" then
        return t.cible and L["Quand je cible %s"]:format(t.cible) or L["Quand je cible… (à choisir)"]
    end
    if t.quand == "zone" then
        return t.zone and L["Dans %s"]:format(t.zone) or L["Dans une zone… (à choisir)"]
    end
    return Tenues.nomCondition(t.quand)
end

-- Emplacements, dans l'ordre de la fiche du personnage.
Tenues.GAUCHE = { 1, 2, 3, 15, 5, 4, 19, 9 }
Tenues.DROITE = { 10, 6, 7, 8, 11, 12, 13, 14 }
Tenues.BAS = { 16, 17, 18 }

---------------------------------------------------------------------------
-- Données
---------------------------------------------------------------------------

function Tenues.liste()
    SuperGuideCharDB = SuperGuideCharDB or {}
    SuperGuideCharDB.tenues = SuperGuideCharDB.tenues or {}
    return SuperGuideCharDB.tenues
end

local function etat()
    SuperGuideCharDB = SuperGuideCharDB or {}
    SuperGuideCharDB.tenuesEtat = SuperGuideCharDB.tenuesEtat or {}
    return SuperGuideCharDB.tenuesEtat
end

function Tenues.parId(id)
    for i, t in ipairs(Tenues.liste()) do if t.id == id then return t, i end end
end

local function nouvelId()
    local n = 0
    for _, t in ipairs(Tenues.liste()) do n = math.max(n, t.id or 0) end
    return n + 1
end

-- Mots cherchés pour une tenue : ceux de sa catégorie, plus le nom du
-- métier dans la langue du jeu.
function Tenues.mots(t)
    local ty = PAR_CLE[t.type]
    local l = {}
    for _, m in ipairs(Tenues.motsType(ty)) do l[#l + 1] = m end
    if t.metier then l[#l + 1] = t.metier:lower() end
    -- Objets reconnus par leur numéro (toutes langues).
    for _, x in ipairs(ty and ty.ids or {}) do l[#l + 1] = x end
    return l
end

function Tenues.nbPieces(t)
    local n = 0
    for _ in pairs(t.pieces or {}) do n = n + 1 end
    return n
end

---------------------------------------------------------------------------
-- Pièces proposées
---------------------------------------------------------------------------

local function contient(l, v) for _, x in ipairs(l) do if x == v then return true end end return false end

-- Bonus de chaque objet pour ces mots ; objets = Jeu.objetsPortables().
function Tenues.bonus(o, mots)
    if #mots == 0 then return nil end
    -- D'abord par le numéro de l'objet ou de son enchantement (toutes langues).
    local parId, textes = nil, {}
    local enchant = ns.Jeu.enchantDe and ns.Jeu.enchantDe(o.lien)
    for _, m in ipairs(mots) do
        if type(m) == "table" and (m.id or m.enchant) then
            if (m.id and m.id == o.id) or (m.enchant and m.enchant == enchant) then
                parId = math.max(parId or 0, m.valeur or 1)
            end
        else
            textes[#textes + 1] = m
        end
    end
    o.bonusCache = o.bonusCache or {}
    local cle = table.concat((function()
        local s = {}
        for _, m in ipairs(textes) do s[#s + 1] = type(m) == "table" and m[1] or m end
        return s
    end)(), "|")
    if o.bonusCache[cle] == nil then o.bonusCache[cle] = ns.Jeu.bonusDans(o.lignes or {}, textes) or false end
    local b = o.bonusCache[cle] or nil
    if parId and (not b or parId > b) then b = parId end
    return b
end

-- Objets possibles pour cet emplacement, les meilleurs d'abord : bonus de la
-- catégorie, puis niveau d'objet. { { objet, bonus } }.
function Tenues.candidats(t, case, objets)
    local mots = Tenues.mots(t)
    local l = {}
    for _, o in ipairs(objets) do
        if contient(o.cases, case) then
            l[#l + 1] = { objet = o, bonus = Tenues.bonus(o, mots) }
        end
    end
    table.sort(l, function(a, b)
        if (a.bonus or 0) ~= (b.bonus or 0) then return (a.bonus or 0) > (b.bonus or 0) end
        if (a.objet.niveau or 0) ~= (b.objet.niveau or 0) then return (a.objet.niveau or 0) > (b.objet.niveau or 0) end
        return (a.objet.id or 0) < (b.objet.id or 0)
    end)
    return l
end

-- Remplit les emplacements non épinglés avec les meilleurs objets à bonus.
-- Bagues, bijoux : deux objets différents. Arme à une main : main droite
-- seulement (la main gauche demande l'ambidextrie). Rend true si ça change.
function Tenues.remplir(t, objets)
    t.pieces = t.pieces or {}
    if #Tenues.mots(t) == 0 then return false end
    local change = false
    local pris = {}   -- objets déjà placés (même objet, une fois)
    for case, p in pairs(t.pieces) do
        if p.epingle then pris[p.id] = (pris[p.id] or 0) + 1 end
    end
    local function nombre(id)
        local n = 0
        for _, o in ipairs(objets) do if o.id == id then n = n + 1 end end
        return n
    end
    for case = 1, 19 do
        local p = t.pieces[case]
        if not (p and p.epingle) and not (t.vides and t.vides[case]) then
            local choix
            for _, c in ipairs(Tenues.candidats(t, case, objets)) do
                local o = c.objet
                local main = not (case == 17 and contient(o.cases, 16))
                if c.bonus and main and (pris[o.id] or 0) < nombre(o.id) then choix = o; break end
            end
            local avant = p and p.id
            if choix then
                pris[choix.id] = (pris[choix.id] or 0) + 1
                t.pieces[case] = { id = choix.id, lien = choix.lien }
            else
                t.pieces[case] = nil
            end
            if (choix and choix.id) ~= avant then change = true end
        end
    end
    return change
end

-- Pièce choisie à la main (épinglée) ou vidée (id nil : emplacement libre,
-- épinglé vide pour ne plus rien proposer).
function Tenues.choisir(t, case, o)
    t.pieces = t.pieces or {}
    if o then
        t.pieces[case] = { id = o.id, lien = o.lien, epingle = true }
        if t.vides then t.vides[case] = nil end
    else
        t.pieces[case] = nil
        t.vides = t.vides or {}
        t.vides[case] = true
    end
end

-- Emplacement rendu au choix automatique.
function Tenues.liberer(t, case)
    if t.pieces then t.pieces[case] = nil end
    if t.vides then t.vides[case] = nil end
end

-- Ce que tu portes, épinglé dans la tenue (tenues à remplir à la main).
function Tenues.prendrePorte(t)
    t.pieces = {}
    for case = 1, 19 do
        local id = ns.Jeu.idPiece(case)
        if id then t.pieces[case] = { id = id, lien = ns.Jeu.lienPiece(case), epingle = true } end
    end
end

-- Nouvelle tenue de cette catégorie (metier : nom du métier dans la langue
-- du jeu), remplie tout de suite. Ajoutée en tête de liste.
function Tenues.creer(typeCle, objets, metier)
    local ty = PAR_CLE[typeCle] or PAR_CLE.perso
    local t = { id = nouvelId(), type = ty.cle, nom = metier or ty.nom, quand = ty.quand, actif = true,
                metier = metier, pieces = {} }
    Tenues.remplir(t, objets or {})
    table.insert(Tenues.liste(), 1, t)
    return t
end

function Tenues.supprimer(id)
    local t, i = Tenues.parId(id)
    if not t then return end
    table.remove(Tenues.liste(), i)
    SuperGuideCharDB.tenuesVues = SuperGuideCharDB.tenuesVues or {}
    SuperGuideCharDB.tenuesVues[t.metier or t.type] = true
end

function Tenues.deplacer(id, sens)
    local l = Tenues.liste()
    local _, i = Tenues.parId(id)
    local j = i and i + sens
    if not (j and l[j]) then return end
    l[i], l[j] = l[j], l[i]
end

-- Une pièce de tenue n'est jamais jetée ni vendue.
function Tenues.protege(lien)
    local id = type(lien) == "string" and tonumber(lien:match("item:(%d+)"))
    if not id then return false end
    for _, t in ipairs(Tenues.liste()) do
        for _, p in pairs(t.pieces or {}) do if p.id == id then return true end end
    end
    return false
end

---------------------------------------------------------------------------
-- Propositions : rien ne change sans toi. Quand tes sacs changent, on
-- regarde ce qui pourrait servir : une tenue que tu n'as pas encore
-- (Carotte sans tenue Monture), ou une meilleure pièce pour une de tes
-- tenues. Chaque idée est proposée une fois ; « Non merci » est retenu.
---------------------------------------------------------------------------

function Tenues.connu(metiers, ty)
    for _, nom in ipairs(metiers) do
        local n = nom:lower()
        for _, m in ipairs(Tenues.motsType(ty)) do
            if type(m) == "string" and n == m then return nom end
        end
    end
end

local function refus()
    SuperGuideCharDB = SuperGuideCharDB or {}
    SuperGuideCharDB.tenuesRefus = SuperGuideCharDB.tenuesRefus or {}
    return SuperGuideCharDB.tenuesRefus
end

local function trouver(objets, id)
    for _, o in ipairs(objets) do if o.id == id then return o end end
end

-- { { cle, creer = type, metier, nom, objet, bonus, n } ou
--   { cle, tenue, case, objet, bonus, avant, bonusAvant } }, les nouvelles
-- tenues d'abord.
function Tenues.propositions(objets, metiers)
    local l, ref = {}, refus()
    for _, ty in ipairs(Tenues.TYPES) do
        if (ty.mots or ty.recolte or ty.metier) and not ty.sansProposer then
            local metier = (ty.recolte or ty.metier) and Tenues.connu(metiers, ty) or nil
            local cle = "creer:" .. ty.cle
            local deja = ref[cle]
            for _, t in ipairs(Tenues.liste()) do if t.type == ty.cle then deja = true end end
            if not deja and (metier or not (ty.recolte or ty.metier)) then
                local essai = { type = ty.cle, metier = metier, pieces = {} }
                Tenues.remplir(essai, objets)
                local meilleur, bonus
                for _, p in pairs(essai.pieces) do
                    local o = trouver(objets, p.id)
                    local b = o and Tenues.bonus(o, Tenues.mots(essai)) or 0
                    if o and (not bonus or b > bonus) then meilleur, bonus = o, b end
                end
                if meilleur then
                    l[#l + 1] = { cle = cle, creer = ty.cle, metier = metier, nom = metier or ty.nom,
                                  objet = meilleur, bonus = bonus, n = Tenues.nbPieces(essai) }
                end
            end
        end
    end
    for _, t in ipairs(Tenues.liste()) do
        local mots = Tenues.mots(t)
        if #mots > 0 then
            local essai = { type = t.type, metier = t.metier, pieces = {}, vides = t.vides }
            Tenues.remplir(essai, objets)
            for case = 1, 19 do
                local p = essai.pieces[case]
                local actuel = t.pieces and t.pieces[case]
                if p and not (actuel and actuel.id == p.id) then
                    local o = trouver(objets, p.id)
                    local b = o and Tenues.bonus(o, mots) or 0
                    local oa = actuel and trouver(objets, actuel.id)
                    local ba = oa and Tenues.bonus(oa, mots) or 0
                    local ailleurs = false
                    for c2, p2 in pairs(t.pieces or {}) do
                        if c2 ~= case and p2.id == p.id then ailleurs = true end
                    end
                    local cle = "piece:" .. t.id .. ":" .. case .. ":" .. p.id
                    if o and b > ba and not ailleurs and not ref[cle] then
                        l[#l + 1] = { cle = cle, tenue = t, case = case, objet = o, bonus = b,
                                      avant = actuel, bonusAvant = ba }
                    end
                end
            end
        end
    end
    return l
end

-- « Ajouter » / « Créer » : rend la tenue concernée.
function Tenues.accepter(p, objets)
    if p.creer then return Tenues.creer(p.creer, objets, p.metier) end
    Tenues.choisir(p.tenue, p.case, p.objet)
    return p.tenue
end

-- « Non merci » : plus jamais cette idée-là.
function Tenues.refuser(p) refus()[p.cle] = true end

---------------------------------------------------------------------------
-- Quand : la tenue voulue maintenant
---------------------------------------------------------------------------

-- ctx = { selle, nage, repos, instance, metier, recolte = { cle = temps },
--         maintenant, delai }
function Tenues.condition(t, ctx)
    local q = t.quand
    if t.force then return true end
    if q == "manuel" then return false end
    if q == "monture" then return ctx.selle == true end
    if q == "herbes" or q == "minage" or q == "depecage" then
        local v = ctx.recolte and ctx.recolte[q]
        return v ~= nil and ctx.maintenant - v <= (ctx.delai or 10)
    end
    if q == "metier" then
        if not ctx.metier then return false end
        local m = ctx.metier:lower()
        for _, mot in ipairs(Tenues.mots(t)) do
            if type(mot) == "string" and m == mot then return true end
        end
        return false
    end
    if q == "nage" then return ctx.nage == true end
    if q == "ville" then return ctx.repos == true end
    if q == "bg" then return ctx.instance == "pvp" or ctx.instance == "arena" end
    if q == "donjon" then return ctx.instance == "party" or ctx.instance == "raid" end
    if q == "cible" then
        return t.cible ~= nil and ctx.cible ~= nil and ctx.cible:lower() == t.cible:lower()
    end
    if q == "zone" then
        if not t.zone then return false end
        local z = t.zone:lower()
        return (ctx.zone ~= nil and ctx.zone:lower() == z) or (ctx.sousZone ~= nil and ctx.sousZone:lower() == z)
    end
    if q == "joueur" then return ctx.joueurEnnemi == true end
    return false
end

-- Première tenue active (dans l'ordre de la liste) dont la condition tient.
function Tenues.voulue(ctx)
    for _, t in ipairs(Tenues.liste()) do
        if t.force and Tenues.nbPieces(t) > 0 then return t end
    end
    for _, t in ipairs(Tenues.liste()) do
        if t.actif and Tenues.nbPieces(t) > 0 and Tenues.condition(t, ctx) then return t end
    end
end

---------------------------------------------------------------------------
-- Échange
---------------------------------------------------------------------------

local recolte = {}
function Tenues.noterRecolte(cle, quand) recolte[cle] = quand end

function Tenues.contexte()
    local jeu = ns.Jeu
    local zone, sousZone = jeu.zones()
    return { selle = jeu.enSelle(), nage = jeu.nage(), repos = jeu.repos(), instance = jeu.typeInstance(),
             cible = jeu.cibleNom(), joueurEnnemi = jeu.cibleJoueurEnnemi(), zone = zone, sousZone = sousZone,
             metier = jeu.metierOuvert(), recolte = recolte, maintenant = GetTime and GetTime() or 0,
             delai = R("tenuesDelai") or 10 }
end

function Tenues.enCours()
    local e = SuperGuideCharDB and SuperGuideCharDB.tenuesEtat
    return e ~= nil and e.active ~= nil
end

function Tenues.active()
    local e = SuperGuideCharDB and SuperGuideCharDB.tenuesEtat
    return e and e.active and Tenues.parId(e.active)
end

-- porte(case) vu comme si ton équipement d'avant était porté (Auto Equip ne
-- compare pas avec la carotte que tu as en selle).
function Tenues.porteNormal(porte)
    local base = SuperGuideCharDB and SuperGuideCharDB.tenuesEtat and SuperGuideCharDB.tenuesEtat.base or {}
    return function(case)
        local lien = base[case]
        if lien then return ns.Jeu.objetLien(lien) end
        if lien == false then return nil end
        return porte(case)
    end
end

-- Peut-on changer de pièces maintenant ?
function Tenues.bloque()
    local jeu = ns.Jeu
    if jeu.enCombat() or jeu.incante() then return true end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return true end
    local p = ns.Peche
    if p and p.enPeche and p.enPeche() then return true end
    return false
end

local function dire(texte)
    if R("tenuesMessage") ~= false then ns.Jeu.message(texte) end
end

-- Remise de ton équipement, vérifiée : une pièce n'est oubliée que quand
-- elle est vraiment revenue. Le jeu peut refuser un échange (objet encore
-- verrouillé par l'échange d'avant, sacs pleins) : on réessaie chaque
-- seconde, ESSAIS fois au plus, puis on le dit.
Tenues.ESSAIS = 6
local essais, prochain, remise = {}, 0, false

local function idDe(lien) return type(lien) == "string" and tonumber(lien:match("item:(%d+)")) or nil end

-- Reste-t-il une pièce à remettre (emplacement hors de la tenue voulue) ?
local function aRemettre(base, pieces)
    for case in pairs(base or {}) do
        if not pieces[case] then return true end
    end
    return false
end

-- À la connexion, le jeu remplit équipement et sacs quelques secondes après
-- le chargement : avant, un emplacement paraît vide et un objet introuvable.
-- Rien ne se décide avant (UI/Tenues.lua passe pret à true ensuite).
Tenues.pret = true

-- Ton équipement normal (sans tenue), emplacement par emplacement, pour les
-- emplacements que tes tenues touchent. Filet de sécurité si l'état de la
-- tenue est perdu (jeu fermé de force, plantage) : SuperGuideCharDB.tenuesNormal.
local function normal()
    SuperGuideCharDB = SuperGuideCharDB or {}
    SuperGuideCharDB.tenuesNormal = SuperGuideCharDB.tenuesNormal or {}
    return SuperGuideCharDB.tenuesNormal
end

function Tenues.noterNormal()
    local jeu, n = ns.Jeu, normal()
    for _, t in ipairs(Tenues.liste()) do
        for case in pairs(t.pieces or {}) do n[case] = jeu.lienPiece(case) or false end
    end
end

-- À la connexion, sans tenue en cours : une pièce de tenue restée sur toi
-- alors que ton équipement normal était autre chose est remise comme à la
-- fin d'une tenue (si la condition tient encore, la tenue reste, simplement).
-- Rend le nombre de pièces à remettre.
function Tenues.orphelins()
    local e = etat()
    if e.active or Tenues.demo then return 0 end
    local jeu, n, base, nb = ns.Jeu, normal(), e.base or {}, 0
    for _, t in ipairs(Tenues.liste()) do
        for case, p in pairs(t.pieces or {}) do
            local lien = n[case]
            local voulu = lien and idDe(lien)
            if base[case] == nil and lien ~= nil and jeu.idPiece(case) == p.id and voulu ~= p.id
               and (lien == false or jeu.possede(voulu)) then
                base[case] = lien
                nb = nb + 1
            end
        end
    end
    e.base = next(base) and base or nil
    return nb
end

-- Met la tenue voulue (ou remet ton équipement). force : réappliquer même
-- si c'est déjà la tenue mise (pièces changées dans la fenêtre).
function Tenues.evaluer(force)
    if Tenues.demo or not Tenues.pret then return false end   -- mode photo, ou connexion pas finie
    local voulue
    if R("tenuesActif") then voulue = Tenues.voulue(Tenues.contexte()) end
    local e = etat()
    local cible = voulue and voulue.id
    local pieces = voulue and voulue.pieces or {}
    local maintenant = GetTime and GetTime() or 0
    if cible == e.active and not force then
        -- Même tenue : seulement s'il reste une pièce à remettre, une fois par seconde.
        if not aRemettre(e.base, pieces) then
            -- Rien en cours, rien à remettre : ton équipement normal est noté.
            if not cible and not e.active and not e.base and not Tenues.bloque() then Tenues.noterNormal() end
            return false
        end
        if maintenant < prochain then return false end
    end
    if Tenues.bloque() then Tenues.enAttente = true; return false end
    Tenues.enAttente = false
    local jeu = ns.Jeu
    local base = e.base or {}
    local precedente = e.active and e.active ~= cible and Tenues.parId(e.active)
    -- 1. Emplacements que la nouvelle tenue ne touche pas : ce qu'ils avaient.
    local remis, rates = 0, {}
    for case, lien in pairs(base) do
        if not pieces[case] then
            local actuel, voulu = jeu.idPiece(case), idDe(lien)
            local piece = precedente and precedente.pieces and precedente.pieces[case]
            if actuel == voulu then
                base[case], essais[case] = nil, nil
                remis = remis + 1
            elseif piece and actuel ~= piece.id and not essais[case] then
                -- Tu as changé cette pièce toi-même pendant la tenue : on n'y touche pas.
                base[case] = nil
            elseif voulu and not jeu.possede(voulu) then
                base[case], essais[case] = nil, nil   -- vendu, jeté, en banque : plus rien à remettre
            elseif (essais[case] or 0) >= Tenues.ESSAIS then
                base[case], essais[case] = nil, nil
                rates[#rates + 1] = lien or case
            else
                essais[case] = (essais[case] or 0) + 1
                if voulu then jeu.mettre(lien, case) else jeu.retirer(case) end
            end
        end
    end
    prochain = maintenant + 1
    if #rates > 0 then
        local noms = {}
        for _, r in ipairs(rates) do noms[#noms + 1] = type(r) == "string" and r or L["un emplacement"] end
        ns.Jeu.message(L["Auto Sets : impossible de remettre %s (sacs pleins ?)."]:format(table.concat(noms, ", ")))
    end
    -- 2. Pièces de la tenue : ce qui était là avant est retenu une fois.
    local mises = 0
    for case, p in pairs(pieces) do
        if jeu.idPiece(case) ~= p.id and jeu.possede(p.id) then
            if base[case] == nil then base[case] = jeu.lienPiece(case) or false end
            -- Une arme à deux mains range la main gauche : retenue aussi.
            if case == 16 and base[17] == nil and not pieces[17] then base[17] = jeu.lienPiece(17) or false end
            if jeu.mettre(p.lien or p.id, case) then mises = mises + 1 end
        end
    end
    local avant = e.active
    e.active = cible
    e.base = next(base) and base or nil
    if not voulue and avant then remise = true end
    if voulue then remise = false end
    if voulue and cible ~= avant and mises > 0 then
        dire(L["Auto Sets : %s mise (%d pièces)."]:format(voulue.nom, mises))
    elseif remise and not aRemettre(e.base, pieces) then
        remise = false
        if remis > 0 then dire(L["Auto Sets : ton équipement est remis."]) end
    end
    return true
end

-- Mise d'un clic (bouton « Mettre », /sg tenue) : la tenue passe avant les
-- conditions jusqu'à ce qu'on la retire. Rend true si elle est mise.
function Tenues.basculer(id)
    local t = Tenues.parId(id)
    if not t then return false end
    local mise = t.force == true
    for _, x in ipairs(Tenues.liste()) do x.force = nil end
    if not mise then t.force = true end
    if Tenues.bloque() then
        ns.Jeu.message(L["Auto Sets : ça se fera dès que possible (pas en combat, en incantation ni en pêche)."])
    end
    Tenues.evaluer(true)
    return not mise
end
