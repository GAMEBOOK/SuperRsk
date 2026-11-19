-- Propositions d'équipement : un objet meilleur que celui porté (selon la
-- classe et l'arbre de talents principal) est proposé au joueur, qui dit
-- Oui ou Non. Jamais un objet bleu ou violet « lié quand équipé » non lié.
--
-- Code pur : ne parle au jeu que par ns.Jeu (testé hors jeu). Les poids
-- sont les nôtres, orientés leveling ; c'est le seul endroit à retoucher.

local ADDON, ns = ...

local Equipement = {}
ns.Equipement = Equipement
local L = ns.L or setmetatable({}, { __index = function(_, k) return k end })

-- Clés de GetItemStats -> clés internes. Sur Forever, toucher, critique,
-- hâte, esquive et blocage sont des points de score : PAR_POURCENT en fait
-- des pourcents (10 points de toucher = 1 %), unité des poids ci-dessous.
-- Un même score de toucher ou de critique vaut pour les armes et les sorts.
local function s(...) return { ... } end
Equipement.STATS = {
    ITEM_MOD_STRENGTH_SHORT = s("STR"), ITEM_MOD_AGILITY_SHORT = s("AGI"), ITEM_MOD_STAMINA_SHORT = s("STA"),
    ITEM_MOD_INTELLECT_SHORT = s("INT"), ITEM_MOD_SPIRIT_SHORT = s("SPI"), RESISTANCE0_NAME = s("ARMOR"),
    ITEM_MOD_DAMAGE_PER_SECOND_SHORT = s("DPS"),
    ITEM_MOD_ATTACK_POWER_SHORT = s("AP"), ITEM_MOD_RANGED_ATTACK_POWER_SHORT = s("RAP"),
    ITEM_MOD_SPELL_POWER_SHORT = s("SP", "HEAL"), -- « dégâts et soins des sorts »
    ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = s("SP"), ITEM_MOD_SPELL_HEALING_DONE_SHORT = s("HEAL"),
    ITEM_MOD_MANA_REGENERATION_SHORT = s("MP5"), ITEM_MOD_POWER_REGEN0_SHORT = s("MP5"),
    ITEM_MOD_HIT_RATING_SHORT = s("HIT"), ITEM_MOD_HIT_SPELL_RATING_SHORT = s("HIT"),
    ITEM_MOD_HIT_MELEE_RATING_SHORT = s("HIT"), ITEM_MOD_HIT_RANGED_RATING_SHORT = s("HIT"),
    ITEM_MOD_CRIT_RATING_SHORT = s("CRIT"), ITEM_MOD_CRIT_SPELL_RATING_SHORT = s("CRIT"),
    ITEM_MOD_SPELL_CRIT_RATING_SHORT = s("CRIT"), ITEM_MOD_CRIT_MELEE_RATING_SHORT = s("CRIT"),
    ITEM_MOD_CRIT_RANGED_RATING_SHORT = s("CRIT"),
    ITEM_MOD_HASTE_RATING_SHORT = s("HASTE"), ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = s("DEF"),
    ITEM_MOD_DODGE_RATING_SHORT = s("DODGE"), ITEM_MOD_BLOCK_RATING_SHORT = s("BLOCK"),
}
-- Points de score pour 1 % (mêmes valeurs que NaowhForever_BiS, au niveau 60).
Equipement.PAR_POURCENT = { HIT = 10, CRIT = 14, HASTE = 10, DODGE = 12, BLOCK = 5 }

function Equipement.convertirStats(brut)
    local stats = {}
    for cle, v in pairs(brut or {}) do
        local cibles, n = Equipement.STATS[cle], tonumber(v)
        if cibles and n then
            for _, c in ipairs(cibles) do
                stats[c] = (stats[c] or 0) + n / (Equipement.PAR_POURCENT[c] or 1)
            end
        end
    end
    return stats
end

---------------------------------------------------------------------------
-- Poids de leveling, par classe et par arbre (ordre des onglets du jeu).
-- Unité : 1 point de stat, 1 de DPS d'arme, 1 % de toucher / critique /
-- hâte / esquive / blocage. Repères : 1 de DPS d'arme vaut 14 de puissance
-- d'attaque ; 1 de Force = 2 PA (guerrier, paladin, chaman, druide) ; 1
-- d'Agilité = 1 PA et du critique (voleur), 2 PA à distance et du critique
-- (chasseur). En leveling l'Endurance compte un peu plus qu'en raid.
-- DPS : arme de mêlée (main droite, moitié en main gauche) ; DPS_DIST :
-- arc, fusil, arbalète, armes de jet, baguette.
---------------------------------------------------------------------------

local GUERRIER = { STR = 1, AGI = .6, STA = .5, ARMOR = .02, DPS = 8, DPS_DIST = .5, AP = .5,
                   HIT = 12, CRIT = 11, HASTE = 7, DEF = .2, DODGE = 3, BLOCK = 1 }
local function chasseur(t)
    local w = { STR = .1, AGI = 1, STA = .5, INT = .3, SPI = .05, ARMOR = .02, DPS = .5, DPS_DIST = 6,
                AP = .38, RAP = .4, HIT = 12, CRIT = 12, HASTE = 8 }
    for k, v in pairs(t) do w[k] = v end
    return w
end
local VOLEUR = { STR = .55, AGI = 1, STA = .4, ARMOR = .02, DPS = 9, DPS_DIST = .5, AP = .55,
                 HIT = 14, CRIT = 12, HASTE = 9, DODGE = 3 }
local MAGE = { INT = 1, SPI = .6, STA = .4, ARMOR = .005, DPS_DIST = 2, SP = 1.2, MP5 = .8,
               HIT = 13, CRIT = 10, HASTE = 10 }
local DEMO = { INT = .8, SPI = .6, STA = .7, ARMOR = .005, DPS_DIST = 3, SP = 1.2, MP5 = .4,
               HIT = 13, CRIT = 8, HASTE = 8 }
local PRETRE_SOIN = { INT = 1, SPI = .8, STA = .5, ARMOR = .005, DPS_DIST = 3, SP = .8, HEAL = .4,
                      MP5 = 1.5, HIT = 6, CRIT = 4, HASTE = 5 }

Equipement.POIDS = {
    WARRIOR = { GUERRIER, GUERRIER,
                { STR = .8, AGI = .5, STA = 1, ARMOR = .05, DPS = 4, DPS_DIST = .3, AP = .4,
                  HIT = 8, CRIT = 4, HASTE = 4, DEF = 1.5, DODGE = 10, BLOCK = 4 } },
    PALADIN = { { STR = .3, INT = 1, SPI = .4, STA = .6, ARMOR = .01, DPS = 2, SP = .3, HEAL = .8,
                  MP5 = 1.5, CRIT = 4, HASTE = 4 },
                { STR = .8, AGI = .3, STA = 1, INT = .3, ARMOR = .05, DPS = 4, AP = .4, SP = .4,
                  HIT = 4, DEF = 1.2, DODGE = 8, BLOCK = 5 },
                { STR = 1, AGI = .5, STA = .5, INT = .3, ARMOR = .02, DPS = 8, AP = .5, SP = .2,
                  MP5 = .3, HIT = 12, CRIT = 10, HASTE = 6 } },
    HUNTER  = { chasseur({}), chasseur({ INT = .35, HIT = 13, CRIT = 12.5, DPS_DIST = 6.5 }),
                chasseur({ STR = .15, DPS = 1, CRIT = 11, HIT = 10.5 }) },
    ROGUE   = { VOLEUR, VOLEUR, VOLEUR },
    PRIEST  = { PRETRE_SOIN, PRETRE_SOIN,
                { INT = .8, SPI = 1, STA = .5, ARMOR = .005, DPS_DIST = 3, SP = 1, MP5 = .8,
                  HIT = 10, CRIT = 6, HASTE = 8 } },
    SHAMAN  = { { INT = 1, SPI = .4, STA = .5, ARMOR = .01, DPS = 1, SP = 1, MP5 = 1,
                  HIT = 12, CRIT = 10, HASTE = 9 },
                { STR = 1, AGI = .6, STA = .5, INT = .4, ARMOR = .02, DPS = 8, AP = .5, SP = .1,
                  MP5 = .3, HIT = 12, CRIT = 10, HASTE = 8 },
                { INT = 1, SPI = .5, STA = .5, ARMOR = .01, SP = .3, HEAL = .8, MP5 = 2,
                  CRIT = 4, HASTE = 5 } },
    MAGE    = { MAGE, MAGE, MAGE },
    WARLOCK = { DEMO, DEMO, DEMO },
    DRUID   = { { INT = 1, SPI = .6, STA = .5, ARMOR = .01, SP = 1, MP5 = .8, HIT = 12, CRIT = 9, HASTE = 8 },
                -- Farouche : formes animales, le DPS de l'arme ne compte pas.
                { STR = 1, AGI = .9, STA = .6, INT = .2, SPI = .1, ARMOR = .03, AP = .5,
                  HIT = 10, CRIT = 9, HASTE = 4, DEF = .5, DODGE = 4 },
                { INT = 1, SPI = .7, STA = .5, ARMOR = .01, SP = .3, HEAL = .8, MP5 = 2, CRIT = 3, HASTE = 5 } },
}

-- Arbre de leveling par défaut (avant le niveau 10, ou arbre indécis).
Equipement.ARBRE_DEFAUT = { WARRIOR = 1, PALADIN = 3, HUNTER = 2, ROGUE = 2, PRIEST = 3,
                            SHAMAN = 2, MAGE = 3, WARLOCK = 1, DRUID = 2 }

function Equipement.poids(classe, arbre, niveau)
    local arbres = Equipement.POIDS[classe]
    if not arbres then return Equipement.POIDS.WARRIOR[1] end
    if not arbre or not arbres[arbre] or (niveau or 0) < 10 then
        arbre = Equipement.ARBRE_DEFAUT[classe]
    end
    return arbres[arbre]
end

local DISTANCE = { INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true, INVTYPE_THROWN = true }
local PRIMAIRES = { STR = true, AGI = true, STA = true, INT = true, SPI = true }

-- Valeur d'un objet. emplacement : où il est (ou serait) porté, pour son DPS
-- (main gauche à moitié). sansPrimaires : les cinq stats de base, déjà
-- comptées par le jeu dans la puissance.
function Equipement.score(objet, poids, emplacement, sansPrimaires)
    local total = 0
    for cle, v in pairs(objet.stats or {}) do
        local w
        if cle == "DPS" then
            if DISTANCE[objet.equipLoc] or emplacement == 18 then w = poids.DPS_DIST
            elseif emplacement == 17 or objet.equipLoc == "INVTYPE_WEAPONOFFHAND" then w = (poids.DPS or 0) / 2
            else w = poids.DPS end
        elseif not (sansPrimaires and PRIMAIRES[cle]) then
            w = poids[cle]
        end
        total = total + v * (w or 0)
    end
    return total
end

local TOUS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }

-- Ce que vaut le personnage : ses cinq stats telles que le jeu les additionne
-- (base et équipement), plus le reste de l'équipement porté. Sans base
-- (illisible, en combat), tout l'équipement porté.
function Equipement.puissance(porte, poids, base)
    local total = 0
    for cle, v in pairs(base or {}) do total = total + v * (poids[cle] or 0) end
    for _, i in ipairs(TOUS) do
        local o = porte(i)
        if o then total = total + Equipement.score(o, poids, i, base ~= nil) end
    end
    return total
end

---------------------------------------------------------------------------
-- Emplacements (ids d'inventaire du jeu) et éligibilité.
---------------------------------------------------------------------------

Equipement.EMPLACEMENTS = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 },
    INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 },
    INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 },
    INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 },
    INVTYPE_WEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_2HWEAPON = { 16 },
    INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_SHIELD = { 17 }, INVTYPE_HOLDABLE = { 17 },
    INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 }, INVTYPE_RELIC = { 18 },
}

-- Gain minimal pour proposer un objet : 0,5 % de la puissance du personnage.
Equipement.SEUIL = 0.005

-- Type d'armure : seulement celui de la classe (un paladin en plaques ne
-- se voit pas proposer du tissu). Sous-classes du jeu : 1 tissu, 2 cuir,
-- 3 mailles, 4 plaques. Avant 40 : mailles (guerrier, paladin), cuir
-- (chasseur, chaman) ; à 40, le type au-dessus, l'ancien reste accepté.
-- Capes, bijoux, boucliers : pas concernés.
Equipement.ARMURE = 4
Equipement.PIECES_ARMURE = {
    INVTYPE_HEAD = true, INVTYPE_SHOULDER = true, INVTYPE_CHEST = true, INVTYPE_ROBE = true,
    INVTYPE_WAIST = true, INVTYPE_LEGS = true, INVTYPE_FEET = true, INVTYPE_WRIST = true, INVTYPE_HAND = true,
}
local TYPES_ARMURE = {
    WARRIOR = { 3, 4 }, PALADIN = { 3, 4 }, HUNTER = { 2, 3 }, SHAMAN = { 2, 3 },
    ROGUE = { 2 }, DRUID = { 2 }, PRIEST = { 1 }, MAGE = { 1 }, WARLOCK = { 1 },
}

function Equipement.armureOk(objet, classe, niveau)
    if objet.classeObjet ~= Equipement.ARMURE or not Equipement.PIECES_ARMURE[objet.equipLoc] then return true end
    local sc, types = objet.sousClasse, TYPES_ARMURE[classe or ""]
    if not (types and sc and sc >= 1 and sc <= 4) then return true end
    if sc == types[1] then return true end
    return types[2] ~= nil and sc == types[2] and (niveau or 0) >= 40
end

function Equipement.eligible(objet, ctx)
    if not Equipement.EMPLACEMENTS[objet.equipLoc] then return false end
    if not Equipement.armureOk(objet, ctx.classe, ctx.niveau) then return false end
    if (objet.niveauMin or 0) > ctx.niveau then return false end
    if objet.portable == false then return false end
    -- « Lié quand équipé » pas encore lié : jusqu'à la qualité choisie
    -- (0 aucun, 2 verts, 3 bleus, 7 tous).
    if objet.boe and not objet.lie then
        local max = ctx.boeMax or 2
        if max == 0 or (objet.qualite or 0) > max then return false end
    end
    return not (ctx.refuses and ctx.refuses[objet.lien])
end

---------------------------------------------------------------------------
-- Comparaisons : un objet face à ce qui est porté (porte(id) -> objet|nil).
---------------------------------------------------------------------------

local MAIN_GAUCHE = { INVTYPE_WEAPONOFFHAND = true, INVTYPE_SHIELD = true, INVTYPE_HOLDABLE = true }

local function scoreDe(o, poids, i) return o and Equipement.score(o, poids, i) or 0 end

-- Écart { objet, emplacement, remplace, gain, vide } face à ce qui est porté.
-- gain : ce que l'objet change à la puissance du personnage (0.05 = 5 % plus
-- fort), signé ; puissance absente : celle de l'équipement porté. vide :
-- l'emplacement est vide ou ne vaut rien pour toi. porte(id) rend false pour
-- un objet porté pas encore en cache : on ne compare pas (nil, "attendre").
function Equipement.ecart(objet, porte, poids, puissance)
    local ids = Equipement.EMPLACEMENTS[objet.equipLoc]
    if not ids then return nil end
    local aVoir = { ids[1], ids[2] }
    if objet.equipLoc == "INVTYPE_2HWEAPON" or MAIN_GAUCHE[objet.equipLoc] then aVoir = { 16, 17 } end
    for _, i in ipairs(aVoir) do
        if porte(i) == false then return nil, "attendre" end
    end
    local id, remplace, ancien
    if #ids == 2 then
        -- Bagues, bijoux : le premier emplacement vide, sinon le plus faible.
        for _, i in ipairs(ids) do
            local o = porte(i)
            local sc = scoreDe(o, poids, i)
            if not o then id, remplace, ancien = i, nil, 0; break end
            if not ancien or sc < ancien then id, remplace, ancien = i, o, sc end
        end
    else
        id = ids[1]
        remplace = porte(id)
        ancien = scoreDe(remplace, poids, id)
        if objet.equipLoc == "INVTYPE_2HWEAPON" then
            ancien = ancien + scoreDe(porte(17), poids, 17)
        elseif MAIN_GAUCHE[objet.equipLoc] then
            local droite = porte(16)
            if droite and droite.equipLoc == "INVTYPE_2HWEAPON" then return nil end
        end
    end
    local nouveau = Equipement.score(objet, poids, id)
    if ancien <= 0 and nouveau <= 0 then return nil end
    puissance = puissance or Equipement.puissance(porte, poids)
    if puissance <= 0 then puissance = math.max(nouveau, ancien) end
    return { objet = objet, emplacement = id, remplace = remplace,
             gain = (nouveau - ancien) / puissance, vide = ancien <= 0 }
end

-- Proposition : l'écart s'il atteint le seuil ; toujours pour remplir un
-- emplacement vide (ou qui ne te sert à rien).
function Equipement.comparer(objet, porte, poids, puissance)
    local prop, raison = Equipement.ecart(objet, porte, poids, puissance)
    if not prop or prop.gain <= 0 then return nil, raison end
    if prop.gain < Equipement.SEUIL and not prop.vide then return nil end
    return prop
end

-- Améliorations parmi les objets des sacs : la meilleure par emplacement,
-- triées par gain décroissant. Un objet sans stats (pas en cache) est sauté.
function Equipement.ameliorations(sacs, porte, poids, ctx)
    local parEmplacement = {}
    for _, o in ipairs(sacs) do
        if o.stats and Equipement.eligible(o, ctx) then
            local prop = Equipement.comparer(o, porte, poids, ctx.puissance)
            if prop then
                local avant = parEmplacement[prop.emplacement]
                if not avant or prop.gain > avant.gain then parEmplacement[prop.emplacement] = prop end
            end
        end
    end
    local liste = {}
    for _, prop in pairs(parEmplacement) do liste[#liste + 1] = prop end
    table.sort(liste, function(x, y)
        if x.gain ~= y.gain then return x.gain > y.gain end
        return x.emplacement < y.emplacement
    end)
    return liste
end

---------------------------------------------------------------------------
-- File de propositions : la tête est montrée par surProposition (crochet
-- posé par l'interface), seulement quand elle change.
---------------------------------------------------------------------------

function Equipement.surProposition(prop) end

local file, tete = {}, nil
local refuses = {}   -- « Non » (et échecs) : plus proposés de la session
local tentes = {}    -- « Oui » en cours : encore là au passage suivant = échec

local function cle(prop) return prop and (prop.objet.lien .. "#" .. prop.emplacement) end

local function montrer(prop)
    if cle(prop) == cle(tete) then return end
    tete = prop
    Equipement.surProposition(prop)
end

local function reglage(nom)
    return not (ns.Reglages and ns.Reglages.get(nom) == false)
end

-- Arbre retenu pour les poids et d'où il vient : arbre, source
-- (« points », « specialisation », « defaut »).
function Equipement.arbreRetenu(classe, arbre, source, niveau)
    local arbres = Equipement.POIDS[classe]
    if arbres and arbre and arbres[arbre] and (niveau or 0) >= 10 then return arbre, source end
    return Equipement.ARBRE_DEFAUT[classe], "defaut"
end

-- /sg spe : classe, arbre retenu, d'où il vient, poids principaux, relevé brut.
function Equipement.diagnostic()
    local jeu = ns.Jeu
    local classe, niveau = jeu.joueur().classe, jeu.niveau()
    local brut, source = Equipement.arbreJoueur()
    local arbre, d = Equipement.arbreRetenu(classe, brut, source, niveau)
    local p = Equipement.poids(classe, brut, niveau) or {}
    local role = jeu.roleSpecialisation and jeu.roleSpecialisation()
    local lignes = {
        ("Auto Equip : %s " .. L["niv."] .. " %s, " .. L["rôle"] .. " %s, " .. L["arbre"] .. " %s (%s)"):format(tostring(classe), tostring(niveau),
            tostring(role or "-"), tostring(arbre),
            (d == "points" and L["points de talents"]) or (d == "role" and L["rôle de la spécialisation"])
            or (d == "manuel" and L["choisi dans les réglages"])
            or L["par défaut : arbre indécis ou niveau < 10"]),
        ("  " .. L["poids"] .. " : FOR %s · AGI %s · INT %s · ESP %s · END %s"):format(
            tostring(p.STR or 0), tostring(p.AGI or 0), tostring(p.INT or 0), tostring(p.SPI or 0), tostring(p.STA or 0)),
    }
    local r = jeu.releveTalents and jeu.releveTalents() or {}
    lignes[#lignes + 1] = ("  " .. L["jeu"] .. " : specialisation %s · onglets %s"):format(tostring(r.specialisation), tostring(r.nbOnglets))
    for i, t in ipairs(r.onglets or {}) do lignes[#lignes + 1] = ("  onglet %d : %s"):format(i, t) end
    return lignes
end

-- Poids du personnage (classe, arbre principal, niveau).
function Equipement.poidsJoueur()
    local jeu = ns.Jeu
    return Equipement.poids(jeu.joueur().classe, (Equipement.arbreJoueur()), jeu.niveau())
end

-- Arbre du joueur et sa source : choix manuel (réglage equipArbre 1 à 3),
-- sinon ce que dit le jeu (points, rôle).
function Equipement.arbreJoueur()
    local manuel = ns.Reglages and tonumber(ns.Reglages.get("equipArbre"))
    if manuel and manuel >= 1 and manuel <= 3 then return manuel, "manuel" end
    return ns.Jeu.arbreTalents()
end

-- Puissance du personnage : ses cinq stats lues dans le jeu (les dernières
-- lues quand le jeu les cache, en combat), plus son équipement.
local derniereBase
function Equipement.puissanceJoueur(poids)
    local jeu = ns.Jeu
    local base = jeu.statsBase and jeu.statsBase()
    if base then derniereBase = base end
    return Equipement.puissance(jeu.objetPorte, poids, derniereBase)
end

-- Infobulle d'un objet : son écart avec ce qui est porté (Auto Equip actif,
-- objet portable par le joueur, pas déjà porté) ; nil sinon.
function Equipement._objet(lien) return ns.Jeu.objet(lien) end

function Equipement.infobulle(lien)
    if not lien or not reglage("proposerEquipement") then return nil end
    local objet = Equipement._objet(lien)
    if not (objet and objet.stats and objet.portable ~= false) then return nil end
    if not Equipement.armureOk(objet, ns.Jeu.joueur().classe, ns.Jeu.niveau()) then return nil end
    local ids = Equipement.EMPLACEMENTS[objet.equipLoc]
    if not ids then return nil end
    local porte = ns.Jeu.objetPorte
    for _, i in ipairs(ids) do
        local o = porte(i)
        if o and o.lien == lien then return nil end
    end
    local poids = Equipement.poidsJoueur()
    return (Equipement.ecart(objet, porte, poids, Equipement.puissanceJoueur(poids)))
end

function Equipement.contexte()
    local boeMax = ns.Reglages and tonumber(ns.Reglages.get("equipBoE")) or 2
    return { niveau = ns.Jeu.niveau(), boeMax = boeMax, refuses = refuses, classe = ns.Jeu.joueur().classe }
end

function Equipement.verifier()
    local jeu = ns.Jeu
    if not reglage("proposerEquipement") then
        file = {}
        montrer(nil)
        return
    end
    if jeu.enCombat() then
        montrer(nil)   -- la file reste : remontrée à la sortie du combat
        return
    end
    local poids, ctx = Equipement.poidsJoueur(), Equipement.contexte()
    ctx.puissance = Equipement.puissanceJoueur(poids)
    while true do
        file = Equipement.ameliorations(jeu.objetsSacs() or {}, jeu.objetPorte, poids, ctx)
        local t = file[1]
        if not (t and tentes[t.objet.lien]) then break end
        refuses[t.objet.lien] = true
        jeu.message(L["impossible d'équiper %s"]:format(t.objet.lien))
    end
    tentes = {}
    montrer(file[1])
end

-- Réponse du joueur à la proposition affichée.
function Equipement.repondre(oui)
    local t = file[1]
    if not t then return montrer(nil) end
    if oui then
        if ns.Jeu.enCombat() then return end
        tentes[t.objet.lien] = true
        ns.Jeu.equiper(t.objet, t.emplacement)
    else
        refuses[t.objet.lien] = true
    end
    table.remove(file, 1)
    montrer(file[1])
end

---------------------------------------------------------------------------
-- Récompense de quête (fenêtre de rendu ouverte, nb récompenses au choix).
---------------------------------------------------------------------------

-- Index choisi, "attendre" (une récompense pas encore en cache) ou nil
-- (rien de sûr : la fenêtre reste ouverte).
function Equipement.choisirRecompense(nb, choixDefaut)
    local jeu = ns.Jeu
    local recompenses = {}
    for i = 1, nb do
        recompenses[i] = jeu.recompenseQuete(i)
        if not recompenses[i] then return "attendre" end
    end
    local poids, ctx = Equipement.poidsJoueur(), Equipement.contexte()
    local puissance = Equipement.puissanceJoueur(poids)
    local meilleure, gain
    for i, o in ipairs(recompenses) do
        local prop, attente
        if o.stats and Equipement.eligible(o, ctx) then
            prop, attente = Equipement.comparer(o, jeu.objetPorte, poids, puissance)
        end
        if attente then return "attendre" end
        if prop and (not gain or prop.gain > gain) then meilleure, gain = i, prop.gain end
    end
    if meilleure then return meilleure end
    if type(choixDefaut) == "number" and choixDefaut >= 1 and choixDefaut <= nb then return choixDefaut end
    local chere, prix = nil, 0
    for i, o in ipairs(recompenses) do
        if (o.prix or 0) > prix then chere, prix = i, o.prix end
    end
    return chere
end
