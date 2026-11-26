-- Auto Loot : liste animée du butin ramassé (ex-LootDisplay de SuperAutoLoot).
--
-- Au LOOT_READY on note les objets du corps ; les messages de butin du chat
-- (les nôtres seulement) et la variation d'argent les font apparaître : une
-- ligne glisse, reste 3 s (tant que la souris est dessus) puis s'efface. Un
-- même objet ramassé à nouveau s'ajoute à sa ligne. Les objets de quête ont
-- une lueur dorée autour de l'icône. Placée par le mode
-- Déplacement.
-- Aperçu : une copie (même construction) dans la bannière du menu, nourrie
-- d'un butin d'exemple ; la vraie liste continue d'afficher le vrai butin.

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

-- Une liste = { ancre, zone, reserve, actives, attente, survol, dernierePose } :
-- la vraie (vraie) et la copie de l'aperçu (copie) ont chacune la sienne.
local vraie, copie, evenements
local corps = {}          -- objets du corps ouvert, par emplacement
local dernierNombre, argent = 0, 0
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

local function prendre(l)
    for _, f in ipairs(l.reserve) do
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

local function ordonner(actives)
    for i = 2, #actives do
        local avant, f = actives[i - 1], actives[i]
        if f.fin < avant.fin + ECART_FONDU then f.fin = avant.fin + ECART_FONDU end
    end
end

local function poser(l, d, now)
    local f = prendre(l)
    if not f then return end
    local actives = l.actives
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
    f:SetPoint("TOPLEFT", l.zone, "TOPLEFT", -20, SENS() * (#actives * (HAUTEUR + ECART)))
    f:SetAlpha(0)
    f:Show()
    actives[#actives + 1] = f
end

local function animer(l)
    local now = GetTime()
    local actives, attente, zone = l.actives, l.attente, l.zone
    if #attente > 0 and now - l.dernierePose >= DELAI then
        l.dernierePose = now
        poser(l, table.remove(attente, 1), now)
        ordonner(actives)
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
            if l.survol then
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

-- Nouvelle ligne, ou ajout à la ligne (ou l'attente) du même objet, dans la liste l.
local function ajouterA(l, d)
    d.nombre = (d.nombre and d.nombre >= 1) and d.nombre or 1
    d.cle = d.argent and ARGENT or d.nom
    local now = GetTime()
    local actives, attente = l.actives, l.attente
    l.zone:SetScript("OnUpdate", l.animer)
    for _, f in ipairs(actives) do
        if f.cle == d.cle then
            -- Même objet : il reste plus longtemps, sans passer devant les suivants.
            f.fin = now + DUREE()
            ordonner(actives)
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

-- Le vrai butin, dans la vraie liste.
function ListeButin.ajouter(d)
    if vraie then ajouterA(vraie, d) end
end

-- Ligne de la liste l. Sans souris (la copie) : ni infobulle ni survol.
local function creerLigne(l, souris)
    local f = CreateFrame("Button", nil, l.zone)
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
    if souris then
        f:SetScript("OnEnter", function(self)
            if not self.lien then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(self.lien)
            GameTooltip:Show()
            l.survol = true
        end)
        f:SetScript("OnLeave", function()
            GameTooltip:Hide()
            l.survol = false
        end)
    else
        f:EnableMouse(false)
    end
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
local function placerZone(l)
    if not l then return end
    local zone, ancre = l.zone, l.ancre
    zone:ClearAllPoints()
    if SENS() > 0 then
        zone:SetPoint("TOPLEFT", ancre, "BOTTOMLEFT", 0, HAUTEUR)
        zone:SetPoint("TOPRIGHT", ancre, "BOTTOMRIGHT", 0, HAUTEUR)
    else
        zone:SetPoint("TOPLEFT", ancre, "TOPLEFT")
        zone:SetPoint("TOPRIGHT", ancre, "TOPRIGHT")
    end
end

-- La vraie liste et la copie de l'aperçu suivent le réglage du sens.
function ListeButin.placerZone()
    placerZone(vraie)
    placerZone(copie)
end

function ListeButin.appliquer(cle)
    if cle == "butinSens" then ListeButin.placerZone() end
end

-- Fabrique une liste : ancre sur UIParent, zone, n lignes en réserve.
-- Sans souris (la copie) : aucune ligne ne capte les clics ni le survol.
local function construire(nom, hauteur, n, souris)
    local ancre = CreateFrame("Frame", nom, UIParent)
    ancre:SetSize(LARGEUR, hauteur)
    ancre:SetClampedToScreen(true)
    -- Seules les poignées du mode Déplacement bougent la liste : pas de zone
    -- invisible qui mange les clics.
    ancre:EnableMouse(false)
    local l = { ancre = ancre, reserve = {}, actives = {}, attente = {}, survol = false, dernierePose = 0 }
    l.animer = function() animer(l) end
    ancre.liste = l
    l.zone = CreateFrame("Frame", nil, ancre)
    placerZone(l)
    l.zone:SetHeight(1)
    l.zone:EnableMouse(false)
    for i = 1, n do l.reserve[i] = creerLigne(l, souris) end
    return l
end

local function viderTout(l)
    for i = #l.actives, 1, -1 do vider(table.remove(l.actives, i)) end
    wipe(l.attente)
    l.zone:SetScript("OnUpdate", nil)
end

---------------------------------------------------------------------------
-- Aperçu (page du module) : une copie de la liste, nourrie en boucle d'un
-- butin d'exemple. Même rendu, mêmes animations, mêmes réglages qu'en jeu.
---------------------------------------------------------------------------

local EXEMPLES = {
    { nom = "Cuir léger", icone = "Interface\\Icons\\INV_Misc_LeatherScrap_03", qualite = 1, nombre = 1 },
    { argent = true, nombre = 4523, qualite = 1 },
    { nom = "Étoffe de lin", icone = "Interface\\Icons\\INV_Fabric_Linen_01", qualite = 1, nombre = 2 },
    { nom = "Bottes de l'éclaireur", icone = "Interface\\Icons\\INV_Boots_05", qualite = 2, nombre = 1 },
    { nom = "Patte de loup", icone = "Interface\\Icons\\INV_Misc_MonsterClaw_04", qualite = 1, nombre = 1, quete = true },
    { nom = "Os brisé", icone = "Interface\\Icons\\INV_Misc_Bone_01", qualite = 0, nombre = 1 },
}
local LIGNES_APERCU = 3   -- elles tiennent dans la bannière du menu

-- Copie montrée dans la bannière d'aperçu du menu (la vraie reste en place).
function ListeButin.vitrine()
    if not copie then
        copie = construire(nil, LIGNES_APERCU * (HAUTEUR + ECART), LIGNES_APERCU + 1, false)
        copie.ancre:Hide()
    end
    return copie.ancre, "butin", true
end

function ListeButin.apercu(oui)
    if not copie then return end
    local ancre = copie.ancre
    viderTout(copie)
    if oui then
        ancre:Show()
        local n, prochain = 0, 0
        -- La copie se nourrit elle-même : cachée (menu fermé), elle s'arrête.
        ancre:SetScript("OnUpdate", function()
            local now = GetTime()
            if now < prochain or #copie.actives + #copie.attente >= LIGNES_APERCU then return end
            prochain = now + 0.9
            n = n % #EXEMPLES + 1
            local d = {}
            for k, v in pairs(EXEMPLES[n]) do d[k] = v end
            if d.nom then d.nom = L[d.nom] end
            ajouterA(copie, d)
        end)
    else
        ancre:SetScript("OnUpdate", nil)
        ancre:Hide()
    end
end

function ListeButin.creer()
    vraie = construire("SuperGuideListeButin", 5 * (HAUTEUR + ECART), MAX, true)
    ns.Deplacement.inscrire(vraie.ancre, L["Butin ramassé"], "butin", { "CENTER", 400, 200 })

    evenements = CreateFrame("Frame")
    evenements:SetScript("OnEvent", function(_, e, ...) ListeButin.surEvenement(e, ...) end)
    evenements:RegisterEvent("LOOT_READY")
    evenements:RegisterEvent("LOOT_CLOSED")
end
