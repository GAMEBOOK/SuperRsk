-- Pêche en un bouton : canne en main, une seule touche lance la ligne puis
-- ferre le poisson quand le bouchon plonge.
--
--   repos   la touche lance Pêche
--   ligne   la ligne est à l'eau : la touche devient « Interagir avec la
--           cible » du jeu, qui vise le bouchon (ciblage souple) et le prend
--
-- La touche n'est qu'empruntée (liaison prioritaire, rien n'est écrit dans
-- tes raccourcis) et seulement canne en main, hors combat. Les réglages du
-- jeu touchés (ciblage souple, portée) sont gardés et rendus au retour.
-- Le branchement de la touche lui-même est dans UI/Peche.lua (Peche.lier).

local ADDON, ns = ...

local Peche = {}
ns.Peche = Peche

local L = ns.L or setmetatable({}, { __index = function(_, k) return k end })
local function R(cle) return ns.Reglages.get(cle) end

Peche.SORT = 7620                 -- Pêche (rang 1) : lancé par son nom, donc au meilleur rang
Peche.ICONE = 136245              -- Interface\Icons\Trade_Fishing
Peche.PORTEE = "60"               -- le bouchon tombe souvent au-delà de la portée normale
Peche.DELAI = 0.3                 -- l'appui qui ferre ne doit pas relancer aussitôt

local etat = "repos"
local arme, annonce = false, nil

-- Branchement de la touche (UI/Peche.lua le remplace) : mode « lancer »,
-- « ferrer » ou nil (touche rendue).
function Peche.lier(touche, mode) end

function Peche.etat() return etat end
function Peche.arme() return arme end

-- Réglages du jeu gardés pendant la pêche (SuperGuideDB.pecheAvant), rendus
-- au retour, même après une déconnexion en pleine pêche.
local function garde()
    SuperGuideDB = SuperGuideDB or {}
    SuperGuideDB.pecheAvant = SuperGuideDB.pecheAvant or {}
    return SuperGuideDB.pecheAvant
end

local function poserCvar(nom, v)
    local jeu = ns.Jeu
    local actuel = jeu.cvar(nom)
    if actuel == nil then return end
    local g = garde()
    if g[nom] == nil then g[nom] = actuel end
    if actuel ~= v then jeu.ecrireCvar(nom, v) end
end

local function rendreCvar(nom)
    local g = garde()
    if g[nom] == nil then return end
    if ns.Jeu.cvar(nom) ~= nil then ns.Jeu.ecrireCvar(nom, g[nom]) end
    g[nom] = nil
end

function Peche.rendreTout()
    for nom in pairs(garde()) do rendreCvar(nom) end
end

local function touche()
    local t = R("pecheTouche")
    return type(t) == "string" and t ~= "" and t or "SPACE"
end

local function voulu()
    return R("pecheActif") == true and ns.Jeu.cannePortee() and not ns.Jeu.enCombat()
end

-- Sans canne en main, la touche de pêche met la tenue de pêche (puis lance
-- la ligne au prochain appui). Jamais Espace : sans canne, il sert à sauter.
function Peche.sortirPossible()
    return R("pecheActif") == true and R("pecheSortir") ~= false and touche() ~= "SPACE"
end

-- Prend la touche ou la rend, selon la canne, le combat et l'état de la ligne.
function Peche.maj()
    if ns.Jeu.enCombat() then return end
    if not voulu() then
        if arme then
            arme = false
            Peche.rendreTout()
            etat = "repos"
        end
        annonce = nil
        if Peche.sortirPossible() and not ns.Jeu.cannePortee() then
            Peche.lier(touche(), "sortir")
        else
            Peche.lier(nil, nil)
        end
        return
    end
    if not arme then
        arme = true
        poserCvar("SoftTargetInteract", "3")   -- le clavier aussi vise les objets
    end
    Peche.lier(touche(), etat == "ligne" and "ferrer" or "lancer")
    if annonce ~= touche() then
        annonce = touche()
        ns.Jeu.message(L["Pêche : canne en main, %s lance la ligne puis ferre le poisson."]:format(Peche.nomTouche(annonce)))
    end
end

function Peche.nomTouche(t)
    if ns.Jeu.nomTouche then return ns.Jeu.nomTouche(t) end
    return t
end

-- La ligne est à l'eau : la touche ferre, et la portée s'allonge.
function Peche.surLigne()
    if not arme then return end
    etat = "ligne"
    poserCvar("SoftTargetInteractRange", Peche.PORTEE)
    Peche.lier(touche(), "ferrer")
end

-- La ligne est sortie (poisson pris, raté ou annulé) : après un court délai,
-- la touche relance.
function Peche.surFinLigne()
    if etat ~= "ligne" then return end
    etat = "fin"
    ns.Jeu.plusTard(Peche.DELAI, function()
        if etat ~= "fin" then return end
        etat = "repos"
        rendreCvar("SoftTargetInteractRange")
        Peche.maj()
    end)
end

-- Le combat commence : la touche revient tout de suite à son rôle normal
-- (sauter, par exemple). Rien ne se rebranche avant la fin du combat.
function Peche.surCombat()
    if Peche.tenueMise() then Peche.rangerTenue(true) end
    if not arme then return end
    arme = false
    etat = "repos"
    Peche.lier(nil, nil)
end

function Peche.surDeconnexion()
    arme = false
    Peche.lier(nil, nil)
    Peche.rendreTout()
end

-- Au lancement : une pêche coupée net (déconnexion, plantage) a pu laisser
-- les réglages du jeu modifiés.
function Peche.demarrer()
    -- Une fois par compte : comment s'en servir (sans touche choisie, rien
    -- ne se passe sans canne en main).
    SuperGuideDB = SuperGuideDB or {}
    if R("pecheActif") == true and not SuperGuideDB.pecheAvis then
        SuperGuideDB.pecheAvis = true
        ns.Jeu.message(L["Nouveau, Pêche en un bouton : canne en main, Espace lance la ligne et ferre le poisson. Choisis ta propre touche dans /sg > Pêche en un bouton : elle sortira aussi ta canne des sacs."])
    end
    Peche.rendreTout()
    Peche.maj()
end

---------------------------------------------------------------------------
-- Session de pêche (SuperGuideCharDB.pecheSession, gardée au /reload) :
-- temps canne en main, nombre de prises, et chaque objet pêché.
---------------------------------------------------------------------------

-- Appâts connus (à poser sur la canne), le meilleur d'abord : Attracteur
-- aquadynamique (+100), Babioles brillantes et Ver dévoreur (+75),
-- Asticots et Lentille aquadynamique (+50), Babiole brillante (+25).
Peche.APPATS = { 6533, 6532, 7307, 6530, 6811, 6529 }

-- L'appât que la touche pose avant de lancer : le meilleur des sacs que tu
-- peux utiliser, seulement s'il n'y en a plus sur la canne.
function Peche.appatAPoser(appats, actif)
    if R("pecheAppat") == false or actif then return nil end
    for _, a in ipairs(appats) do
        if a.utilisable ~= false then return a end
    end
end

function Peche.session()
    SuperGuideCharDB = SuperGuideCharDB or {}
    local s = SuperGuideCharDB.pecheSession
    if type(s) ~= "table" then
        s = { temps = 0, prises = 0, objets = {} }
        SuperGuideCharDB.pecheSession = s
    end
    return s
end

function Peche.remettreAZero()
    SuperGuideCharDB = SuperGuideCharDB or {}
    SuperGuideCharDB.pecheSession = nil
end

-- Le temps ne compte que canne en main.
-- Une session s'arrête après 30 minutes sans canne en main : la suivante
-- repart de zéro (même après une déconnexion). maintenant : time().
Peche.PAUSE = 1800
function Peche.compterTemps(dt, maintenant)
    if not arme then return end
    local s = Peche.session()
    if maintenant and s.derniere and maintenant - s.derniere > Peche.PAUSE then
        Peche.remettreAZero()
        s = Peche.session()
    end
    s.derniere = maintenant or s.derniere
    s.temps = s.temps + dt
end

-- Un butin de pêche : une prise, et ses objets { { id, lien, icone, nombre } }.
-- memePrise : d'autres objets de la prise déjà comptée.
function Peche.noterPrise(objets, memePrise)
    local s = Peche.session()
    if not memePrise then s.prises = s.prises + 1 end
    for _, o in ipairs(objets) do
        local cle = o.id or o.lien
        if cle then
            local e = s.objets[cle]
            if not e then
                e = { lien = o.lien, icone = o.icone, nombre = 0 }
                s.objets[cle] = e
            end
            e.nombre = e.nombre + (o.nombre or 1)
            e.lien, e.icone = o.lien or e.lien, o.icone or e.icone
        end
    end
end

-- Objets pêchés, le plus précieux d'abord, et la valeur totale.
-- prix(lien) rend le prix unitaire et sa source ("hv", "marchand" ou nil).
function Peche.bilan(prix)
    local liste, total = {}, 0
    for _, e in pairs(Peche.session().objets) do
        local p, source = 0, nil
        if e.lien then p, source = prix(e.lien) end
        local v = (p or 0) * e.nombre
        total = total + v
        liste[#liste + 1] = { lien = e.lien, icone = e.icone, nombre = e.nombre, valeur = v, source = source }
    end
    table.sort(liste, function(a, b)
        if a.valeur ~= b.valeur then return a.valeur > b.valeur end
        return a.nombre > b.nombre
    end)
    return liste, total
end

-- Valeur par heure de pêche, nil avant 5 minutes (trop tôt pour dire).
function Peche.parHeure(total, temps)
    if not (temps and temps >= 300) then return nil end
    return math.floor(total * 3600 / temps)
end

---------------------------------------------------------------------------
-- Tenue de pêche : une touche sort des sacs la meilleure canne et les pièces
-- à bonus de pêche, et retient ce que tu portais ; un second appui le remet.
-- Attaqué : les armes reviennent tout de suite (le jeu le permet en combat),
-- le reste à la fin du combat.
-- SuperGuideCharDB.pecheTenue = { [emplacement] = lien porté avant, ou false
-- s'il était vide (la pièce de pêche reste alors en place).
---------------------------------------------------------------------------

-- Nom du sort Pêche dans la langue du jeu (UI/Peche.lua le remplace).
function Peche.nomPeche() return "Fishing" end

local function mieux(a, b)
    if not b then return true end
    if (a.bonus or 0) ~= (b.bonus or 0) then return (a.bonus or 0) > (b.bonus or 0) end
    return (a.niveau or 0) > (b.niveau or 0)
end

-- Ce qu'il faut mettre : { [emplacement] = lien }. sacs : Jeu.sacsPeche ;
-- portes : Jeu.equipementPeche ; canne : une canne est déjà en main.
function Peche.choisirTenue(sacs, portes, canne)
    local meilleurs = {}
    for _, o in ipairs(sacs) do
        if mieux(o, meilleurs[o.case]) then meilleurs[o.case] = o end
    end
    local porte = {}
    for _, p in ipairs(portes) do porte[p.case] = p.bonus or 0 end
    local choix = {}
    for case, o in pairs(meilleurs) do
        if (case == 16 and not canne) or (o.bonus or 0) > (porte[case] or 0) then choix[case] = o.lien end
    end
    return choix
end

function Peche.tenueMise()
    return type(SuperGuideCharDB) == "table" and type(SuperGuideCharDB.pecheTenue) == "table"
end

local function trier(t)
    local l = {}
    for k in pairs(t) do l[#l + 1] = k end
    table.sort(l)
    return l
end

function Peche.mettreTenue()
    local jeu = ns.Jeu
    if jeu.enCombat() then jeu.message(L["Pêche : pas pendant un combat."]); return end
    local nom = Peche.nomPeche()
    local canne = jeu.cannePortee()
    local choix = Peche.choisirTenue(jeu.sacsPeche(nom), jeu.equipementPeche(nom), canne)
    if next(choix) == nil then
        jeu.message(canne and L["Pêche : tu portes déjà ta meilleure tenue de pêche."]
            or L["Pêche : aucune canne à pêche que tu peux porter dans tes sacs."])
        return
    end
    local avant, n = {}, 0
    for _, case in ipairs(trier(choix)) do
        avant[case] = jeu.lienPiece(case) or false
        -- La canne se tient à deux mains : l'arme de main gauche part aussi.
        if case == 16 then avant[17] = jeu.lienPiece(17) or false end
        if jeu.mettre(choix[case], case) then n = n + 1 end
    end
    SuperGuideCharDB = SuperGuideCharDB or {}
    SuperGuideCharDB.pecheTenue = avant
    jeu.message(L["Pêche : tenue de pêche mise (%d pièces). Rappuie pour remettre ton équipement."]:format(n))
end

-- Remet ce que tu portais. seulementArmes : en combat, les armes seulement,
-- le reste est gardé pour la fin du combat.
function Peche.rangerTenue(seulementArmes)
    if not Peche.tenueMise() then return end
    local avant, reste = SuperGuideCharDB.pecheTenue, {}
    for _, case in ipairs(trier(avant)) do
        local lien = avant[case]
        if lien then
            if (seulementArmes and case < 16) or not ns.Jeu.mettre(lien, case) then reste[case] = lien end
        end
    end
    if next(reste) then
        SuperGuideCharDB.pecheTenue = reste
    else
        SuperGuideCharDB.pecheTenue = nil
        ns.Jeu.message(L["Pêche : ton équipement est remis."])
    end
end

-- En pêche : canne en main, ou tenue de pêche pas encore remise.
function Peche.enPeche()
    return ns.Jeu.cannePortee() or Peche.tenueMise()
end

-- Équipement « normal » (sans canne), relevé à chaque changement : même une
-- canne mise à la main se range ensuite d'un appui (touche de tenue, clic
-- sur le widget), avec tout ce qui a été changé depuis.
local normal
function Peche.surEquipement()
    local jeu = ns.Jeu
    if not jeu.cannePortee() then
        if Peche.tenueMise() then
            -- Remis à la main : ce qui est déjà en place n'est plus à remettre.
            local avant = SuperGuideCharDB.pecheTenue
            for c, lien in pairs(avant) do
                if not lien or jeu.lienPiece(c) == lien then avant[c] = nil end
            end
            if next(avant) then return end
            SuperGuideCharDB.pecheTenue = nil
        end
        normal = {}
        for c = 1, 19 do normal[c] = jeu.lienPiece(c) or false end
        return
    end
    if not normal then return end
    local avant = Peche.tenueMise() and SuperGuideCharDB.pecheTenue or {}
    for c = 1, 19 do
        if avant[c] == nil and normal[c] and (jeu.lienPiece(c) or false) ~= normal[c] then avant[c] = normal[c] end
    end
    if next(avant) then
        SuperGuideCharDB = SuperGuideCharDB or {}
        SuperGuideCharDB.pecheTenue = avant
    end
end

-- porte(case) vu comme si l'équipement de combat retenu était porté :
-- pièce retenue, emplacement vide avant (nil), ou inconnu (false : arme
-- remplacée par la canne sans rien de retenu, Auto Equip attend).
function Peche.porteNormal(porte)
    local avant = Peche.tenueMise() and SuperGuideCharDB.pecheTenue or {}
    return function(case)
        local lien = avant[case]
        if lien then return ns.Jeu.objetLien(lien) end
        if lien == false then return nil end
        if case == 16 and ns.Jeu.cannePortee() then return false end
        return porte(case)
    end
end

function Peche.basculerTenue()
    if Peche.tenueMise() then Peche.rangerTenue() else Peche.mettreTenue() end
end

local CLES = { pecheActif = true, pecheTouche = true, pecheSortir = true }
function Peche.appliquer(cle)
    if not CLES[cle] then return end
    if cle == "pecheTouche" and arme then Peche.lier(nil, nil) end
    annonce = nil
    Peche.maj()
end
