-- Auto Loot : liste animée du butin ramassé (ex-LootDisplay de SuperAutoLoot).
--
-- Au LOOT_READY on note les objets du corps ; les messages de butin du chat
-- (les nôtres seulement) et la variation d'argent les font apparaître : une
-- ligne glisse, reste 3 s (tant que la souris est dessus) puis s'efface. Un
-- même objet ramassé à nouveau s'ajoute à sa ligne. Les objets de quête ont
-- une lueur dorée autour de l'icône. Placée par le mode
-- Déplacement.

local ADDON, ns = ...

local ListeButin = {}
ns.ListeButin = ListeButin
local L = ns.L or setmetatable({}, { __index = function(_, k) return k end })

local ICONE, HAUTEUR, ECART, LARGEUR = 28, 28, 4, 200
local DELAI, MAX = 0.15, 20
-- Temps d'affichage d'une ligne (réglage « butinDuree », 5 s par défaut).
local function DUREE() return tonumber(ns.Reglages.get("butinDuree")) or 5 end
-- Sens de la liste depuis l'ancre : vers le bas (par défaut) ou vers le haut.
-- Fondu de sortie (s), et écart entre deux lignes qui s'effacent : elles
-- partent une par une, dans l'ordre d'arrivée.
local FONDU, ECART_FONDU = 1.5, 0.45
local function SENS() return ns.Reglages.get("butinSens") == "haut" and 1 or -1 end
local MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\Media\\Butin\\"
local ARGENT = "ARGENT"

local ancre, zone, evenements
local reserve, actives, attente = {}, {}, {}
local corps = {}          -- objets du corps ouvert, par emplacement
local dernierNombre, argent, dernierePose = 0, 0, 0
local survol = false
local minuteurArret

local function vider(f)
    f:Hide()
    f:SetAlpha(0)
    f.cle, f.lien, f.nombre, f.qualite = nil, nil, 0, 1
    f.debut, f.flash, f.fin, f.liberer, f.sansAnim, f.libre = 0, 0, 0, false, false, true
    f.quete = false
    f.Flash:SetAlpha(0)
    f.Lueur:Hide()
    f:ClearAllPoints()
end

local function prendre()
    for _, f in ipairs(reserve) do
        if f.libre then f.libre = false; return f end
    end
end

local function texte(d, nombre, hex)
    if d.argent then
        local t = (C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString and C_CurrencyInfo.GetCoinTextureString(nombre))
            or (ns.Jeu and ns.Jeu.texteArgent and ns.Jeu.texteArgent(nombre)) or tostring(nombre)
        return ("|c%s%s|r"):format(hex, t)
    end
    return ("|cffffffff+%d|r |c%s%s|r"):format(nombre, hex, d.nom or "")
end

-- Pièce d'or, d'argent ou de cuivre selon le montant (en cuivre).
local function iconeArgent(cuivre)
    if cuivre >= 10000 then return "Interface\\Icons\\INV_Misc_Coin_01" end
    if cuivre >= 100 then return "Interface\\Icons\\INV_Misc_Coin_03" end
    return "Interface\\Icons\\INV_Misc_Coin_05"
end

-- Icône d'un objet : celle du corps, sinon celle lue dans son lien, sinon « ? ».
local function iconeObjet(d)
    if d.icone then return d.icone end
    local lien = d.lien
    if type(lien) == "string" then
        local f = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
        local id = tonumber(lien:match("item:(%d+)"))
        local ok, ic = pcall(f, id or lien)
        if ok and ic then return ic end
    end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

-- Objet de quête : signalé par le corps, sinon classe « Quête » (12) ou
-- objet lié « quête » (4) lus dans son lien.
function ListeButin.estQuete(d)
    if d.argent then return false end
    if d.quete then return true end
    local id = type(d.lien) == "string" and tonumber(d.lien:match("item:(%d+)"))
    if not id then return false end
    local instant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if instant then
        local ok, _, _, _, _, _, classe = pcall(instant, id)
        if ok and classe == 12 then return true end
    end
    local info = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if info then
        local ok, lie = pcall(function() return select(14, info(id)) end)
        if ok and lie == 4 then return true end
    end
    return false
end

local function couleur(qualite)
    return C_Item.GetItemQualityColor(qualite or 1)
end

local function lancerFlash(f, now)
    local r, g, b = couleur(f.qualite)
    f.flash = now
    f.Flash:SetVertexColor(r, g, b)
    f.Flash:SetAlpha(1)
end

local function ordonner()
    for i = 2, #actives do
        local avant, f = actives[i - 1], actives[i]
        if f.fin < avant.fin + ECART_FONDU then f.fin = avant.fin + ECART_FONDU end
    end
end

local function poser(d, now)
    local f = prendre()
    if not f then return end
    f.cle, f.lien, f.nombre, f.qualite = d.cle, d.lien, d.nombre, d.qualite or 1
    f.debut, f.fin, f.sansAnim, f.liberer, f.argent, f.nom = now, now + DUREE(), false, false, d.argent, d.nom
    local _, _, _, hex = couleur(f.qualite)
    if f.qualite >= 4 then lancerFlash(f, now) else f.flash = 0; f.Flash:SetAlpha(0) end
    f.quete = ListeButin.estQuete(d)
    f.Lueur:SetShown(f.quete)
    f.Icone:Show()
    f.Bord:Show()
    f.Icone:SetTexCoord(0.0625, 0.9375, 0.0625, 0.9375)
    if d.argent then
        f.Icone:SetTexture(iconeArgent(d.nombre or 0))
        f.Bord:SetVertexColor(1, 0.82, 0, 1)
    else
        local r, g, b = couleur(f.qualite)
        f.Icone:SetTexture(iconeObjet(d))
        f.Bord:SetVertexColor(r, g, b, 1)
    end
    f.Texte:SetText(texte(d, d.nombre, hex))
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", zone, "TOPLEFT", -20, SENS() * (#actives * (HAUTEUR + ECART)))
    f:SetAlpha(0)
    f:Show()
    actives[#actives + 1] = f
end

local function animer()
    local now = GetTime()
    if #attente > 0 and now - dernierePose >= DELAI then
        dernierePose = now
        poser(table.remove(attente, 1), now)
        ordonner()
    end
    for i = #actives, 1, -1 do
        if actives[i].liberer then vider(table.remove(actives, i)) end
    end
    if #actives == 0 and #attente == 0 then
        zone:SetScript("OnUpdate", nil)
        return
    end
    for i, f in ipairs(actives) do
        local cible = SENS() * ((i - 1) * (HAUTEUR + ECART))
        local _, _, _, _, y = f:GetPoint()
        y = (y or cible) + (cible - (y or cible)) * 0.15
        if f.flash > 0 then
            local age = now - f.flash
            if age < 1 then f.Flash:SetAlpha(1 - age) else f.Flash:SetAlpha(0); f.flash = 0 end
        end
        if f.quete then f.Lueur:SetAlpha(0.55 + 0.45 * math.sin(now * 4)) end
        local reste = f.fin - now
        if reste < FONDU then
            if survol then
                f.fin = now + DUREE()
                f:SetAlpha(1)
            else
                f:SetAlpha(math.max(0, reste / FONDU))
            end
        elseif f.sansAnim then
            f:SetAlpha(1)
            f:SetPoint("TOPLEFT", zone, "TOPLEFT", 0, y)
        else
            local entree = math.min(1, (now - f.debut) / 0.2)
            f:SetAlpha(entree)
            f:SetPoint("TOPLEFT", zone, "TOPLEFT", -20 + 20 * entree, y)
        end
        if reste <= 0 then f.liberer = true end
    end
end

-- Nouvelle ligne, ou ajout à la ligne (ou l'attente) du même objet.
function ListeButin.ajouter(d)
    d.nombre = (d.nombre and d.nombre >= 1) and d.nombre or 1
    d.cle = d.argent and ARGENT or d.nom
    local now = GetTime()
    zone:SetScript("OnUpdate", animer)
    for _, f in ipairs(actives) do
        if f.cle == d.cle then
            -- Même objet : il reste plus longtemps, sans passer devant les suivants.
            f.fin = now + DUREE()
            ordonner()
            f.nombre = f.nombre + d.nombre
            if f.argent then f.Icone:SetTexture(iconeArgent(f.nombre)) end
            f.sansAnim = true
            f.lien = d.lien or f.lien
            local _, _, _, hex = couleur(f.qualite)
            f.Texte:SetText(texte(f, f.nombre, hex))
            if f.qualite >= 4 then lancerFlash(f, now) end
            return
        end
    end
    for _, a in ipairs(attente) do
        if a.cle == d.cle then a.nombre = a.nombre + d.nombre; return end
    end
    attente[#attente + 1] = d
end

local function creerLigne()
    local f = CreateFrame("Button", nil, zone)
    f:SetSize(LARGEUR, HAUTEUR)
    if f.SetPropagateMouseClicks then f:SetPropagateMouseClicks(true) end
    f.Icone = f:CreateTexture(nil, "ARTWORK")
    f.Icone:SetSize(ICONE, ICONE)
    f.Icone:SetPoint("LEFT")
    f.Texte = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.Texte:SetPoint("LEFT", f.Icone, "RIGHT", 10, 0)
    local fond = f:CreateTexture(nil, "BACKGROUND")
    fond:SetAllPoints()
    fond:SetColorTexture(0, 0, 0)
    if fond.SetGradient and CreateColor then
        fond:SetGradient("HORIZONTAL", CreateColor(0, 0, 0, 0.8), CreateColor(0, 0, 0, 0))
    end
    f.Flash = f:CreateTexture(nil, "OVERLAY", nil, 1)
    f.Flash:SetAllPoints()
    f.Flash:SetColorTexture(1, 1, 1, 0.5)
    f.Bord = f:CreateTexture(nil, "OVERLAY")
    f.Bord:SetAllPoints(f.Icone)
    if f.Bord.SetTextureSliceMargins and Enum.UITextureSliceMode then
        f.Bord:SetTextureSliceMargins(6, 6, 6, 6)
        f.Bord:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
    end
    f.Bord:SetTexture(MEDIA .. "Bord.tga")
    -- Lueur dorée qui pulse autour de l'icône des objets de quête.
    f.Lueur = f:CreateTexture(nil, "OVERLAY", nil, 2)
    f.Lueur:SetSize(ICONE * 1.75, ICONE * 1.75)
    f.Lueur:SetPoint("CENTER", f.Icone, "CENTER")
    f.Lueur:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    f.Lueur:SetBlendMode("ADD")
    f.Lueur:SetVertexColor(1, 0.82, 0.1)
    f.Lueur:Hide()
    f:SetScript("OnEnter", function(self)
        if not self.lien then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(self.lien)
        GameTooltip:Show()
        survol = true
    end)
    f:SetScript("OnLeave", function()
        GameTooltip:Hide()
        survol = false
    end)
    vider(f)
    return f
end

---------------------------------------------------------------------------
-- Événements
---------------------------------------------------------------------------

local SUIVI = { "CHAT_MSG_LOOT", "CHAT_MSG_CURRENCY", "PLAYER_MONEY" }

local function suivre(oui)
    for _, e in ipairs(SUIVI) do
        if oui then evenements:RegisterEvent(e) else evenements:UnregisterEvent(e) end
    end
end

local function secret(v) return issecretvalue and issecretvalue(v) end

-- Le message vise-t-il un objet du corps ? Alors on l'affiche (une fois).
local function surMessage(msg, compare)
    if secret(msg) then return end
    local lien, nombre = ns.Butin.lireMessage(msg)
    if not lien then return end
    for i, d in pairs(corps) do
        if compare(d, lien) then
            d.nombre = nombre
            ListeButin.ajouter(d)
            corps[i] = nil
            return
        end
    end
end

local REACTIONS = {}

function REACTIONS.LOOT_READY()
    local n = GetNumLootItems()
    if n == 0 or dernierNombre == n then return end
    if minuteurArret then minuteurArret:Cancel() end
    suivre(true)
    argent = GetMoney()
    wipe(corps)
    for i = 1, n do
        local icone, nom, quantite, monnaie, qualite, _, quete, idQuete = GetLootSlotInfo(i)
        if monnaie and CurrencyContainerUtil then
            nom, icone, quantite, qualite = CurrencyContainerUtil.GetCurrencyContainerInfo(monnaie, quantite, nom, icone, qualite)
        end
        if GetLootSlotType(i) ~= 2 then -- 2 = pièces : suivies par PLAYER_MONEY
            corps[i] = { nom = nom, icone = icone, qualite = qualite or 1, lien = GetLootSlotLink(i),
                quete = quete or idQuete }
        end
    end
    dernierNombre = n
end

-- Sur Forever, l'auteur peut être le prénom seul ou le nom complet (« Super
-- Rsk ») ; ailleurs « Nom-Royaume ». Auteur vide : message du joueur lui-même.
function ListeButin.estMoi(auteur)
    if auteur == nil or auteur == "" then return true end
    if secret(auteur) or type(auteur) ~= "string" then return false end
    local nom = auteur:gsub("%-.*$", "")
    local premier, second = UnitName("player")
    if nom == premier then return true end
    local complet = ns.SwapGroupe and ns.SwapGroupe.nomComplet and ns.SwapGroupe.nomComplet(premier, second)
    return complet ~= nil and nom == complet
end

function REACTIONS.CHAT_MSG_LOOT(msg, ...)
    local auteur = select(4, ...)
    if not ListeButin.estMoi(auteur) then return end
    surMessage(msg, function(d, lien) return d.lien == lien end)
end

function REACTIONS.CHAT_MSG_CURRENCY(msg)
    surMessage(msg, function(d, lien)
        local id = tonumber(lien:match("currency:(%d+)"))
        return id and d.lien and tonumber(d.lien:match("currency:(%d+)")) == id
    end)
end

function REACTIONS.PLAYER_MONEY()
    local m = GetMoney()
    local gain = m - (argent or m)
    argent = m
    if gain > 0 then ListeButin.ajouter({ argent = true, nombre = gain, qualite = 1 }) end
end

-- Les messages arrivent après la fermeture : on écoute encore 3 s.
function REACTIONS.LOOT_CLOSED()
    dernierNombre = 0
    if minuteurArret then minuteurArret:Cancel() end
    minuteurArret = C_Timer.NewTimer and C_Timer.NewTimer(3, function() suivre(false) end)
end

function ListeButin.surEvenement(e, ...)
    if REACTIONS[e] and ns.Reglages.get("butinListe") then REACTIONS[e](...) end
end

-- Vers le bas : les lignes partent du haut de l'ancre. Vers le haut : du bas
-- (la première ligne posée sur le bas de l'ancre, les suivantes au-dessus).
function ListeButin.placerZone()
    if not zone then return end
    zone:ClearAllPoints()
    if SENS() > 0 then
        zone:SetPoint("TOPLEFT", ancre, "BOTTOMLEFT", 0, HAUTEUR)
        zone:SetPoint("TOPRIGHT", ancre, "BOTTOMRIGHT", 0, HAUTEUR)
    else
        zone:SetPoint("TOPLEFT", ancre, "TOPLEFT")
        zone:SetPoint("TOPRIGHT", ancre, "TOPRIGHT")
    end
end

function ListeButin.appliquer(cle)
    if cle == "butinSens" then ListeButin.placerZone() end
end

---------------------------------------------------------------------------
-- Aperçu (page du module) : la vraie liste, nourrie en boucle d'un butin
-- d'exemple. Même rendu, mêmes animations, mêmes réglages qu'en jeu.
---------------------------------------------------------------------------

local EXEMPLES = {
    { nom = "Cuir léger", icone = "Interface\\Icons\\INV_Misc_LeatherScrap_03", qualite = 1, nombre = 1 },
    { argent = true, nombre = 4523, qualite = 1 },
    { nom = "Étoffe de lin", icone = "Interface\\Icons\\INV_Fabric_Linen_01", qualite = 1, nombre = 2 },
    { nom = "Bottes de l'éclaireur", icone = "Interface\\Icons\\INV_Boots_05", qualite = 2, nombre = 1 },
    { nom = "Patte de loup", icone = "Interface\\Icons\\INV_Misc_MonsterClaw_04", qualite = 1, nombre = 1, quete = true },
    { nom = "Os brisé", icone = "Interface\\Icons\\INV_Misc_Bone_01", qualite = 0, nombre = 1 },
}
local pilote, hauteurAvant

function ListeButin.vitrine() return ancre, "butin" end

local function viderTout()
    for i = #actives, 1, -1 do vider(table.remove(actives, i)) end
    wipe(attente)
    if zone then zone:SetScript("OnUpdate", nil) end
end

function ListeButin.apercu(oui)
    if not ancre then return end
    pilote = pilote or CreateFrame("Frame")
    if oui then
        hauteurAvant = hauteurAvant or ancre:GetHeight()
        ancre:SetHeight(3 * (HAUTEUR + ECART))     -- tient dans la bannière du menu
        ListeButin.placerZone()
        viderTout()
        ancre:Show()
        local n, prochain = 0, 0
        pilote:SetScript("OnUpdate", function()
            local now = GetTime()
            -- 3 lignes au plus : elles tiennent dans la bannière.
            if now < prochain or #actives + #attente >= 3 then return end
            prochain = now + 0.9
            n = n % #EXEMPLES + 1
            local e = EXEMPLES[n]
            local d = {}
            for k, v in pairs(e) do d[k] = v end
            if d.nom then d.nom = L[d.nom] end
            ListeButin.ajouter(d)
        end)
    else
        pilote:SetScript("OnUpdate", nil)
        viderTout()
        if hauteurAvant then ancre:SetHeight(hauteurAvant); hauteurAvant = nil end
        ListeButin.placerZone()
    end
end

function ListeButin.creer()
    ancre = CreateFrame("Frame", "SuperGuideListeButin", UIParent)
    ancre:SetSize(LARGEUR, 5 * (HAUTEUR + ECART))
    ancre:SetClampedToScreen(true)
    ns.Deplacement.inscrire(ancre, L["Butin ramassé"], "butin", { "CENTER", 400, 200 })
    -- Seules les poignées du mode Déplacement la bougent : pas de zone
    -- invisible qui mange les clics.
    ancre:EnableMouse(false)

    zone = CreateFrame("Frame", nil, ancre)
    ListeButin.placerZone()
    zone:SetHeight(1)
    zone:EnableMouse(false)
    for i = 1, MAX do reserve[i] = creerLigne() end

    evenements = CreateFrame("Frame")
    evenements:SetScript("OnEvent", function(_, e, ...) ListeButin.surEvenement(e, ...) end)
    evenements:RegisterEvent("LOOT_READY")
    evenements:RegisterEvent("LOOT_CLOSED")
end
