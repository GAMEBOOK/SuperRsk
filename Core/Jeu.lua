-- Façade des API du jeu.
--
-- Le code pur (filtre, parseur, commandes, moteur, quêtes) ne parle au jeu
-- QUE par ns.Jeu : les tests hors jeu le remplacent par un faux
-- (tests/faux_jeu.lua). Toute nouvelle API passe par ici.

local ADDON, ns = ...

local Jeu = {}
ns.Jeu = Jeu

---------------------------------------------------------------------------
-- Joueur
---------------------------------------------------------------------------

function Jeu.joueur()
    local _, classe = UnitClass("player")
    local _, race = UnitRace("player")
    local sexe = UnitSex("player") == 3 and "female" or "male"
    return {
        classe = classe, race = race, faction = UnitFactionGroup("player"),
        sexe = sexe, niveau = UnitLevel("player"), jeu = "FOREVER", locale = GetLocale(),
    }
end

function Jeu.niveau() return UnitLevel("player") end

-- Force, Agilité, Endurance, Intelligence, Esprit du joueur (équipement
-- compris) ; nil si le jeu les cache (valeurs secrètes) ou ne les donne pas.
local CLES_STATS = { "STR", "AGI", "STA", "INT", "SPI" }
function Jeu.statsBase()
    if not UnitStat then return nil end
    local t = {}
    for i, cle in ipairs(CLES_STATS) do
        local ok, _, v = pcall(UnitStat, "player", i)
        if not ok or (issecretvalue and issecretvalue(v)) or type(v) ~= "number" then return nil end
        t[cle] = v
    end
    return t
end
function Jeu.xp() return UnitXP("player") end
function Jeu.xpMax() return UnitXPMax("player") end

---------------------------------------------------------------------------
-- Quêtes
---------------------------------------------------------------------------

-- Quêtes rendues à l'instant : le serveur met quelques secondes à mettre
-- IsQuestFlaggedCompleted à jour après QUEST_TURNED_IN.
local rendues = {}
local DELAI_RENDUE = 5

-- Journal de quêtes chargé (premier QUEST_LOG_UPDATE) : avant, une quête
-- absente peut n'être qu'une quête pas encore lue.
local journalVu = false

function Jeu.estEnQuete(id)
    if C_QuestLog.IsOnQuest then return C_QuestLog.IsOnQuest(id) == true end
    return C_QuestLog.GetLogIndexForQuestID(id) ~= nil
end

function Jeu.estComplete(id)
    return C_QuestLog.IsComplete and C_QuestLog.IsComplete(id) == true or false
end

-- Quête à rendre : terminée, ou dans le journal sans aucun objectif
-- (quêtes « va parler à », que le jeu ne marque pas toujours complètes).
function Jeu.pretARendre(id)
    if Jeu.estComplete(id) then return true end
    if not Jeu.estEnQuete(id) then return false end
    local objs = C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(id)
    return not objs or #objs == 0
end

-- Titre d'une quête. S'il n'est pas encore connu du client, on demande son
-- chargement (au plus une fois par 10 s et par quête) ; QUEST_DATA_LOAD_RESULT
-- signale l'arrivée et Init rafraîchit la fenêtre.
local demandes = {}

-- Nom traduit d'une entité QuestieDB (dépendance facultative : absente ou
-- en erreur -> nil, et le guide garde le nom anglais).
local function champQuestie(genre, id, champ)
    local db = LibQuestieDB and LibQuestieDB[genre]
    if not (db and db.Get) then return nil end
    local ok, v = pcall(db.Get, id, champ)
    if ok then return v end
end

local function nomQuestie(genre, id)
    local nom = champQuestie(genre, id, "name")
    if type(nom) == "string" and nom ~= "" then return nom end
end

-- Infos d'un objet : C_Item.GetItemInfo sur les clients récents, où la
-- fonction globale a disparu.
local function infoObjet(x)
    local f = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if f then return f(x) end
end

---------------------------------------------------------------------------
-- Dialogues de PNJ (automatisation des quêtes)
-- GOSSIP_SHOW : C_GossipInfo par questID ; QUEST_GREETING : par index
-- (sous Forever, GetAvailableQuestInfo rend le questID en 5e valeur).
---------------------------------------------------------------------------

-- Réglage du jeu (CVar) en texte ; nil si ce client ne l'a pas.
function Jeu.cvar(nom)
    if C_CVar and C_CVar.GetCVar then return C_CVar.GetCVar(nom) end
    return GetCVar and GetCVar(nom)
end
function Jeu.ecrireCvar(nom, v)
    if C_CVar and C_CVar.SetCVar then C_CVar.SetCVar(nom, v) elseif SetCVar then SetCVar(nom, v) end
end

function Jeu.enCombat() return InCombatLockdown and InCombatLockdown() or false end

-- Addon installé et activé (chargé) ?
function Jeu.addonCharge(nom)
    local f = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    return f and f(nom) and true or false
end
function Jeu.ctrlEnfonce() return IsControlKeyDown and IsControlKeyDown() or false end

-- Repère sur la carte (x, y de 0 à 1) : TomTom s'il est là, sinon celui du jeu, suivi à l'écran.
function Jeu.repere(carte, x, y, titre)
    if TomTom and TomTom.AddWaypoint then
        TomTom:AddWaypoint(carte, x, y, { title = titre, from = "SuperRsk" })
    elseif C_Map and C_Map.SetUserWaypoint and UiMapPoint and
           (not C_Map.CanSetUserWaypointOnMap or C_Map.CanSetUserWaypointOnMap(carte)) then
        C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(carte, x, y))
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
    else
        return
    end
    Jeu.message(L["repère : %s (%d, %d)"]:format(titre, math.floor(x * 100 + 0.5), math.floor(y * 100 + 0.5)))
end

function Jeu.majEnfoncee() return IsShiftKeyDown and IsShiftKeyDown() or false end
function Jeu.plusTard(delai, f) C_Timer.After(delai, f) end
function Jeu.nbRecompenses() return GetNumQuestChoices and GetNumQuestChoices() or 0 end

---------------------------------------------------------------------------
-- Objets, sorts, déplacements
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Métiers (« .skill firstaid,50 ») : niveau actuel, 0 si pas appris
---------------------------------------------------------------------------

-- Clé du guide -> SkillLine (ids de Blizzard) et sort d'apprenti (son nom
-- localisé est celui du métier) ; noms écrits pour les cas où ils diffèrent.
local METIERS = {
    firstaid = { 129, 3273 }, cooking = { 185, 2550 }, fishing = { 356, 7620 },
    mining = { 186, 2575 }, herbalism = { 182 }, skinning = { 393, 8613 },
    tailoring = { 197, 3908 }, blacksmithing = { 164, 2018 }, leatherworking = { 165, 2108 },
    alchemy = { 171, 2259 }, engineering = { 202, 4036 }, enchanting = { 333, 7411 },
    lockpicking = { 633 },
}
local NOMS_METIERS = {
    herbalism = { "Herbalism", "Herboristerie" }, lockpicking = { "Lockpicking", "Crochetage" },
}

local function nomsMetier(cle, m)
    local noms = {}
    for _, n in ipairs(NOMS_METIERS[cle] or {}) do noms[n] = true end
    local sort = m[2] and ((C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(m[2]))
        or (GetSpellInfo and GetSpellInfo(m[2])))
    if sort then noms[sort] = true end
    return noms
end

function Jeu.surTaxi() return UnitOnTaxi("player") == true end

-- Valeur secrète (combat, instance) : ni comparable ni calculable par un add-on.
local function secret(v) return issecretvalue and issecretvalue(v) end

---------------------------------------------------------------------------
-- Expérience (barre d'XP)
---------------------------------------------------------------------------

function Jeu.xpRepos() return GetXPExhaustion and GetXPExhaustion() or 0 end

function Jeu.niveauMax()
    if GetMaxPlayerLevel then return GetMaxPlayerLevel() end
    return MAX_PLAYER_LEVEL or 60
end

-- XP promise par chaque quête du journal : { { xp, complete } }.
-- nil si le client ne donne pas l'XP des quêtes. Le journal ne liste pas
-- les quêtes sous un en-tête replié : on garde l'XP lue la dernière fois
-- tant que la quête est dans le journal.
local xpVue = {}
function Jeu.xpQuetes()
    if not GetQuestLogRewardXP then return nil end
    local liste, vues = {}, {}
    local function ajouter(id)
        if id and id > 0 and not vues[id] then
            vues[id] = true
            xpVue[id] = GetQuestLogRewardXP(id) or 0
            liste[#liste + 1] = { xp = xpVue[id], complete = Jeu.pretARendre(id) }
        end
    end
    if C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
        for i = 1, C_QuestLog.GetNumQuestLogEntries() do
            local info = C_QuestLog.GetInfo(i)
            if info and not info.isHeader then ajouter(info.questID) end
        end
    elseif GetNumQuestLogEntries and GetQuestLogTitle then
        for i = 1, GetNumQuestLogEntries() do
            local _, _, _, enTete, _, _, _, id = GetQuestLogTitle(i)
            if not enTete then ajouter(id) end
        end
    end
    for id, xp in pairs(xpVue) do
        if not vues[id] then
            if Jeu.estEnQuete(id) then
                liste[#liste + 1] = { xp = xp, complete = Jeu.pretARendre(id) }
            else
                xpVue[id] = nil
            end
        end
    end
    return liste
end

-- Temps joué demandé à la connexion sans afficher le message du jeu ; un
-- /played tapé par le joueur reste affiché.
local muet, enveloppe = false, false

function Jeu.demanderTempsJoue()
    if not enveloppe and ChatFrame_DisplayTimePlayed then
        enveloppe = true
        local origine = ChatFrame_DisplayTimePlayed
        ChatFrame_DisplayTimePlayed = function(...)
            if muet then return end
            return origine(...)
        end
    end
    muet = true
    RequestTimePlayed()
end

-- Sur TIME_PLAYED_MSG : on rend la parole au tour d'image suivant, une fois
-- que tous les cadres de chat ont vu l'événement.
function Jeu.tempsJoueRecu()
    C_Timer.After(0, function() muet = false end)
end

-- Barre d'XP du jeu masquée (ou remontrée). Rien en combat : renvoie false,
-- l'appelant réessaie à PLAYER_REGEN_ENABLED.
local BARRES_JEU = { "MainMenuExpBar", "ExhaustionTick", "MainStatusTrackingBarContainer" }
local barreCachee, accroches = false, {}

function Jeu.barreJeuCachee(oui)
    if InCombatLockdown() then return false end
    barreCachee = oui and true or false
    for _, nom in ipairs(BARRES_JEU) do
        local f = _G[nom]
        if f then
            if not accroches[nom] and f.HookScript then
                accroches[nom] = true
                f:HookScript("OnShow", function(self)
                    if barreCachee and not InCombatLockdown() then self:Hide() end
                end)
            end
            if barreCachee then f:Hide() else f:Show() end
        end
    end
    return true
end

---------------------------------------------------------------------------
-- Équipement (propositions d'amélioration, récompenses de quête)
---------------------------------------------------------------------------

-- Info-bulle cachée : le jeu y écrit en rouge tout ce qui empêche de porter
-- l'objet (compétence, armure, classe, niveau). On lit la couleur, pas le
-- texte : indépendant de la langue.
local scanneur
local chargements = {}   -- [itemID] = demandé par nous, résultat attendu
local function infoScan()
    if not scanneur then
        scanneur = CreateFrame("GameTooltip", "SuperGuideScan", nil, "GameTooltipTemplate")
    end
    scanneur:SetOwner(WorldFrame, "ANCHOR_NONE")
    scanneur:ClearLines()
    return scanneur
end

local function rouge(ligne)
    if not (ligne and ligne:IsShown()) then return false end
    local r, g, b = ligne:GetTextColor()
    return r and r > 0.95 and g < 0.2 and b < 0.2
end

-- « Niveau %d requis » : seule ligne rouge qui n'empêche pas de comparer
-- (Equipement regarde le niveau à part, pour les objets à garder).
local motifNiveau
local function ligneNiveau(ligne)
    if not motifNiveau then
        local f = type(ITEM_MIN_LEVEL) == "string" and ITEM_MIN_LEVEL or "Requires Level %d"
        motifNiveau = "^" .. f:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%d", "%%d+") .. "$"
    end
    local t = ligne:GetText()
    return type(t) == "string" and t:match(motifNiveau) ~= nil
end

local function portable(remplir)
    local t = infoScan()
    remplir(t)
    for i = 1, t:NumLines() or 0 do
        for _, cote in ipairs({ "Left", "Right" }) do
            local l = _G["SuperGuideScanText" .. cote .. i]
            if rouge(l) and not ligneNiveau(l) then return false end
        end
    end
    return true
end

-- Objet décrit pour Equipement ; nil s'il n'est pas encore en cache.
function Jeu.objet(lien, scan)
    if not lien then return nil end
    local _, _, qualite, _, niveauMin, _, _, _, equipLoc, _, prix, classeObjet, sousClasse, liaison = infoObjet(lien)
    if not qualite then
        local id = tonumber(lien:match("item:(%d+)"))
        if id and C_Item and C_Item.RequestLoadItemDataByID then
            chargements[id] = true
            C_Item.RequestLoadItemDataByID(id)
        end
        return nil
    end
    local lireStats = (C_Item and C_Item.GetItemStats) or GetItemStats
    return {
        lien = lien, qualite = qualite, niveauMin = niveauMin, equipLoc = equipLoc,
        prix = prix or 0, boe = liaison == 2, classeObjet = classeObjet, sousClasse = sousClasse,
        stats = ns.Equipement.convertirStats(lireStats and lireStats(lien) or {}),
        portable = portable(scan or function(t) t:SetHyperlink(lien) end),
    }
end

-- Vrai (une fois) si ce chargement d'objet était le nôtre.
function Jeu.chargementAttendu(id)
    local oui = chargements[id] == true
    chargements[id] = nil
    return oui
end

function Jeu.objetsSacs()
    local liste = {}
    for sac = 0, 4 do
        for case = 1, C_Container.GetContainerNumSlots(sac) or 0 do
            local o = Jeu.objet(C_Container.GetContainerItemLink(sac, case),
                function(t) t:SetBagItem(sac, case) end)
            if o then
                o.lie = C_Item.IsBound(ItemLocation:CreateFromBagAndSlot(sac, case)) == true
                liste[#liste + 1] = o
            end
        end
    end
    return liste
end

-- Marchand ------------------------------------------------------------------

-- Objets gris des sacs qui se vendent : { { sac, case, prix (total), nombre } }.
function Jeu.objetsGris()
    local liste = {}
    if not (C_Container and C_Container.GetContainerNumSlots) then return liste end
    for sac = 0, 4 do
        for case = 1, C_Container.GetContainerNumSlots(sac) or 0 do
            local info = C_Container.GetContainerItemInfo(sac, case)
            if info and info.quality == 0 and not info.hasNoValue then
                local prix = info.hyperlink and select(11, C_Item.GetItemInfo(info.hyperlink)) or 0
                if (prix or 0) > 0 then
                    local n = info.stackCount or 1
                    liste[#liste + 1] = { sac = sac, case = case, prix = prix * n, nombre = n }
                end
            end
        end
    end
    return liste
end

function Jeu.vendre(sac, case) C_Container.UseContainerItem(sac, case) end

-- Prix à l'hôtel des ventes (pièce unique, en cuivre) d'après le dernier scan
-- d'Auctionator s'il est installé ; nil sans scan.
function Jeu.prixHV(lien)
    local api = Auctionator and Auctionator.API and Auctionator.API.v1
    if not (api and api.GetAuctionPriceByItemLink and type(lien) == "string") then return nil end
    local ok, p = pcall(api.GetAuctionPriceByItemLink, "SuperRsk", lien)
    return ok and tonumber(p) or nil
end

-- Places libres dans les sacs normaux (ni carquois, ni sacs de métier).
function Jeu.placesLibres()
    if not (C_Container and C_Container.GetContainerNumFreeSlots) then return nil end
    local n = 0
    for sac = 0, 4 do
        local libres, famille = C_Container.GetContainerNumFreeSlots(sac)
        if (famille or 0) == 0 then n = n + (libres or 0) end
    end
    return n
end

-- Tous les objets gris des sacs, même sans valeur :
-- { sac, case, lien, icone, prix (marchand, total), hv (total ou nil), nombre }.
function Jeu.objetsMediocres()
    local liste = {}
    if not (C_Container and C_Container.GetContainerNumSlots) then return liste end
    for sac = 0, 4 do
        -- Sacs spéciaux (carquois, herbes, âmes…) : famille non nulle, pas de gris dedans.
        local _, famille = C_Container.GetContainerNumFreeSlots and C_Container.GetContainerNumFreeSlots(sac)
        local normal = (famille or 0) == 0
        for case = 1, normal and (C_Container.GetContainerNumSlots(sac) or 0) or 0 do
            local info = C_Container.GetContainerItemInfo(sac, case)
            if info and info.quality == 0 and info.hyperlink then
                local prix = info.hasNoValue and 0 or (select(11, C_Item.GetItemInfo(info.hyperlink)) or 0)
                local n = info.stackCount or 1
                local hv = Jeu.prixHV(info.hyperlink)
                liste[#liste + 1] = { sac = sac, case = case, lien = info.hyperlink, icone = info.iconFileID,
                                      prix = prix * n, hv = hv and hv * n or nil, nombre = n }
            end
        end
    end
    return liste
end

-- Sans gris : les objets blancs qu'on peut sacrifier, même format.
-- Jamais : consommables (nourriture, potions), sacs, réactifs, munitions,
-- carquois, objets de quête, clés, ni ce qui ne se vend pas (pierre de
-- foyer, objets spéciaux).
local GARDER = { [0] = true, [1] = true, [5] = true, [6] = true, [11] = true, [12] = true, [13] = true }
function Jeu.objetsCommuns()
    local liste = {}
    if not (C_Container and C_Container.GetContainerNumSlots) then return liste end
    for sac = 0, 4 do
        local _, famille = C_Container.GetContainerNumFreeSlots and C_Container.GetContainerNumFreeSlots(sac)
        local normal = (famille or 0) == 0
        for case = 1, normal and (C_Container.GetContainerNumSlots(sac) or 0) or 0 do
            local info = C_Container.GetContainerItemInfo(sac, case)
            if info and info.quality == 1 and info.hyperlink and not info.hasNoValue and not info.isLocked then
                local classe = select(6, C_Item.GetItemInfoInstant(info.hyperlink))
                local prix = select(11, C_Item.GetItemInfo(info.hyperlink)) or 0
                if classe and not GARDER[classe] and prix > 0 then
                    local n = info.stackCount or 1
                    local hv = Jeu.prixHV(info.hyperlink)
                    liste[#liste + 1] = { sac = sac, case = case, lien = info.hyperlink, icone = info.iconFileID,
                                          prix = prix * n, hv = hv and hv * n or nil, nombre = n, commun = true }
                end
            end
        end
    end
    return liste
end

function Jeu.lienSac(sac, case)
    return C_Container and C_Container.GetContainerItemLink and C_Container.GetContainerItemLink(sac, case)
end

-- Met l'objet de cette case dans la main du joueur, prêt à être jeté.
-- Sur ce serveur, détruire un objet est réservé au jeu lui-même (même sur
-- un clic) : le joueur clique dans le vide et le jeu demande « Détruire ? ».
-- Rend true si l'objet est dans la main.
function Jeu.jeter(sac, case)
    if CursorHasItem and CursorHasItem() then ClearCursor() end
    C_Container.PickupContainerItem(sac, case)
    return CursorHasItem and CursorHasItem() or false
end
function Jeu.marchandOuvert() return MerchantFrame and MerchantFrame:IsShown() or false end
function Jeu.peutReparer() return CanMerchantRepair and CanMerchantRepair() or false end
function Jeu.coutReparation()
    local cout = GetRepairAllCost and GetRepairAllCost()
    return tonumber(cout) or 0
end
function Jeu.peutReparerGuilde() return CanGuildBankRepair and CanGuildBankRepair() or false end
function Jeu.reparer(guilde) RepairAllItems(guilde and true or nil) end
function Jeu.argent() return GetMoney and GetMoney() or 0 end
function Jeu.majEnfonce() return IsShiftKeyDown and IsShiftKeyDown() or false end

-- 1 po 23 pa 45 pc, avec les pièces du jeu quand il sait les dessiner.
function Jeu.texteArgent(cuivre)
    if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then
        return C_CurrencyInfo.GetCoinTextureString(cuivre)
    end
    if GetCoinTextureString then return GetCoinTextureString(cuivre) end
    return ("%d po %d pa %d pc"):format(math.floor(cuivre / 10000), math.floor(cuivre / 100) % 100, cuivre % 100)
end

-- Pêche ---------------------------------------------------------------------

local function estCanne(id)
    if not (id and C_Item and C_Item.GetItemInfoInstant) then return false end
    local _, _, _, _, _, classe, sousClasse = C_Item.GetItemInfoInstant(id)
    return classe == 2 and sousClasse == 20
end

-- Nom lisible d'une touche (« Espace », « Maj-F ») dans la langue du jeu.
function Jeu.nomTouche(t)
    if GetBindingText and t then return GetBindingText(t) end
    return t
end

-- Une canne à pêche en main droite ?
function Jeu.cannePortee()
    return GetInventoryItemID ~= nil and estCanne(GetInventoryItemID("player", 16))
end

-- Compétence de pêche : rang, bonus (équipement et appât), maximum ; nil si illisible.
function Jeu.competencePeche(nom)
    for i = 1, (GetNumSkillLines and GetSkillLineInfo and nom) and GetNumSkillLines() or 0 do
        local ok, n, entete, _, rang, _, bonus, max = pcall(GetSkillLineInfo, i)
        if ok and not entete and n == nom and rang then return rang, bonus or 0, max end
    end
    if GetProfessions and GetProfessionInfo then
        local _, _, _, peche = GetProfessions()
        if peche then
            local ok, _, _, rang, max, _, _, _, bonus = pcall(GetProfessionInfo, peche)
            if ok and rang then return rang, bonus or 0, max end
        end
    end
end

-- Bonus de pêche lu dans l'info-bulle de scan déjà remplie (« +5 Pêche »,
-- « Pêche augmentée de 5 »…), nil sans bonus. Ligne 1 : le nom de l'objet
-- (« Canne à pêche… ») ; « Requiert Pêche (100) » n'est pas un bonus :
-- seulement « +N » ou « de N ».
local function bonusLu(t, motif)
    local bonus
    for i = 2, t:NumLines() or 0 do
        local l = _G["SuperGuideScanTextLeft" .. i]
        local txt = l and l:GetText()
        if type(txt) == "string" and txt:lower():find(motif, 1, true) then
            bonus = tonumber(txt:match("%+%s*(%d+)") or txt:match("%f[%a]de%s+(%d+)")
                or txt:match("%f[%a]by%s+(%d+)")) or bonus
        end
    end
    return bonus
end

-- Emplacement où va un objet, d'après son type (INVTYPE_…).
local EMPLACEMENTS = {
    INVTYPE_HEAD = 1, INVTYPE_NECK = 2, INVTYPE_SHOULDER = 3, INVTYPE_CHEST = 5, INVTYPE_ROBE = 5,
    INVTYPE_WAIST = 6, INVTYPE_LEGS = 7, INVTYPE_FEET = 8, INVTYPE_WRIST = 9, INVTYPE_HAND = 10,
    INVTYPE_FINGER = 11, INVTYPE_TRINKET = 13, INVTYPE_CLOAK = 15,
}

-- Pièces portées qui aident à pêcher : la canne, et celles qui donnent un
-- bonus de pêche. { { case, lien, icone, bonus } }.
function Jeu.equipementPeche(nom)
    local liste = {}
    if not (GetInventoryItemLink and nom) then return liste end
    local motif = nom:lower()
    for case = 1, 19 do
        local lien = GetInventoryItemLink("player", case)
        if lien then
            local t = infoScan()
            t:SetInventoryItem("player", case)
            local bonus = bonusLu(t, motif)
            if bonus or (case == 16 and estCanne(GetInventoryItemID("player", 16))) then
                liste[#liste + 1] = { case = case, lien = lien, icone = GetInventoryItemTexture("player", case), bonus = bonus }
            end
        end
    end
    return liste
end

-- Objets des sacs qui aident à pêcher et que tu peux porter : cannes et
-- pièces à bonus de pêche. { { lien, case (emplacement), canne, bonus, niveau } }.
function Jeu.sacsPeche(nom)
    local liste = {}
    if not (C_Container and C_Container.GetContainerNumSlots and nom) then return liste end
    local motif = nom:lower()
    for sac = 0, 4 do
        for c = 1, C_Container.GetContainerNumSlots(sac) or 0 do
            local lien = C_Container.GetContainerItemLink(sac, c)
            local id = lien and C_Item.GetItemInfoInstant(lien)
            if id then
                local _, _, _, loc = C_Item.GetItemInfoInstant(lien)
                local canne = estCanne(id)
                local emplacement = canne and 16 or EMPLACEMENTS[loc]
                if emplacement and portable(function(t) t:SetBagItem(sac, c) end) then
                    local bonus = bonusLu(scanneur, motif)
                    local _, _, _, niveau, niveauMin = C_Item.GetItemInfo(lien)
                    if (canne or bonus) and (niveauMin or 0) <= (UnitLevel("player") or 0) then
                        niveau = niveau or 0
                        liste[#liste + 1] = { lien = lien, case = emplacement, canne = canne, bonus = bonus, niveau = niveau }
                    end
                end
            end
        end
    end
    return liste
end

-- Équipe un objet par son lien à cet emplacement. Les armes passent même en
-- combat (le jeu le permet) ; le reste attend la fin du combat.
function Jeu.mettre(lien, case)
    local arme = case == 16 or case == 17 or case == 18
    if InCombatLockdown() and not arme then return false end
    local f = (C_Item and C_Item.EquipItemByName) or EquipItemByName
    if not (f and lien) then return false end
    -- Par son numéro : le lien complet contient le niveau du joueur, et ne
    -- correspond plus à l'objet après un niveau gagné (le jeu l'ignore alors).
    local id = type(lien) == "string" and tonumber(lien:match("item:(%d+)"))
    f(id or lien, case)
    return true
end

-- Appât posé sur la canne : secondes restantes, nil sans appât.
function Jeu.appatActif()
    if not GetWeaponEnchantInfo then return nil end
    local a, fin = GetWeaponEnchantInfo()
    if a and fin then return fin / 1000 end
end

-- Appâts des sacs parmi ces objets : { { id, nombre, nom, icone } }.
function Jeu.appatsSacs(ids)
    local liste = {}
    for _, id in ipairs(ids) do
        local n = C_Item and C_Item.GetItemCount and C_Item.GetItemCount(id) or 0
        if n > 0 then
            local nom, _, _, _, _, _, _, _, _, icone = C_Item.GetItemInfo(id)
            -- Compétence de pêche trop basse pour cet appât : pas utilisable.
            local utilisable = true
            local f = (C_Item and C_Item.IsUsableItem) or IsUsableItem
            if f then utilisable = f(id) and true or false end
            liste[#liste + 1] = { id = id, nombre = n, nom = nom or ("#" .. id), icone = icone, utilisable = utilisable }
        end
    end
    return liste
end

-- Prix d'un objet : hôtel des ventes (Auctionator) sinon marchand, à l'unité.
-- Rend prix, "hv" | "marchand" | nil.
function Jeu.prixObjet(lien)
    local hv = Jeu.prixHV(lien)
    if hv then return hv, "hv" end
    local vente = C_Item and C_Item.GetItemInfo and select(11, C_Item.GetItemInfo(lien))
    if vente and vente > 0 then return vente, "marchand" end
    return 0, nil
end

-- Ménage des objets de quête -----------------------------------------------

-- Objets de quête des sacs (classe « Quête », ou objet qui commence une
-- quête) : { { sac, case, lien, id, nom, icone, nombre, queteDebut } }.
function Jeu.objetsQuete()
    local liste = {}
    if not (C_Container and C_Container.GetContainerNumSlots) then return liste end
    for sac = 0, 4 do
        for c = 1, C_Container.GetContainerNumSlots(sac) or 0 do
            local info = C_Container.GetContainerItemInfo(sac, c)
            local lien = info and info.hyperlink
            if lien then
                local id, _, _, _, icone, classe = C_Item.GetItemInfoInstant(lien)
                local q = C_Container.GetContainerItemQuestInfo and C_Container.GetContainerItemQuestInfo(sac, c)
                local debut = q and q.questID
                if id and (classe == 12 or debut) then
                    liste[#liste + 1] = { sac = sac, case = c, lien = lien, id = id,
                        nom = lien:match("%[(.-)%]"), icone = info.iconFileID or icone,
                        nombre = info.stackCount or 1, queteDebut = debut }
                end
            end
        end
    end
    return liste
end

local function questieDB()
    local QL = _G.QuestieLoader
    if not (QL and QL.ImportModule) then return nil end
    local ok, db = pcall(QL.ImportModule, QL, "QuestieDB")
    if ok and db and type(db.QueryQuestSingle) == "function" and type(db.QueryItemSingle) == "function" then return db end
end

-- Objets dont une quête a besoin selon Questie : objectifs, objet donné au
-- départ (un détecteur prêté, par exemple), objets requis, objets qui la
-- commencent. ajouter(itemID) pour chacun.
local function objetsDeQuete(db, q, ajouter)
    local function champ(nom)
        local ok, v = pcall(db.QueryQuestSingle, q, nom)
        if ok then return v end
    end
    local obj = champ("objectives")
    if type(obj) == "table" and type(obj[3]) == "table" then
        for _, it in pairs(obj[3]) do ajouter(type(it) == "table" and it[1] or it) end
    end
    ajouter(champ("sourceItemId"))
    local requis = champ("requiredSourceItems")
    if type(requis) == "table" then for _, it in pairs(requis) do ajouter(it) end end
    local par = champ("startedBy")
    if type(par) == "table" and type(par[3]) == "table" then
        for _, it in pairs(par[3]) do ajouter(it) end
    end
end

-- Objets des quêtes de ton journal selon Questie : { [itemID] = questID }.
function Jeu.objetsQuetesEnCours(journal)
    local db, objets = questieDB(), {}
    if not db then return objets end
    for q in pairs(journal or {}) do
        objetsDeQuete(db, q, function(it) if type(it) == "number" then objets[it] = q end end)
    end
    return objets
end

-- Index objet -> quêtes sur toute la base de Questie, construit par petits
-- morceaux hors combat (pas d'à-coup) : { [itemID] = { questID, … } }.
local index, indexPret, indexEtat, indexObjets = {}, false, "pas lancé", 0
local function construireIndex()
    local db = questieDB()
    if not (db and type(db.QuestPointers) == "table") then
        indexEtat = "liste des quêtes de Questie introuvable"
        return
    end
    local ids = {}
    for q in pairs(db.QuestPointers) do ids[#ids + 1] = q end
    indexEtat = ("en cours (%d quêtes)"):format(#ids)
    local n = 1
    local ticker
    ticker = C_Timer.NewTicker(0.05, function()
        if InCombatLockdown() then return end
        for _ = 1, 150 do
            local q = ids[n]
            if not q then
                indexPret = true
                indexEtat = ("prêt (%d quêtes, %d objets)"):format(#ids, indexObjets)
                ticker:Cancel()
                return
            end
            objetsDeQuete(db, q, function(it)
                if type(it) == "number" then
                    if not index[it] then indexObjets = indexObjets + 1 end
                    local l = index[it] or {}
                    index[it] = l
                    l[#l + 1] = q
                end
            end)
            n = n + 1
        end
    end)
end
function Jeu.lancerIndexQuestie()
    if questieDB() then construireIndex() end
end
function Jeu.indexQuestiePret() return indexPret end
function Jeu.etatIndexQuestie() return questieDB() and indexEtat or "Questie absent" end

-- Quêtes liées à un objet selon Questie (index complet, plus ses champs
-- « quêtes liées » et « commence la quête ») ; nil sans Questie, sans
-- donnée, ou index pas encore prêt et rien d'autre.
function Jeu.quetesObjet(id)
    local db = questieDB()
    if not (db and id) then return nil end
    local quetes, vues = {}, {}
    local function ajouter(q)
        if type(q) == "number" and q > 0 and not vues[q] then vues[q] = true; quetes[#quetes + 1] = q end
    end
    for _, q in ipairs(index[id] or {}) do ajouter(q) end
    local okL, liees = pcall(db.QueryItemSingle, id, "relatedQuests")
    if okL and type(liees) == "table" then for _, q in pairs(liees) do ajouter(q) end end
    local okD, debut = pcall(db.QueryItemSingle, id, "startQuest")
    if okD then ajouter(debut) end
    return #quetes > 0 and quetes or nil
end

function Jeu.queteFaite(q)
    return C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(q) or false
end

function Jeu.queteEnCours(q)
    return C_QuestLog and C_QuestLog.IsOnQuest and C_QuestLog.IsOnQuest(q) or false
end

-- Tout le texte des quêtes du journal (titres, objectifs, descriptions) et
-- leurs identifiants { [questID] = true } : un objet qu'une quête en cours
-- nomme est gardé. Le texte est brut ; Menage le normalise.
function Jeu.texteQuetesEnCours()
    local morceaux, enCours = {}, {}
    local function ajouter(t) if type(t) == "string" and t ~= "" then morceaux[#morceaux + 1] = t end end
    local entrees = {}
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
        for i = 1, C_QuestLog.GetNumQuestLogEntries() or 0 do
            local info = C_QuestLog.GetInfo(i)
            if info and not info.isHeader then
                ajouter(info.title)
                entrees[#entrees + 1] = { i, info.questID }
            end
        end
    elseif GetNumQuestLogEntries and GetQuestLogTitle then
        for i = 1, GetNumQuestLogEntries() or 0 do
            local titre, _, _, enTete, _, _, _, id = GetQuestLogTitle(i)
            if not enTete then
                ajouter(titre)
                entrees[#entrees + 1] = { i, id }
            end
        end
    end
    local avant = GetQuestLogSelection and GetQuestLogSelection()
    for _, e in ipairs(entrees) do
        local index, id = e[1], e[2]
        if id then enCours[id] = true end
        -- Objectifs, interface moderne…
        local objectifs = id and C_QuestLog and C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(id)
        for _, o in ipairs(objectifs or {}) do ajouter(o.text) end
        -- … et classique (« Détecteur Gahz'ridian : 1/1 »).
        if GetNumQuestLeaderBoards and GetQuestLogLeaderBoard then
            local okN, n = pcall(GetNumQuestLeaderBoards, index)
            for k = 1, okN and n or 0 do
                local okT, texte = pcall(GetQuestLogLeaderBoard, k, index)
                if okT then ajouter(texte) end
            end
        end
        -- Description et résumé de l'objectif (sélection rendue après).
        if SelectQuestLogEntry and GetQuestLogQuestText then
            pcall(SelectQuestLogEntry, index)
            local ok, description, objectif = pcall(GetQuestLogQuestText)
            if ok then ajouter(description); ajouter(objectif) end
        end
    end
    if avant and SelectQuestLogEntry then pcall(SelectQuestLogEntry, avant) end
    return table.concat(morceaux, "\n"), enCours
end

-- Questie là et sa base lisible (pas seulement installé).
function Jeu.questieCharge() return questieDB() ~= nil end

-- Usure ---------------------------------------------------------------------

-- Pièces portées qui s'usent : { { case, actuel, max } }.
function Jeu.usure()
    local liste = {}
    if not GetInventoryItemDurability then return liste end
    for case = 1, 18 do
        local actuel, max = GetInventoryItemDurability(case)
        if actuel and max and max > 0 then liste[#liste + 1] = { case = case, actuel = actuel, max = max } end
    end
    return liste
end

-- Icône et lien de la pièce portée dans cette case.
function Jeu.iconePiece(case) return GetInventoryItemTexture and GetInventoryItemTexture("player", case) end
function Jeu.lienPiece(case) return GetInventoryItemLink and GetInventoryItemLink("player", case) end

-- Sons courts du jeu : « alerte » (avertissement de raid).
function Jeu.jouerSon(nom)
    if nom == "alerte" and PlaySound then
        PlaySound((SOUNDKIT and SOUNDKIT.RAID_WARNING) or 8959, "Master")
    end
end

-- nil = emplacement vide ; false = objet porté pas encore en cache.
function Jeu.objetPorte(id)
    local lien = GetInventoryItemLink("player", id)
    if not lien then return nil end
    local o = Jeu.objet(lien, function(t) t:SetInventoryItem("player", id) end)
    if not o then return false end
    o.lie = true
    return o
end

-- Objet décrit d'après son seul lien (pièce retenue pendant la pêche).
function Jeu.objetLien(lien)
    local o = Jeu.objet(lien, function(t) t:SetHyperlink(lien) end)
    if not o then return false end
    o.lie = true
    return o
end

function Jeu.recompenseQuete(i)
    local o = Jeu.objet(GetQuestItemLink("choice", i),
        function(t) t:SetQuestItem("choice", i) end)
    if o then o.lie = true end
    return o
end

-- Druide Retail : Équilibre, Farouche, Gardien, Restauration -> 3 arbres.
local SPE_DRUIDE = { [102] = 1, [103] = 2, [104] = 2, [105] = 3 }

-- Forever : la spécialisation n'est pas un arbre (son nom est celui de la
-- classe, identifiant 1486 relevé chez un paladin) mais un RÔLE, 5e retour de
-- GetSpecializationInfo. Rôle -> arbre quand il suffit à le dire ; sinon nil
-- (Armes ou Fureur, Équilibre ou Farouche… : arbre par défaut ou choix manuel).
-- Prêtre soigneur : Discipline et Sacré ont les mêmes poids, Sacré retenu.
Jeu.ARBRE_ROLE = {
    PALADIN = { HEALER = 1, TANK = 2, DAMAGER = 3 },
    WARRIOR = { TANK = 3 },
    DRUID   = { HEALER = 3, TANK = 2 },
    SHAMAN  = { HEALER = 3 },
    PRIEST  = { HEALER = 2, DAMAGER = 3 },
}

-- Rôle de la spécialisation choisie (« DAMAGER », « TANK », « HEALER ») et
-- son identifiant ; nil si aucune ou illisible.
function Jeu.roleSpecialisation()
    local S = C_SpecializationInfo
    local index = S and S.GetSpecialization and S.GetSpecialization()
    if type(index) ~= "number" or index < 1 or not S.GetSpecializationInfo then return nil end
    local id, _, _, _, role = S.GetSpecializationInfo(index)
    if issecretvalue and (issecretvalue(id) or issecretvalue(role)) then return nil end
    return type(role) == "string" and role or nil, id
end

-- Arbre d'après la spécialisation : identifiant de druide de Retail s'il
-- est reconnu, sinon le rôle. Jamais l'index (il ne désigne pas un onglet).
local function arbreSpecialisation()
    local role, id = Jeu.roleSpecialisation()
    local _, classe = UnitClass("player")
    if classe == "DRUID" and SPE_DRUIDE[id] then return SPE_DRUIDE[id] end
    local t = Jeu.ARBRE_ROLE[classe or ""]
    return t and role and t[role] or nil
end

-- Nœuds de talents (système récent, C_ClassTalents + C_Traits, présent sur
-- Forever) : { x, sort, rang, max } pour chacun. nil si illisible.
local function noeudsTalents()
    local CT, T = C_ClassTalents, C_Traits
    if not (CT and CT.GetActiveConfigID and T and T.GetConfigInfo and T.GetTreeNodes) then return nil end
    local ok, liste = pcall(function()
        local c = CT.GetActiveConfigID()
        local info = c and T.GetConfigInfo(c)
        if not (info and info.treeIDs) then return nil end
        local l = {}
        for _, arbre in ipairs(info.treeIDs) do
            for _, id in ipairs(T.GetTreeNodes(arbre) or {}) do
                local n = T.GetNodeInfo(c, id)
                if n then
                    local sort
                    if (n.currentRank or 0) > 0 and n.activeEntry then
                        local e = T.GetEntryInfo(c, n.activeEntry.entryID)
                        local d = e and e.definitionID and T.GetDefinitionInfo(e.definitionID)
                        sort = d and d.spellID
                    end
                    l[#l + 1] = { x = n.posX, sort = sort, rang = n.currentRank or 0, max = n.maxRanks }
                end
            end
        end
        return l
    end)
    return ok and liste or nil
end

-- Talents pris : [identifiant de sort] = { rang, max }. nil si illisible.
function Jeu.talents()
    local l = noeudsTalents()
    if not l then return nil end
    local t = {}
    for _, n in ipairs(l) do
        if n.sort and n.rang > 0 then t[n.sort] = { rang = n.rang, max = n.max or n.rang } end
    end
    return t
end

-- Forever pose les trois arbres côte à côte (colonnes espacées de 600) :
-- on groupe les positions horizontales, un écart de plus de 1000 sépare deux
-- arbres ; les groupes de moins de 3 nœuds (nœud isolé) sont ignorés. Rend
-- les points mis dans chaque arbre, de gauche à droite ; nil si pas 3 arbres.
function Jeu.pointsParArbre(noeuds)
    local xs = {}
    for _, n in ipairs(noeuds or {}) do if type(n.x) == "number" then xs[#xs + 1] = n.x end end
    table.sort(xs)
    local groupes, g = {}, nil
    for _, x in ipairs(xs) do
        if not g or x - g.max > 1000 then g = { min = x, max = x, n = 0 }; groupes[#groupes + 1] = g end
        g.max, g.n = x, g.n + 1
    end
    local arbres = {}
    for _, gr in ipairs(groupes) do if gr.n >= 3 then arbres[#arbres + 1] = gr end end
    if #arbres ~= 3 then return nil end
    local points = { 0, 0, 0 }
    for _, n in ipairs(noeuds) do
        if type(n.x) == "number" and n.rang > 0 then
            for i, gr in ipairs(arbres) do
                if n.x >= gr.min and n.x <= gr.max then points[i] = points[i] + n.rang end
            end
        end
    end
    return points
end

-- Arbre le plus rempli d'après les talents lus ; nil si aucun point ou égalité.
local function arbrePoints()
    local p = Jeu.pointsParArbre(noeudsTalents())
    if not p then return nil end
    local meilleur, max, egalite = nil, 0, false
    for i, v in ipairs(p) do
        if v > max then meilleur, max, egalite = i, v, false
        elseif v == max and v > 0 then egalite = true end
    end
    if egalite then return nil end
    return meilleur
end

-- Arbre qui a le plus de points ; nil si aucun point ou égalité. Sans
-- GetNumTalentTabs (Forever), la spécialisation choisie. Second retour :
-- d'où vient l'arbre (« points » ou « specialisation »), pour /sg spe.
function Jeu.arbreTalents()
    if not GetNumTalentTabs or not GetTalentTabInfo then
        local p = arbrePoints()
        if p then return p, "points" end
        local a = arbreSpecialisation()
        return a, a and "role" or nil
    end
    local meilleur, max, egalite = nil, 0, false
    for i = 1, GetNumTalentTabs() or 0 do
        local r = { GetTalentTabInfo(i) }
        local points = type(r[3]) == "number" and r[3] or r[5] or 0
        if points > max then meilleur, max, egalite = i, points, false
        elseif points == max and points > 0 then egalite = true end
    end
    if egalite then return nil end
    return meilleur, meilleur and "points" or nil
end

-- /sg dr : les effets néfastes de la cible tels que le jeu les donne aux
-- addons (identifiant de sort lisible ou secret), pour savoir si un suivi
-- des rendements décroissants (DR) est possible sur Forever.
function Jeu.releveAuras(unite)
    unite = unite or "target"
    local function txt(v)
        if issecretvalue and issecretvalue(v) then return "SECRET" end
        return tostring(v)
    end
    local l = {}
    local nom = UnitName and UnitName(unite)
    local ennemi = UnitIsEnemy and UnitIsEnemy("player", unite)
    l[1] = ("cible : %s · ennemi : %s"):format(txt(nom), txt(ennemi))
    local lire = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
    if not lire then
        l[2] = "C_UnitAuras.GetAuraDataByIndex absent"
        return l
    end
    local n = 0
    for i = 1, 40 do
        local ok, a = pcall(lire, unite, i, "HARMFUL")
        if not ok then l[#l + 1] = "erreur : " .. tostring(a); break end
        if not a then break end
        n = n + 1
        l[#l + 1] = ("%d. sort %s · %s · durée %s · lanceur %s"):format(i, txt(a.spellId), txt(a.name),
            txt(a.duration), txt(a.sourceUnit))
    end
    l[#l + 1] = ("effets néfastes : %d"):format(n)
    return l
end

-- /sg spe : ce que le jeu rend (spécialisation, onglets de talents bruts),
-- pour comprendre un arbre mal choisi sans /run.
function Jeu.releveTalents()
    local r = {}
    local S = C_SpecializationInfo
    if S and S.GetSpecialization then
        local ok, v = pcall(S.GetSpecialization)
        r.specialisation = ok and tostring(v) or "erreur"
    else
        r.specialisation = "absent"
    end
    local p = Jeu.pointsParArbre(noeudsTalents())
    r.arbres = p and table.concat(p, " / ") or "illisibles"
    r.onglets = {}
    if GetNumTalentTabs and GetTalentTabInfo then
        local ok, n = pcall(GetNumTalentTabs)
        r.nbOnglets = ok and tostring(n) or "erreur"
        for i = 1, (ok and tonumber(n) or 0) do
            local brut = { pcall(GetTalentTabInfo, i) }
            local champs = {}
            for k = 2, #brut do champs[#champs + 1] = tostring(brut[k]) end
            r.onglets[i] = table.concat(champs, " | ")
        end
    else
        r.nbOnglets = "absent"
    end
    return r
end

-- C_Item.EquipItemByName sur Forever, où la fonction globale a disparu.
function Jeu.equiper(objet, id)
    if InCombatLockdown() then return end
    local f = (C_Item and C_Item.EquipItemByName) or EquipItemByName
    if f then f(objet.lien, id) end
end

---------------------------------------------------------------------------
-- Divers
---------------------------------------------------------------------------

function Jeu.message(texte)
    print("|cff33ccffSuperRsk|r " .. texte)
end
