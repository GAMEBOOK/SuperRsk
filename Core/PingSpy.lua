-- Spy Ping : avec l'addon Spy, un clic sur un ennemi de sa liste le cible
-- (Spy le fait déjà) et pose en plus un ping du jeu dessus, visible par le
-- groupe. Le jeu n'envoie un ping que sur une action du joueur : on ajoute
-- donc la ligne « /ping » à la macro sécurisée de chaque ligne de Spy, qu'il
-- fabrique toujours avec Spy:TargetMacro (Spy/Forever.lua). Le même clic pose
-- un repère (TomTom s'il est là, sinon celui du jeu) là où Spy l'a vu.

local ADDON, ns = ...

local PingSpy = {}
ns.PingSpy = PingSpy

local function R(cle) return ns.Reglages.get(cle) end

PingSpy.TYPES = { Warning = true, Attack = true, Assist = true, OnMyWay = true }

-- Macro de ciblage de Spy, plus le ping si le module est actif. [harm] :
-- rien si personne n'a été ciblé (ennemi trop loin) ou si c'est un allié.
function PingSpy.macro(base)
    if R("spyPing") ~= true then return base end
    local genre = R("spyPingType")
    if not PingSpy.TYPES[genre] then genre = "Warning" end
    return base .. "\n/ping [@target,harm] " .. genre
end

-- Enveloppe Spy:TargetMacro (une seule fois). Rend true si Spy est là.
function PingSpy.brancher(spy)
    if type(spy) ~= "table" or type(spy.TargetMacro) ~= "function" then return false end
    if spy._superGuidePing then return true end
    local origine = spy.TargetMacro
    spy.TargetMacro = function(self, nom, ...) return PingSpy.macro(origine(self, nom, ...)) end
    spy._superGuidePing = true
    return true
end

-- Où Spy t'a vu croiser cet ennemi : carte, x, y (0 à 1) ; nil si inconnu.
function PingSpy.position(nom)
    local db = type(SpyPerCharDB) == "table" and SpyPerCharDB.PlayerData
    local d = db and db[nom]
    if not (d and d.mapID and tonumber(d.mapX) and tonumber(d.mapY)) then return nil end
    local x, y = tonumber(d.mapX), tonumber(d.mapY)
    if x <= 0 or y <= 0 then return nil end
    return d.mapID, x, y
end

-- Clic sur une ligne de Spy (avant sa macro) : au relâché du clic gauche
-- simple, repère sur l'endroit de la rencontre. Maj et Ctrl sont à Spy
-- (liste KOS, ignorés).
function PingSpy.surClic(spy, ligne, bouton, appui)
    if appui or bouton ~= "LeftButton" or R("spyPing") ~= true or R("spyWay") ~= true then return end
    local jeu = ns.Jeu
    if jeu.majEnfoncee() or jeu.ctrlEnfonce() then return end
    local nom = spy and spy.ButtonName and ligne and spy.ButtonName[ligne.id]
    if not nom or nom == "" then return end
    local carte, x, y = PingSpy.position(nom)
    if carte then jeu.repere(carte, x, y, nom) end
end

-- Réécrit les macros des lignes déjà affichées (Spy ne le fait que hors combat).
function PingSpy.rafraichir(spy, enCombat)
    if enCombat or type(spy) ~= "table" or type(spy.RefreshCurrentList) ~= "function" then return end
    pcall(spy.RefreshCurrentList, spy)
end

function PingSpy.creer()
    local spy = _G.Spy
    if PingSpy.brancher(spy) and type(spy.ButtonClicked) == "function" and hooksecurefunc then
        hooksecurefunc(spy, "ButtonClicked", function(s, ligne, bouton, appui)
            PingSpy.surClic(s, ligne, bouton, appui)
        end)
    end
end

function PingSpy.appliquer(cle)
    if cle == "spyPing" or cle == "spyPingType" then
        PingSpy.rafraichir(_G.Spy, ns.Jeu.enCombat())
    end
end

---------------------------------------------------------------------------
-- Victoires honorables : un petit widget déplaçable (icône PvP + total),
-- survol = aujourd'hui, total, rang, et le classement de la guilde. Les
-- membres qui ont SuperRsk s'envoient leurs chiffres par message d'addon
-- (canal de guilde) ; on garde ce qu'on a reçu dans SuperGuideDB.vhGuilde.
---------------------------------------------------------------------------

local VH = {}
ns.VH = VH

local L = ns.L or setmetatable({}, { __index = function(_, k) return k end })
VH.PREFIXE = "SGVH"
VH.INTERVALLE = 30      -- au plus un envoi par 30 s
VH.OUBLI = 30 * 86400   -- un membre muet depuis 30 jours sort du classement

local function secret(v) return issecretvalue and issecretvalue(v) end
local function lisible(v) if v == nil or secret(v) then return nil end return v end
local function maintenant() return time and time() or 0 end

-- 12345 -> « 12 345 »
function VH.nombre(n)
    local t = tostring(math.floor(tonumber(n) or 0))
    local signe, chiffres = t:match("^(-?)(%d+)$")
    if not chiffres then return t end
    local r = chiffres:reverse():gsub("(%d%d%d)", "%1 "):reverse():gsub("^ ", "")
    return signe .. r
end

-- Mes chiffres : { total, jour, rang (nil sans rang), nomRang, classe }.
-- Le compteur « à vie » du jeu compte déjà celles du jour (vérifié en jeu).
function VH.moi()
    local m = { total = 0, vie = 0, jour = 0 }
    if GetPVPLifetimeStats then
        local ok, hk = pcall(GetPVPLifetimeStats)
        if ok then m.vie = tonumber(lisible(hk)) or 0 end
    end
    if GetPVPSessionStats then
        local ok, hk = pcall(GetPVPSessionStats)
        if ok then m.jour = tonumber(lisible(hk)) or 0 end
    end
    m.total = m.vie
    if UnitPVPRank then
        local ok, r = pcall(UnitPVPRank, "player")
        r = ok and tonumber(lisible(r))
        if r and r > 0 then
            m.rang = r
            if GetPVPRankInfo then
                local ok2, nom = pcall(GetPVPRankInfo, r)
                m.nomRang = ok2 and lisible(nom) or nil
            end
        end
    end
    if UnitClass then
        local _, c = UnitClass("player")
        m.classe = lisible(c)
    end
    return m
end

local function guilde()
    if not (IsInGuild and IsInGuild()) or not GetGuildInfo then return nil end
    local g = lisible(GetGuildInfo("player"))
    return type(g) == "string" and g ~= "" and g or nil
end

local function base(g)
    SuperGuideDB = SuperGuideDB or {}
    SuperGuideDB.vhGuilde = type(SuperGuideDB.vhGuilde) == "table" and SuperGuideDB.vhGuilde or {}
    if not g then return nil end
    SuperGuideDB.vhGuilde[g] = SuperGuideDB.vhGuilde[g] or {}
    return SuperGuideDB.vhGuilde[g]
end

local function court(nom)
    if type(nom) ~= "string" or secret(nom) then return nil end
    local n = nom:gsub("%-.*$", "")
    return n ~= "" and n or nil
end

function VH.monNom()
    if ns.SwapGroupe and ns.SwapGroupe.monNom then return ns.SwapGroupe.monNom() end
    return court(UnitName and UnitName("player"))
end

-- Message : « V:total:rang:classe » (rang 0 = aucun), « Q » = demande.
function VH.message(m)
    return ("V:%d:%d:%s"):format(m.total or 0, m.rang or 0, m.classe or "")
end

function VH.lire(msg)
    local total, rang, classe = tostring(msg):match("^V:(%d+):(%d+):(%u*)$")
    if not total then return nil end
    return { total = tonumber(total), rang = tonumber(rang) > 0 and tonumber(rang) or nil,
             classe = classe ~= "" and classe or nil }
end

local dernierEnvoi = -1000
local function envoyer(texte)
    if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then return end
    pcall(C_ChatInfo.SendAddonMessage, VH.PREFIXE, texte, "GUILD")
end

-- Mes chiffres à la guilde (et chez moi), au plus toutes les INTERVALLE s.
function VH.partager(force)
    local g = guilde()
    local m = VH.moi()
    local moi = VH.monNom()
    local b = base(g)
    if b and moi then
        b[moi] = { total = m.total, rang = m.rang, classe = m.classe, t = maintenant() }
        local prenom = UnitName and court(UnitName("player"))
        if prenom and prenom ~= moi then b[prenom] = nil end
    end
    if not g or ns.Reglages.get("vhGuilde") == false then return false end
    local t = GetTime and GetTime() or 0
    if not force and t - dernierEnvoi < VH.INTERVALLE then return false end
    dernierEnvoi = t
    envoyer(VH.message(m))
    return true
end

function VH.surMessage(prefixe, msg, canal, envoyeur)
    if prefixe ~= VH.PREFIXE or canal ~= "GUILD" or ns.Reglages.get("vhGuilde") == false then return end
    local nom = court(envoyeur)
    if not nom or nom == VH.monNom() then return end
    if msg == "Q" then
        -- Chacun répond un peu plus tard, pas tous en même temps.
        local delai = 1 + (math.random and math.random() * 6 or 3)
        if C_Timer then C_Timer.After(delai, function() VH.partager(true) end) else VH.partager(true) end
        return
    end
    local d = VH.lire(msg)
    local b = base(guilde())
    if d and b then
        d.t, d.vu = maintenant(), nil
        b[nom] = d
        if VH.rafraichir then VH.rafraichir() end
    end
end

-- Classement : { { nom, total, rang, classe, moi } } trié, sans les oubliés.
function VH.classement()
    local b = base(guilde())
    local l, limite, moi = {}, maintenant() - VH.OUBLI, VH.monNom()
    for nom, d in pairs(b or {}) do
        if type(d) == "table" and tonumber(d.total) and (d.t or 0) >= limite then
            l[#l + 1] = { nom = nom, total = d.total, rang = d.rang, classe = d.classe, moi = nom == moi,
                          vu = d.vu and d.t or nil }
        end
    end
    table.sort(l, function(a, c)
        if a.total ~= c.total then return a.total > c.total end
        return a.nom < c.nom
    end)
    return l
end

-- Widget -----------------------------------------------------------------

local widget

local function couleurClasse(c)
    local col = c and RAID_CLASS_COLORS and RAID_CLASS_COLORS[c]
    if not col then return "ffe8ecf2" end
    return ("ff%02x%02x%02x"):format(col.r * 255, col.g * 255, col.b * 255)
end

local function icone()
    local f = UnitFactionGroup and lisible(UnitFactionGroup("player"))
    if f == "Horde" or f == "Alliance" then return "Interface\\TargetingFrame\\UI-PVP-" .. f, true end
    return "Interface\\Icons\\INV_BannerPVP_02", false
end

local function infobulle(self)
    local T = ns.Theme
    local m = VH.moi()
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(L["Victoires honorables"], 1, 0.82, 0)
    GameTooltip:AddDoubleLine(L["Aujourd'hui"], VH.nombre(m.jour), 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:AddDoubleLine(L["Au total"], VH.nombre(m.total), 0.7, 0.7, 0.7, 1, 1, 1)
    if m.rang then
        GameTooltip:AddDoubleLine(L["Rang"], (m.nomRang or "") .. " (" .. m.rang .. ")", 0.7, 0.7, 0.7, 1, 1, 1)
    end
    if guilde() and ns.Reglages.get("vhGuilde") ~= false then
        local l = VH.classement()
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["Guilde : %d joueur(s)"]:format(#l), 0.31, 0.85, 1)
        local top = tonumber(ns.Reglages.get("vhTop")) or 10
        local maPlace
        for i, e in ipairs(l) do if e.moi then maPlace = i end end
        for i = 1, math.min(top, #l) do
            local e = l[i]
            local medaille = (i == 1 and "|cffffd100") or (i == 2 and "|cffc0c0c0") or (i == 3 and "|cffcd7f32") or "|cff9aa3b2"
            local gauche = medaille .. i .. ".|r  |c" .. couleurClasse(e.classe) .. e.nom .. "|r"
            if e.moi then gauche = gauche .. " |cff4fd8ff" .. L["(toi)"] .. "|r" end
            if e.vu and date then gauche = gauche .. " |cff6f7889" .. L["vu le %s"]:format(date("%d/%m", e.vu)) .. "|r" end
            GameTooltip:AddDoubleLine(gauche, VH.nombre(e.total), 1, 1, 1, 1, 1, 1)
        end
        if maPlace and maPlace > top then
            GameTooltip:AddDoubleLine("|cff9aa3b2" .. maPlace .. ".|r  |cff4fd8ff" .. L["toi"] .. "|r",
                VH.nombre(l[maPlace].total), 1, 1, 1, 1, 1, 1)
        end
        if #l <= 1 then
            GameTooltip:AddLine(L["Les membres qui ont SuperRsk apparaissent en se connectant ; les autres quand tu passes près d'eux."], 0.6, 0.6, 0.6, true)
        end
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L["Glisser : déplacer."], 0.5, 0.5, 0.5)
    GameTooltip:Show()
end

function VH.rafraichir()
    if not widget then return end
    if ns.Reglages.get("vhActif") == false then widget:Hide(); return end
    local m = VH.moi()
    widget.texte:SetText(VH.nombre(m.total))
    local suffixe = m.jour > 0 and ("|cff6fdc6f+" .. VH.nombre(m.jour) .. "|r") or ""
    widget.jour:SetText(suffixe)
    widget:SetWidth(36 + math.max(widget.texte:GetStringWidth() or 30, 20) + (m.jour > 0 and ((widget.jour:GetStringWidth() or 0) + 6) or 0) + 10)
    widget:Show()
    if GameTooltip:IsOwned(widget) then infobulle(widget) end
end

local function placer()
    local pos = SuperGuideDB and SuperGuideDB.vhPos
    widget:ClearAllPoints()
    if type(pos) == "table" and pos.point then
        widget:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
    else
        widget:SetPoint("TOP", UIParent, "TOP", 0, -14)
    end
end

-- Bouton du module : le widget revient en haut au centre.
function VH.recentrer()
    SuperGuideDB = SuperGuideDB or {}
    SuperGuideDB.vhPos = nil
    if widget then placer(); VH.rafraichir() end
end

function VH.creer()
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        pcall(C_ChatInfo.RegisterAddonMessagePrefix, VH.PREFIXE)
    end
    local T = ns.Theme
    widget = CreateFrame("Button", "SuperGuideVH", UIParent)
    widget:SetSize(110, 28)
    widget:SetFrameStrata("MEDIUM")
    widget:SetMovable(true)
    widget:SetClampedToScreen(true)
    widget:RegisterForDrag("LeftButton")
    T.fond(widget, "panneau", 0.92, "bordFort")
    local ic = widget:CreateTexture(nil, "ARTWORK")
    ic:SetSize(26, 26)
    ic:SetPoint("LEFT", 5, -1)
    local tex, badge = icone()
    ic:SetTexture(tex)
    if badge then ic:SetTexCoord(0, 0.625, 0, 0.625) else ic:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    widget.texte = widget:CreateFontString(nil, "OVERLAY")
    widget.texte:SetFont(T.MEDIA .. "Polices\\Archivo-BoldCondensed.ttf", 15, "")
    widget.texte:SetTextColor(T.rgb("texte"))
    widget.texte:SetPoint("LEFT", ic, "RIGHT", 5, 1)
    widget.jour = widget:CreateFontString(nil, "OVERLAY")
    widget.jour:SetFont(T.MEDIA .. "Polices\\Archivo-BoldCondensed.ttf", 11, "")
    widget.jour:SetPoint("LEFT", widget.texte, "RIGHT", 6, 0)
    placer()
    widget:SetScript("OnDragStart", function(self) self:StartMoving() end)
    widget:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        SuperGuideDB = SuperGuideDB or {}
        SuperGuideDB.vhPos = { point = point, x = x, y = y }
    end)
    if C_Timer and C_Timer.NewTicker then
        C_Timer.NewTicker(5, function()
            local avant = widget.dernier
            local m = VH.moi()
            if m.total ~= avant then
                widget.dernier = m.total
                VH.rafraichir()
                if avant then VH.partager(false) end
            end
        end)
    end
    widget:SetScript("OnEnter", infobulle)
    widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
    VH.rafraichir()

    -- Au démarrage : mes chiffres, puis demande ceux des autres.
    if C_Timer then
        C_Timer.After(8, function()
            VH.partager(true)
            if guilde() and ns.Reglages.get("vhGuilde") ~= false then envoyer("Q") end
            VH.rafraichir()
        end)
    end
end

-- Une victoire de plus.
function VH.surVictoire()
    VH.partager(false)
    VH.rafraichir()
end

function VH.appliquer(cle)
    if cle == "vhActif" or cle == "vhGuilde" or cle == "vhTop" then
        VH.rafraichir()
        if cle == "vhGuilde" and ns.Reglages.get("vhGuilde") ~= false then VH.partager(true); envoyer("Q") end
    end
end

-- Membres sans SuperRsk : relevés par inspection quand on passe près
-- d'eux (souris, cible, plaque, groupe), hors combat, un toutes les
-- INSPECTION s, chacun au plus toutes les REVOIR s. Le jeu donne alors
-- GetInspectHonorData() : aujourd'hui, -, hier, -, total, rang…
VH.INSPECTION = 3
VH.REVOIR = 600
local attente           -- { guid, nom, classe, a }
local dernierInspect = -1000
local revus = {}        -- [nom] = GetTime()

-- Lit la réponse du jeu : { total, rang } ou nil (pas de données).
function VH.lireInspection(...)
    local n = select("#", ...)
    if n < 5 then return nil end
    local total, rang = tonumber(lisible((select(5, ...)))), tonumber(lisible((select(6, ...))))
    if not total then return nil end
    return { total = total, rang = (rang and rang > 0) and rang or nil }
end

local function inspectionLibre()
    if InCombatLockdown and InCombatLockdown() then return false end
    if InspectFrame and InspectFrame.IsShown and InspectFrame:IsShown() then return false end
    return true
end

-- Une unité vue : membre de ma guilde, joueur, à portée -> on l'inspecte.
function VH.croiser(unite)
    if ns.Reglages.get("vhActif") == false or not guilde() then return false end
    if not (NotifyInspect and UnitExists and UnitExists(unite)) then return false end
    if not (UnitIsPlayer and UnitIsPlayer(unite)) or (UnitIsUnit and UnitIsUnit(unite, "player")) then return false end
    if not (UnitIsInMyGuild and lisible(UnitIsInMyGuild(unite))) then return false end
    local nom = ns.SwapGroupe and ns.SwapGroupe.nomComplet(UnitName(unite)) or court(UnitName(unite))
    if not nom then return false end
    local t = GetTime and GetTime() or 0
    if revus[nom] and t - revus[nom] < VH.REVOIR then return false end
    if t - dernierInspect < VH.INSPECTION or not inspectionLibre() then return false end
    if CanInspect and not lisible(CanInspect(unite)) then return false end
    if CheckInteractDistance and not lisible(CheckInteractDistance(unite, 1)) then return false end
    local _, classe = UnitClass(unite)
    attente = { guid = lisible(UnitGUID(unite)), nom = nom, classe = lisible(classe), a = t }
    dernierInspect, revus[nom] = t, t
    pcall(NotifyInspect, unite)
    return true
end

-- Réponse du jeu (INSPECT_READY / INSPECT_HONOR_UPDATE).
function VH.surInspection(guid)
    if not attente or not GetInspectHonorData then return false end
    local t = GetTime and GetTime() or 0
    if t - attente.a > 5 then attente = nil; return false end
    if guid ~= nil and not secret(guid) and attente.guid and guid ~= attente.guid then return false end
    local d = VH.lireInspection(GetInspectHonorData())
    if not d or d.total == 0 then return false end   -- pas encore arrivé : l'événement suivant
    local b = base(guilde())
    local ancien = b and b[attente.nom]
    -- Un membre qui a SuperRsk garde ses chiffres envoyés (plus frais).
    if b and not (ancien and not ancien.vu and (ancien.t or 0) > maintenant() - 3600) then
        b[attente.nom] = { total = d.total, rang = d.rang, classe = attente.classe, t = maintenant(), vu = true }
    end
    attente = nil
    if not (InspectFrame and InspectFrame.IsShown and InspectFrame:IsShown()) and ClearInspectPlayer then
        pcall(ClearInspectPlayer)
    end
    VH.rafraichir()
    return true
end

-- Groupe ou raid : les membres de la guilde à portée.
function VH.parcourirGroupe()
    local raid = IsInRaid and IsInRaid()
    local n = raid and (GetNumGroupMembers and GetNumGroupMembers() or 0) or (GetNumSubgroupMembers and GetNumSubgroupMembers() or 0)
    for i = 1, n do
        if VH.croiser((raid and "raid" or "party") .. i) then return end
    end
end
