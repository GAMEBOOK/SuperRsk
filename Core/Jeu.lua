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

local function portable(remplir)
    local t = infoScan()
    remplir(t)
    for i = 1, t:NumLines() or 0 do
        if rouge(_G["SuperGuideScanTextLeft" .. i]) or rouge(_G["SuperGuideScanTextRight" .. i]) then
            return false
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

function Jeu.lienSac(sac, case)
    return C_Container and C_Container.GetContainerItemLink and C_Container.GetContainerItemLink(sac, case)
end

-- Détruit l'objet de cette case (prend l'objet, le jette). Rend true si fait.
function Jeu.jeter(sac, case)
    if CursorHasItem and CursorHasItem() then return false end
    C_Container.PickupContainerItem(sac, case)
    if CursorHasItem and CursorHasItem() then
        DeleteCursorItem()
        return true
    end
    return false
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

-- Arbre qui a le plus de points ; nil si aucun point ou égalité. Sans
-- GetNumTalentTabs (Forever), la spécialisation choisie. Second retour :
-- d'où vient l'arbre (« points » ou « specialisation »), pour /sg spe.
function Jeu.arbreTalents()
    if not GetNumTalentTabs or not GetTalentTabInfo then
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
