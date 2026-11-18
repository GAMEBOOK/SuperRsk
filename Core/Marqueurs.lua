-- Marqueurs : un symbole de raid sur moi, et sur les personnes de ma liste
-- (nom -> symbole) quand elles sont dans mon groupe.
--
-- Décisions pures ; UI/Marqueurs.lua tient le bouton sécurisé qui pose
-- les symboles.

local ADDON, ns = ...

local Marqueurs = {}
ns.Marqueurs = Marqueurs
local L = ns.L or setmetatable({}, { __index = function(_, k) return k end })

-- Symboles du jeu, dans l'ordre de leur numéro (1 à 8).
Marqueurs.NOMS = { L["Étoile"], L["Cercle"], L["Losange"], L["Triangle"], L["Lune"], L["Carré"], L["Croix"], L["Crâne"] }

function Marqueurs.icone(i, taille)
    return ("|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_%d:%d|t"):format(i, taille or 16)
end

function Marqueurs.texture(i) return "Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. i end

-- Nom comparable : sans espaces autour, sans royaume, en minuscules.
function Marqueurs.cle(nom)
    if type(nom) ~= "string" then return nil end
    local n = nom:match("^%s*(.-)%s*$"):gsub("%-.*$", "")
    if n == "" then return nil end
    return n:lower()
end

local function valide(i) return type(i) == "number" and i >= 1 and i <= 8 and i % 1 == 0 end

-- Liste enregistrée, débarrassée des entrées abîmées : { { nom, icone } }.
function Marqueurs.liste(brute)
    local l, vus = {}, {}
    for _, e in ipairs(type(brute) == "table" and brute or {}) do
        local k = type(e) == "table" and Marqueurs.cle(e.nom)
        if k and valide(e.icone) and not vus[k] then
            vus[k] = true
            l[#l + 1] = { nom = e.nom, icone = e.icone }
        end
    end
    return l
end

-- Premier symbole libre (ni le mien ni un de la liste), sinon l'étoile.
function Marqueurs.libre(liste, moi)
    local pris = { [moi or 0] = true }
    for _, e in ipairs(liste) do pris[e.icone] = true end
    for i = 1, 8 do if not pris[i] then return i end end
    return 1
end

-- Ajoute une personne ; rend true, ou false et « vide » / « deja ».
function Marqueurs.ajouter(liste, nom, icone)
    local k = Marqueurs.cle(nom)
    if not k then return false, "vide" end
    for _, e in ipairs(liste) do
        if Marqueurs.cle(e.nom) == k then return false, "deja" end
    end
    -- Le royaume reste : « @Nom-Royaume » vise un joueur d'un autre royaume.
    liste[#liste + 1] = { nom = nom:match("^%s*(.-)%s*$"), icone = valide(icone) and icone or 1 }
    return true
end

-- Texte de macro qui pose les symboles (le jeu n'accepte « /tm » que sur
-- une action du joueur). « ~ » (12.0.7) : une personne qui porte déjà un
-- symbole n'est pas retouchée (le second appui ne l'enlève pas, celui d'un
-- autre joueur reste). « exists » : une personne absente du groupe est sautée.
-- Un symbole ne va qu'à une personne : le mien d'abord, puis l'ordre de la
-- liste (sinon chaque appui le ferait sauter de l'un à l'autre).
function Marqueurs.macro(moi, liste)
    local lignes, pris = {}, {}
    if valide(moi) then
        lignes[1] = "/tm [@player] ~" .. moi
        pris[moi] = true
    end
    for _, e in ipairs(liste) do
        if not pris[e.icone] then
            pris[e.icone] = true
            lignes[#lignes + 1] = ("/tm [@%s,exists] ~%d"):format(e.nom, e.icone)
        end
    end
    return table.concat(lignes, "\n")
end


---------------------------------------------------------------------------
-- Swap groupé : changer de couche avec LayerSwap quand on joue groupé avec
-- ses persos (multibox). LayerSwap refuse de demander en groupe : un bouton,
-- trois étapes (quitter, demander, « je valide mon layer » qui réinvite).
-- Avant de quitter, le main prévient ses persos (message d'addon invisible) :
-- ils quittent aussi le groupe restant et acceptent seuls son invitation.
-- Ils acceptent aussi toujours les noms de leur propre liste de Marqueurs.
-- Quitter, inviter et accepter marchent sans clic (LayerSwap le fait déjà).
---------------------------------------------------------------------------

local Swap = {}
ns.SwapGroupe = Swap

Swap.PREFIXE = "SGSwap"
Swap.DUREE = 900          -- le main retenu, en secondes
Swap.DELAI_INVITE = 1.5   -- après avoir quitté le groupe de l'hôte
Swap.ATTENTE_HOTE = 180   -- après la demande de swap : l'invitation de l'hôte passe seule

-- phase : nil, « parti » (groupe quitté), « demande » (swap demandé)
local etat = { phase = nil, alts = {}, chef = nil, jusqua = 0, symboles = false }
Swap._etat = etat

local function secret(v) return issecretvalue and issecretvalue(v) end
local function maintenant() return GetTime and GetTime() or 0 end
local function enGroupe() return IsInGroup and IsInGroup() and true or false end
local function actif() return not ns.Reglages or ns.Reglages.get("swapGroupeActif") ~= false end
local function apres(s, f) if C_Timer and C_Timer.After then C_Timer.After(s, f) else f() end end

local function quitterGroupe()
    local f = (C_PartyInfo and C_PartyInfo.LeaveParty) or LeaveParty
    if f then pcall(f) end
end

local function expulser(nom)
    local f = (C_PartyInfo and C_PartyInfo.UninviteUnit) or UninviteUnit
    if f then pcall(f, nom) end
end

local function inviter(nom)
    local f = (C_PartyInfo and C_PartyInfo.InviteUnit) or InviteUnit
    if f then pcall(f, nom) end
end

-- LayerSwap chargé ?
function Swap.layerSwap()
    return (SlashCmdList and SlashCmdList.LAYERSWAP) or _G.LayerSwapPanelSwapButton
end

-- Bouton 1 : « quitter » (en groupe avec mes persos) ou « demander ».
-- Après le départ, IsInGroup reste vrai un instant : la phase dit la suite.
function Swap.etape()
    if etat.phase == nil and enGroupe() then return "quitter" end
    return "demander"
end

-- Persos retenus, gardés au /reload (par personnage).
local function sauver()
    if type(SuperGuideCharDB) == "table" then SuperGuideCharDB.swapAlts2 = etat.alts end
end

function Swap.charger()
    local l = type(SuperGuideCharDB) == "table" and SuperGuideCharDB.swapAlts2
    if type(l) == "table" and #etat.alts == 0 then
        for _, nom in ipairs(l) do
            if type(nom) == "string" and nom ~= "" then etat.alts[#etat.alts + 1] = nom end
        end
    end
end

-- Qui inviter : les persos retenus au départ, plus ma liste de Marqueurs
-- (mes alts), sans doublon ni moi.
function Swap.aInviter()
    local l, vus = {}, {}
    local moi = Swap.monNom()
    if not secret(moi) then vus[Marqueurs.cle(moi) or ""] = true end
    local function ajouter(nom)
        local k = Marqueurs.cle(nom)
        if k and not vus[k] then vus[k] = true; l[#l + 1] = nom end
    end
    for _, nom in ipairs(etat.alts) do ajouter(nom) end
    for _, e in ipairs(Marqueurs.personnes and Marqueurs.personnes() or {}) do ajouter(e.nom) end
    return l
end

function Swap.nombreAlts() return #Swap.aInviter() end

-- Ceux avec qui j'ai été groupé : un perso du multibox fait confiance à
-- leur demande de quitter son groupe, même en chuchotement d'addon.
Swap.MAX_CONNUS = 40
function Swap.noterGroupe()
    if type(SuperGuideCharDB) == "table" then
        SuperGuideCharDB.swapConnus2 = type(SuperGuideCharDB.swapConnus2) == "table" and SuperGuideCharDB.swapConnus2 or {}
        etat.connus = SuperGuideCharDB.swapConnus2
    end
    etat.connus = etat.connus or {}
    local n = 0
    for _ in pairs(etat.connus) do n = n + 1 end
    for _, nom in ipairs(Swap.membres()) do
        local k = Marqueurs.cle(nom)
        if k and not etat.connus[k] and n < Swap.MAX_CONNUS then etat.connus[k] = true; n = n + 1 end
    end
end

-- Après la réinvitation, dès que le groupe existe et que je le mène :
-- butin en accès libre (une fois).
function Swap.reglerButin()
    if not etat.butin or not enGroupe() then return false end
    if not (UnitIsGroupLeader and UnitIsGroupLeader("player")) then return false end
    etat.butin = false
    local actuel = GetLootMethod and GetLootMethod()
    if actuel == "freeforall" then return true end
    local f = (C_PartyInfo and C_PartyInfo.SetLootMethod) or SetLootMethod
    if f then pcall(f, "freeforall") end
    return true
end

function Swap.connu(nom)
    local k = Marqueurs.cle(nom)
    if not k then return false end
    if etat.connus and etat.connus[k] then return true end
    for _, e in ipairs(Marqueurs.personnes and Marqueurs.personnes() or {}) do
        if Marqueurs.cle(e.nom) == k then return true end
    end
    return false
end

-- Bouton 2 : « valider », puis « symboles » une fois les persos réinvités
-- (poser un symbole demande un clic du joueur : le même bouton s'en charge).
function Swap.etape2()
    if etat.symboles and ns.Reglages and ns.Reglages.get("marqueursActif") ~= false then return "symboles" end
    return "valider"
end

function Swap.symbolesPoses() etat.symboles = false end

-- LayerSwap lit la couche sur les créatures autour (plaques, cible, survol),
-- deux au moins. Plaques cachées hors combat : on les montre un instant
-- (réglages d'avant rendus après). Rend true si quelque chose a changé.
Swap.PLAQUES = { "nameplateShowAll", "nameplateShowEnemies", "nameplateShowFriendlyNPCs" }
Swap.DUREE_PLAQUES = 30
local avantPlaques = {}

function Swap.rendrePlaques()
    local jeu = ns.Jeu
    if not (jeu and jeu.ecrireCvar) then return end
    if jeu.enCombat and jeu.enCombat() then apres(5, Swap.rendrePlaques); return end
    for nom, v in pairs(avantPlaques) do pcall(jeu.ecrireCvar, nom, v) end
    avantPlaques = {}
end

function Swap.preparerLecture()
    local jeu = ns.Jeu
    if not (jeu and jeu.cvar and jeu.ecrireCvar) or (jeu.enCombat and jeu.enCombat()) then return false end
    local change = false
    for _, nom in ipairs(Swap.PLAQUES) do
        local ok, v = pcall(jeu.cvar, nom)
        if ok and v ~= nil and tostring(v) ~= "1" then
            if avantPlaques[nom] == nil then avantPlaques[nom] = v end
            pcall(jeu.ecrireCvar, nom, "1")
            change = true
        end
    end
    if change then apres(Swap.DUREE_PLAQUES, Swap.rendrePlaques) end
    return change
end

-- Nom complet d'une unité, tel que l'invitation l'attend. Sur Forever, le
-- second retour de UnitName est le NOM DE FAMILLE (« Super » + « Rsk » =
-- « Super Rsk ») ; sur les autres clients, c'est le royaume (« Nom-Royaume »).
local function forever()
    local toc = GetBuildInfo and select(4, GetBuildInfo())
    return type(toc) == "number" and toc >= 16000 and toc < 20000
end

function Swap.nomComplet(premier, second)
    if type(premier) ~= "string" or secret(premier) or premier == "" then return nil end
    if type(second) ~= "string" or secret(second) or second == "" then return premier end
    if forever() then
        local c = Constants and Constants.CharacterNameSeparatorConsts
        local sep = c and type(c.CHARACTERNAME_SURNAME_SEPARATOR) == "string" and c.CHARACTERNAME_SURNAME_SEPARATOR or " "
        if sep == "" then sep = " " end
        return premier .. sep .. second
    end
    return premier .. "-" .. second
end

-- Mon nom complet (« Super Rsk », comme les autres me voient).
function Swap.monNom()
    if not UnitName then return nil end
    return Swap.nomComplet(UnitName("player"))
end

-- Les autres membres du groupe, noms complets (pour l'invitation).
function Swap.membres()
    local l = {}
    local raid = IsInRaid and IsInRaid()
    local n = raid and (GetNumGroupMembers and GetNumGroupMembers() or 0)
              or (GetNumSubgroupMembers and GetNumSubgroupMembers() or 0)
    for i = 1, n do
        local unite = (raid and "raid" or "party") .. i
        if not (UnitIsUnit and UnitIsUnit(unite, "player")) then
            local nom = Swap.nomComplet(UnitName(unite))
            if nom and nom ~= UNKNOWNOBJECT then l[#l + 1] = nom end
        end
    end
    return l
end

function Swap.quitter()
    etat.alts = Swap.membres()
    sauver()
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        pcall(C_ChatInfo.SendAddonMessage, Swap.PREFIXE, "PART", (IsInRaid and IsInRaid()) and "RAID" or "PARTY")
    end
    etat.phase = "parti"
    Swap.preparerLecture()
    -- Chef : j'expulse d'abord mes persos, le groupe est dissous (sinon le
    -- lead passe à l'un d'eux et ils restent groupés entre eux, impossibles
    -- à réinviter). Le message part avant.
    local chef = UnitIsGroupLeader and UnitIsGroupLeader("player")
    local alts = etat.alts
    apres(0.3, function()
        if chef then for _, nom in ipairs(alts) do expulser(nom) end end
        quitterGroupe()
    end)
end

-- Dans le clic du joueur (LayerSwap a besoin de cette action). Dans le
-- groupe d'un hôte, le bouton de LayerSwap sait quitter et redemander ;
-- seul, « /ls swap » demande sans que son panneau soit ouvert.
function Swap.demander()
    local b, cmd = _G.LayerSwapPanelSwapButton, SlashCmdList and SlashCmdList.LAYERSWAP
    if enGroupe() and etat.phase ~= "parti" then
        if b and b.Click then b:Click() else quitterGroupe() end
    elseif etat.phase == nil and Swap.preparerLecture() then
        -- Seul, plaques cachées : on les montre, la demande part au clic suivant.
        etat.phase = "lecture"
        if ns.Jeu and ns.Jeu.message then
            ns.Jeu.message(L["Je montre les PNJ autour pour que LayerSwap lise ta couche : reclique sur Swap ! dans une seconde."])
        end
        return
    elseif cmd then
        Swap.preparerLecture()
        pcall(cmd, "swap")
    elseif b and b.Click then
        b:Click()
    end
    etat.phase = "demande"
    Swap.noterDemande()
end

-- Une demande de swap vient de partir (notre bouton, ou LayerSwap lui-même :
-- son bouton, /ls swap, ou sa nouvelle demande après un hôte qui ne nous a
-- pas déplacés) : l'invitation d'un hôte passe seule pendant ATTENTE_HOTE.
function Swap.noterDemande() etat.demandeA = maintenant() end

-- Groupe quitté pendant une attente : LayerSwap redemande, l'attente repart.
function Swap.surGroupeQuitte()
    if etat.demandeA and maintenant() - etat.demandeA <= Swap.ATTENTE_HOTE then Swap.noterDemande() end
    if Swap.rafraichir then Swap.rafraichir() end
end

-- Bouton 2 : quitte le groupe de l'hôte s'il y est, réinvite les persos
-- retenus. Rend leur nombre.
function Swap.valider()
    local alts = Swap.aInviter()
    etat.alts, etat.phase, etat.demandeA = {}, nil, nil
    sauver()
    etat.symboles = #alts > 0
    etat.butin = #alts > 0 and ns.Reglages and ns.Reglages.get("swapButinLibre") ~= false
    local function tous() for _, nom in ipairs(alts) do inviter(nom) end end
    -- Encore groupés entre eux (départ fait sans nous) : le jeu refuserait
    -- l'invitation. Chacun reçoit « quitte ton groupe » avant.
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        for _, nom in ipairs(alts) do pcall(C_ChatInfo.SendAddonMessage, Swap.PREFIXE, "PART", "WHISPER", nom) end
    end
    if enGroupe() then quitterGroupe() end
    if #alts > 0 then apres(Swap.DELAI_INVITE, tous) end
    return #alts
end

local function apresClic()
    if Swap.rafraichir then Swap.rafraichir() end
end

function Swap.cliquer()
    if not actif() then return end
    if Swap.etape() == "quitter" then Swap.quitter() else Swap.demander() end
    apresClic()
end

function Swap.cliquerValider()
    if not actif() then return end
    local n = Swap.valider()
    if n == 0 and ns.Jeu and ns.Jeu.message then
        ns.Jeu.message(L["Aucun perso à inviter : ajoute tes persos dans la liste des Marqueurs (ou clique sur « Quitter + swap » quand tu es groupé avec eux)."])
    end
    apresClic()
end

-- Côté perso : le main annonce son départ.
function Swap.surMessage(prefixe, msg, canal, envoyeur)
    if prefixe ~= Swap.PREFIXE or msg ~= "PART" or not actif() then return end
    if secret(envoyeur) then return end
    if canal ~= "PARTY" and canal ~= "RAID" and not (canal == "WHISPER" and Swap.connu(envoyeur)) then return end
    local k = Marqueurs.cle(envoyeur)
    local moi = Swap.monNom()
    if not k or secret(moi) or k == Marqueurs.cle(moi) then return end
    etat.chef, etat.jusqua = k, maintenant() + Swap.DUREE
    if enGroupe() then
        quitterGroupe()
        if ns.Jeu and ns.Jeu.message then ns.Jeu.message(L["%s part changer de couche : je quitte le groupe (Swap groupé)."]:format(envoyeur)) end
    end
end

-- Invitation à accepter seul : le main retenu (15 min), un nom de ma liste
-- ou quelqu'un avec qui j'ai déjà été groupé (mes autres persos), ou
-- n'importe qui juste après ma demande de swap (l'hôte de LayerSwap).
function Swap.accepte(nom)
    if not actif() or secret(nom) then return false end
    if etat.demandeA and maintenant() - etat.demandeA <= Swap.ATTENTE_HOTE and not enGroupe() then
        return true
    end
    local k = Marqueurs.cle(nom)
    if not k then return false end
    if k == etat.chef and maintenant() <= etat.jusqua then return true end
    return Swap.connu(nom)
end

-- Fenêtres liées à l'invitation : celle du jeu (PARTY_INVITE) est fermée
-- marquée acceptée (sinon sa fermeture refuse) ; une autre qui parle
-- d'invitation, de couche ou de transfert (« vous allez changer de couche… »)
-- est validée par son premier bouton.
Swap.FENETRES = { "INVITE", "LAYER", "SHARD", "PHASE", "TRANSFER", "XREALM" }

function Swap.fenetreInvitation(which)
    if type(which) ~= "string" then return false end
    local w = which:upper()
    for _, mot in ipairs(Swap.FENETRES) do
        if w:find(mot, 1, true) then return true end
    end
    return false
end

local function fermerFenetre()
    for i = 1, (STATICPOPUP_NUMDIALOGS or 4) do
        local f = _G["StaticPopup" .. i]
        if f and f.IsShown and f:IsShown() and Swap.fenetreInvitation(f.which) then
            if f.which == "PARTY_INVITE" then
                f.inviteAccepted = 1
                f:Hide()
            else
                local b = f.button1 or (f.ButtonContainer and f.ButtonContainer.Button1)
                if b and b.IsShown and b:IsShown() and b.Click then b:Click() end
            end
        end
    end
end

function Swap.surInvitation(nom)
    if not Swap.accepte(nom) then return false end
    if AcceptGroup then AcceptGroup() end
    if ns.Jeu and ns.Jeu.message then ns.Jeu.message(L["Invitation de %s acceptée (Swap groupé)."]:format(nom)) end
    fermerFenetre()
    -- Une confirmation peut s'ouvrir un peu après l'acceptation.
    for _, t in ipairs({ 0.1, 0.5, 1, 2 }) do apres(t, fermerFenetre) end
    return true
end
