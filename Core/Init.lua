-- Démarrage : chaque module est lancé, puis les événements du jeu lui sont branchés.

local ADDON, ns = ...

local L = ns.L or setmetatable({}, { __index = function(_, k) return k end })

local evenements = CreateFrame("Frame")

-- Démarre un module sans que son erreur éventuelle arrête les suivants :
-- elle part dans le gestionnaire d'erreurs du jeu (BugSack…).
local function lancer(f, ...)
    local ok, err = pcall(f, ...)
    if not ok then (geterrorhandler and geterrorhandler() or print)(err) end
end

-- Inscrit un événement s'il existe sur ce client (un nom inconnu lèverait
-- une erreur et couperait toutes les inscriptions suivantes).
local function inscrire(e)
    if C_EventUtils and C_EventUtils.IsEventValid and not C_EventUtils.IsEventValid(e) then return end
    pcall(evenements.RegisterEvent, evenements, e)
end

-- Propositions d'équipement : une vérification par image au plus.
local VERIFIER = {
    BAG_UPDATE_DELAYED = true, PLAYER_LEVEL_UP = true, PLAYER_REGEN_ENABLED = true,
    PLAYER_EQUIPMENT_CHANGED = true,
}
local verifEnAttente = false
local function demanderVerif()
    if verifEnAttente then return end
    verifEnAttente = true
    C_Timer.After(0, function()
        verifEnAttente = false
        ns.Equipement.verifier()
    end)
end
local CLES_EQUIPEMENT = { proposerEquipement = true, equipBoE = true, choisirRecompense = true }

-- Barre d'XP : un redessin par image au plus.
local BARRE_XP = {}
for _, e in ipairs(ns.BarreXP.EVENEMENTS) do BARRE_XP[e] = true end
local barreEnAttente = false
local function demanderBarre()
    if barreEnAttente then return end
    barreEnAttente = true
    C_Timer.After(0, function()
        barreEnAttente = false
        ns.BarreXP.maj()
    end)
end

-- Données de l'ancien module Guide (retiré) : effacées une fois pour toutes.
local ANCIENS_COMPTE = { "echelle", "opacite", "texte", "nbApercu", "apercu", "verrou", "muet",
    "flecheCachee", "flecheEchelle", "carteEtapes", "carteNbEtapes", "autoAccepter", "autoRendre",
    "sauterAbsentes", "autoDialogues", "styleSSF", "quetesGroupe", "guideActif", "volsAuto",
    "fenetre", "fleche" }
local ANCIENS_PERSO = { "guide", "termines", "recents", "etape", "coches", "passees", "sautes",
    "absentes", "parallele", "signaux", "swapAlts", "swapConnus" }

function ns.purgerAnciennes(compte, perso)
    for _, k in ipairs(ANCIENS_COMPTE) do compte[k] = nil end
    for _, k in ipairs(ANCIENS_PERSO) do perso[k] = nil end
end

-- Au lancement : addons à installer pour profiter de tous les modules.
-- Dit une fois ; redit seulement si un nouvel addon vient à manquer.
function ns.signalerDependances(db)
    local manque = ns.Reglages.dependancesManquantes()
    local deja = type(db.depsSignales) == "table" and db.depsSignales or {}
    local suivants, nouveau, morceaux = {}, false, {}
    for _, d in ipairs(manque) do
        suivants[d.addon] = true
        if not deja[d.addon] then nouveau = true end
        morceaux[#morceaux + 1] = L["%s (module %s)"]:format(d.addon, table.concat(d.modules, ", "))
    end
    db.depsSignales = suivants
    if not nouveau then return false end
    ns.Jeu.message(L["Pour profiter de tous les modules, installe aussi : %s. Disponibles sur CurseForge."]:format(table.concat(morceaux, ", ")))
    return true
end

-- Un module allumé sans l'addon dont il a besoin : on le dit tout de suite.
function ns.rappelerDependance(cle, v)
    if v ~= true then return end
    for _, m in ipairs(ns.Reglages.MODULES) do
        local a = m.interrupteur == cle and ns.Reglages.manquant(m)
        if a then
            ns.Jeu.message(L["%s a besoin de l'addon %s : installe-le et active-le, sinon ce module ne fait rien."]:format(m.titre, a))
        end
    end
end

local function demarrer()
    SuperGuideDB = SuperGuideDB or {}
    SuperGuideCharDB = SuperGuideCharDB or {}
    ns.purgerAnciennes(SuperGuideDB, SuperGuideCharDB)

    for _, e in ipairs(ns.Quetes.evenements) do inscrire(e) end
    inscrire("ITEM_DATA_LOAD_RESULT")
    inscrire("TAXIMAP_OPENED")

    if ns.Minimap then lancer(ns.Minimap.creer) end

    lancer(ns.Proposition.creer)
    lancer(ns.Proposition.brancherInfobulle)
    ns.Equipement.surProposition = ns.Proposition.montrer
    inscrire("PLAYER_REGEN_ENABLED")
    inscrire("PLAYER_EQUIPMENT_CHANGED")
    ns.Reglages.ecouter(function(cle) if CLES_EQUIPEMENT[cle] then demanderVerif() end end)
    demanderVerif()

    lancer(ns.BarreXP.creer)
    for _, e in ipairs(ns.BarreXP.EVENEMENTS) do inscrire(e) end
    ns.Reglages.ecouter(ns.BarreXP.appliquer)
    C_Timer.NewTicker(1, ns.BarreXP.tic)
    inscrire("PLAYER_REGEN_DISABLED")

    lancer(ns.Butin.creer)
    lancer(ns.ListeButin.creer)
    ns.Reglages.ecouter(ns.Butin.appliquer)

    lancer(ns.Rangs.creer)
    ns.Reglages.ecouter(ns.Rangs.appliquer)

    lancer(ns.Marqueurs.creer)
    ns.Reglages.ecouter(ns.Marqueurs.appliquer)

    lancer(ns.Tir.creer)
    ns.Reglages.ecouter(ns.Tir.appliquer)

    lancer(ns.SwapGroupe.creer)
    ns.Reglages.ecouter(ns.SwapGroupe.appliquer)
    for _, e in ipairs({ "CHAT_MSG_ADDON", "PARTY_INVITE_REQUEST", "GROUP_ROSTER_UPDATE", "GROUP_LEFT" }) do inscrire(e) end

    lancer(ns.PingSpy.creer)
    lancer(ns.VH.creer)
    lancer(ns.Tsquid.creer)
    ns.Reglages.ecouter(ns.VH.appliquer)
    for _, e in ipairs({ "PLAYER_PVP_KILLS_CHANGED", "PLAYER_GUILD_UPDATE", "INSPECT_READY", "INSPECT_HONOR_UPDATE",
                     "UPDATE_MOUSEOVER_UNIT", "PLAYER_TARGET_CHANGED", "NAME_PLATE_UNIT_ADDED" }) do inscrire(e) end
    ns.Reglages.ecouter(ns.PingSpy.appliquer)

    lancer(ns.Graphismes.synchroniser)
    ns.Reglages.ecouter(ns.Graphismes.appliquer)

    lancer(ns.Vols.creer)
    ns.Reglages.ecouter(ns.Vols.appliquer)

    for e in pairs(ns.Marchand.evenements) do inscrire(e) end

    lancer(ns.Usure.creer)
    for _, e in ipairs(ns.Usure.EVENEMENTS) do inscrire(e) end
    ns.Reglages.ecouter(ns.Usure.appliquer)

    ns.Reglages.ecouter(ns.rappelerDependance)
    lancer(function() ns.signalerDependances(SuperGuideDB) end)

    -- Section des raccourcis clavier (Échap > Raccourcis > SuperRsk).
    BINDING_HEADER_SUPERGUIDE = "SuperRsk"
end

local USURE = {}
for _, e in ipairs(ns.Usure.EVENEMENTS) do USURE[e] = true end

evenements:SetScript("OnEvent", function(_, e, ...)
    if VERIFIER[e] then demanderVerif() end
    if USURE[e] then ns.Usure.verifier() end
    if ns.Marchand.evenements[e] then ns.Marchand.evenements[e](...); return end
    if BARRE_XP[e] and ns.BarreXP.maj then
        ns.BarreXP.surEvenement(e, ...)
        demanderBarre()
    end
    -- Seulement nos chargements réussis : un échec redemandé à chaque
    -- vérification tournerait en boucle à chaque image.
    if e == "ITEM_DATA_LOAD_RESULT" then
        local id, ok = ...
        if ok and ns.Jeu.chargementAttendu(id) then demanderVerif() end
    end
    if e == "CHAT_MSG_ADDON" then
        ns.SwapGroupe.surMessage(...)
        ns.VH.surMessage(...)
        return
    elseif e == "PLAYER_PVP_KILLS_CHANGED" then
        ns.VH.surVictoire()
        return
    elseif e == "PLAYER_GUILD_UPDATE" then
        ns.VH.rafraichir()
        return
    elseif e == "INSPECT_READY" or e == "INSPECT_HONOR_UPDATE" then
        ns.VH.surInspection(e == "INSPECT_READY" and (...) or nil)
        return
    elseif e == "UPDATE_MOUSEOVER_UNIT" then
        ns.VH.croiser("mouseover")
        return
    elseif e == "PLAYER_TARGET_CHANGED" then
        ns.VH.croiser("target")
        return
    elseif e == "NAME_PLATE_UNIT_ADDED" then
        if type((...)) == "string" then ns.VH.croiser((...)) end
        return
    elseif e == "PARTY_INVITE_REQUEST" then
        ns.SwapGroupe.surInvitation((...))
        return
    elseif e == "GROUP_LEFT" then
        ns.SwapGroupe.surGroupeQuitte()
        return
    elseif e == "GROUP_ROSTER_UPDATE" then
        ns.SwapGroupe.noterGroupe()
        ns.SwapGroupe.reglerButin()
        if ns.SwapGroupe.rafraichir then ns.SwapGroupe.rafraichir() end
        return
    end
    if e == "PLAYER_LOGIN" then
        demarrer()
    elseif e == "TAXIMAP_OPENED" then
        ns.Vols.surCarteVol()
    elseif e == "PLAYER_REGEN_DISABLED" then
        -- Les cadres protégés ne bougent plus en combat : on quitte le mode Déplacement.
        if ns.Deplacement.ouvert() then ns.Deplacement.annuler() end
    elseif e == "PLAYER_REGEN_ENABLED" then
        ns.Graphismes.sortieCombat()
    else
        ns.Quetes.surEvenement(e, ...)
    end
end)
evenements:RegisterEvent("PLAYER_LOGIN")

---------------------------------------------------------------------------
-- /sg (ou /sg menu) : le menu · /sg move : mode Déplacement
-- /sg tir : armement mesuré du tir auto / de la baguette
-- /sg spe : arbre retenu par Auto Equip et d'où il vient (diagnostic)
-- /sg dr : effets néfastes de la cible lus par un addon (test d'un suivi des DR)
---------------------------------------------------------------------------

SLASH_SUPERGUIDE1 = "/sg"
SLASH_SUPERGUIDE2 = "/srsk"
SlashCmdList.SUPERGUIDE = function(arg)
    arg = (arg or ""):lower():match("^%s*(.-)%s*$")
    if arg == "" or arg == "menu" or arg == "options" or arg == "config" then
        ns.Menu.basculer()
    elseif arg == "spe" or arg == "spé" or arg == "spec" or arg == "arbre" then
        for _, ligne in ipairs(ns.Equipement.diagnostic()) do ns.Jeu.message(ligne) end
    elseif arg == "dr" then
        for _, ligne in ipairs(ns.Jeu.releveAuras("target")) do ns.Jeu.message(ligne) end
    elseif arg == "move" then
        ns.Deplacement.ouvrir()
    elseif arg == "tir" then
        if ns.Tir and ns.Tir.rapport then ns.Tir.rapport() end
    else
        ns.Jeu.message(L["Commande inconnue : %s (/sg, /sg move, tir, spe, dr)."]:format(arg))
        ns.Menu.basculer()
    end
end
