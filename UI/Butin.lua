-- Auto Loot (ex-addon SuperAutoLoot) : ramassage instantané.
--
-- La fenêtre de butin du jeu vit dans un cadre caché : on vide les
-- emplacements un par un (un toutes les 0,033 s) et elle ne réapparaît que
-- s'il reste quelque chose (objet pour le groupe, sacs pleins, lié quand
-- ramassé en groupe). Décisions dans Core/Butin.lua.

local ADDON, ns = ...

local Butin = ns.Butin
local L = ns.L or setmetatable({}, { __index = function(_, k) return k end })
local function R(cle) return ns.Reglages.get(cle) end

local SON_PLEIN = 139
local CANAL = "master"
local RYTHME = 0.033

local evenements, cache
local veille = false -- l'addon SuperAutoLoot est encore chargé
local etat = {}

local function remettre()
    etat.enCours, etat.cachee, etat.bloque, etat.echec = false, true, false, false
    etat.dernier, etat.auto, etat.sonJoue = nil, false, false
end
remettre()

local function actif() return not veille and R("butinRapide") end

---------------------------------------------------------------------------
-- Fenêtre de butin du jeu
---------------------------------------------------------------------------

local function geree() return LootFrame and LootFrame:IsEventRegistered("LOOT_OPENED") end
local modeEdition = function() return LootFrame and LootFrame.UpdateShownState ~= nil end

-- Sous la souris si l'option du jeu le demande, sinon à sa place.
local function ancrer()
    local f = LootFrame
    if GetCVarBool("lootUnderMouse") then
        local x, y = GetCursorPosition()
        f:ClearAllPoints()
        local e = f:GetEffectiveScale()
        if modeEdition() then
            f:SetPoint("TOPLEFT", nil, "BOTTOMLEFT", x / e - 30, math.max(y / e + 50, 350))
        else
            f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / e - 40, y / e + 20)
        end
        f:Raise()
    elseif modeEdition() and f.systemInfo and f.systemInfo.anchorInfo then
        local a, s = f.systemInfo.anchorInfo, f:GetScale()
        f:SetPoint(a.point, a.relativeTo, a.relativePoint, a.offsetX / s, a.offsetY / s)
    else
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, -125)
    end
end

local function montrerFenetre(retarde)
    etat.cachee = false
    if not geree() then return end
    LootFrame:SetParent(UIParent)
    LootFrame:SetFrameStrata("HIGH")
    ancrer()
    if retarde then ancrer() end
end

-- Module coupé : la fenêtre revient sous UIParent pour de bon.
local function cacherFenetre()
    if not geree() then return end
    LootFrame:SetParent(actif() and cache or UIParent)
end

---------------------------------------------------------------------------
-- Ramassage
---------------------------------------------------------------------------

local function seuil()
    local enGroupe, partage = IsInGroup(), false
    if enGroupe and C_PartyInfo and C_PartyInfo.GetLootMethod and Enum.LootMethod then
        local m, E = C_PartyInfo.GetLootMethod(), Enum.LootMethod
        partage = m == E.Group or m == E.Needbeforegreed or m == E.Masterlooter
    end
    return Butin.seuil(enGroupe, partage, partage and GetLootThreshold())
end

-- Cases libres de chaque sac ; le sac de composants (5) ne prend que les
-- composants d'artisanat.
local function sacs(reactif)
    local s = { porteCles = 0 }
    local cle = Enum.BagIndex and Enum.BagIndex.Keyring
    if cle then s.porteCles = C_Container.GetContainerNumFreeSlots(cle) or 0 end
    for sac = BACKPACK_CONTAINER or 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4 do
        if sac ~= 5 or reactif then
            local libres, famille = C_Container.GetContainerNumFreeSlots(sac)
            s[#s + 1] = { libres = libres or 0, famille = famille }
        end
    end
    return s
end

-- C_Item d'abord, l'API globale sur les clients qui n'ont qu'elle.
local function api(nom) return (C_Item and C_Item[nom]) or _G[nom] end

local function tient(lien, quantite)
    if not lien then return true end
    local pile, _, _, _, _, _, _, _, _, reactif = select(8, api("GetItemInfo")(lien))
    return Butin.tientDansSacs({ famille = api("GetItemFamily")(lien), pile = pile,
        possede = api("GetItemCount")(lien), quantite = quantite }, sacs(reactif))
end

local function typeEmplacement(i)
    local t, E = GetLootSlotType(i), Enum.LootSlotType
    if t == E.None then return "aucun" end
    return t == E.Item and "objet" or "autre"
end

local function seul() return (GetNumGroupMembers() or 0) <= 1 end

-- Rend false si l'emplacement reste plein (la fenêtre devra s'ouvrir).
local function ramasser(i)
    local lien = GetLootSlotLink(i)
    local _, _, quantite, _, qualite, verrouille = GetLootSlotInfo(i)
    local d = Butin.decision({ type = typeEmplacement(i), verrouille = verrouille, qualite = qualite },
        etat.seuil, function() return tient(lien, quantite) end)
    if d == "vide" then return true end
    if d == "bloque" then etat.bloque = true end
    if d ~= "ramasser" then return false end
    LootSlot(i)
    if R("butinConfirmerLie") and seul() then ConfirmLootSlot(i) end
    return true
end

local function arreter()
    if etat.minuteur then etat.minuteur:Cancel() end
    etat.minuteur = nil
end

-- Du dernier emplacement au premier : les numéros ne bougent pas.
local function vider(n)
    arreter()
    local i = n
    etat.minuteur = C_Timer.NewTicker(RYTHME, function()
        if i >= 1 then
            if not ramasser(i) then etat.echec = true end
            i = i - 1
        else
            if etat.echec then montrerFenetre() end
            arreter()
        end
    end, n + 1)
end

-- Popup « lié quand ramassé » du jeu : coupée seul si on confirme pour toi.
local function popupLie()
    if not UIParent.RegisterEvent then return end
    if actif() and R("butinConfirmerLie") and seul() then
        UIParent:UnregisterEvent("LOOT_BIND_CONFIRM")
    else
        UIParent:RegisterEvent("LOOT_BIND_CONFIRM")
    end
end

---------------------------------------------------------------------------
-- Événements
---------------------------------------------------------------------------

local PLEIN = {}

local REACTIONS = {}

function REACTIONS.LOOT_READY(auto)
    etat.enCours = true
    -- Un clic répété peut inverser « auto » : le premier événement fait foi.
    if not etat.auto then
        etat.auto = auto or GetCVarBool("autoLootDefault") ~= IsModifiedClick("AUTOLOOTTOGGLE")
    end
    local n = GetNumLootItems()
    if n == 0 or etat.dernier == n then return end
    if IsFishingLoot() and R("butinSonPeche") then PlaySound(SOUNDKIT.FISHING_REEL_IN, CANAL) end
    if etat.auto then
        etat.seuil = seuil()
        vider(n)
    else
        montrerFenetre()
    end
    etat.dernier = n
end
REACTIONS.LOOT_OPENED = REACTIONS.LOOT_READY

function REACTIONS.LOOT_CLOSED()
    arreter()
    remettre()
    cacherFenetre()
end

function REACTIONS.LOOT_BIND_CONFIRM(i)
    if not (etat.enCours and LootSlotHasItem(i)) then return end
    if R("butinConfirmerLie") and seul() then ConfirmLootSlot(i) end
    if etat.cachee then montrerFenetre(true) end
end

function REACTIONS.UI_ERROR_MESSAGE(_, msg)
    if not PLEIN[msg] or not etat.enCours then return end
    if etat.cachee then montrerFenetre(true) end
    -- Sacs pleins (message du jeu, dans la langue du client) : la poubelle propose.
    if msg == ERR_INV_FULL and ns.Poubelle then ns.Poubelle.surPlein() end
    if msg ~= ERR_LOOT_ROLL_PENDING and R("butinSonPlein") and not etat.sonJoue and not etat.bloque then
        etat.sonJoue = true
        PlaySound(SON_PLEIN, CANAL)
    end
end

REACTIONS.GROUP_ROSTER_UPDATE = popupLie

function Butin.surEvenement(e, ...)
    if REACTIONS[e] and (actif() or e == "GROUP_ROSTER_UPDATE") then REACTIONS[e](...) end
end

local LISTE = { "LOOT_READY", "LOOT_OPENED", "LOOT_CLOSED", "LOOT_BIND_CONFIRM", "UI_ERROR_MESSAGE" }

local function brancher()
    for _, e in ipairs(LISTE) do
        if actif() then evenements:RegisterEvent(e) else evenements:UnregisterEvent(e) end
    end
    if not actif() then arreter(); remettre() end
    cacherFenetre()
    popupLie()
end

local function autoJeu(oui)
    if C_CVar and C_CVar.SetCVar then C_CVar.SetCVar("autoLootDefault", oui and "1" or "0") end
end

function Butin.appliquer(cle)
    if cle == "butinRapide" or cle == "butinConfirmerLie" then brancher()
    elseif cle == "butinAuto" then autoJeu(R("butinAuto")) end
end

local function autreAddon()
    local charge = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    return charge and charge("SuperAutoLoot") and true or false
end

function Butin.creer()
    for _, m in ipairs({ ERR_INV_FULL, ERR_ITEM_MAX_COUNT, ERR_LOOT_ROLL_PENDING }) do PLEIN[m] = true end
    cache = CreateFrame("Frame", nil, UIParent)
    cache:Hide()
    evenements = CreateFrame("Frame")
    evenements:SetScript("OnEvent", function(_, e, ...) Butin.surEvenement(e, ...) end)
    evenements:RegisterEvent("GROUP_ROSTER_UPDATE")

    veille = autreAddon()
    if veille then
        ns.Jeu.message(L["Auto Loot en veille : l'addon SuperAutoLoot est encore activé (désactive-le pour utiliser le module)."])
    end
    if not veille and R("butinAuto") then autoJeu(true) end

    -- Mode édition du jeu : la fenêtre doit rester visible pour être placée.
    if modeEdition() and hooksecurefunc then
        hooksecurefunc(LootFrame, "UpdateShownState", function(f)
            if not geree() then return end
            f:SetParent((f.isInEditMode or not actif()) and UIParent or cache)
        end)
    end
    brancher()
    -- Certaines interfaces reprennent la fenêtre après la connexion.
    C_Timer.After(5, cacherFenetre)
end
