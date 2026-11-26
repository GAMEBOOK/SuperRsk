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
        b[moi] = { total = m.total, rang = m.rang, classe = m.classe, t = maintenant(), addon = true }
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

-- Tout le monde : les joueurs avec SuperRsk croisés en groupe, en raid, en
-- champ de bataille ou dans la guilde (les 500 plus récents).
VH.MONDE_MAX = 500
VH.PAUSE_GROUPE = 10   -- au plus un envoi au groupe toutes les 10 s

local function monde()
    SuperGuideDB = SuperGuideDB or {}
    SuperGuideDB.vhMonde = type(SuperGuideDB.vhMonde) == "table" and SuperGuideDB.vhMonde or {}
    return SuperGuideDB.vhMonde
end

local function noterMonde(nom, d)
    local m = monde()
    m[nom] = { total = d.total, rang = d.rang, classe = d.classe, t = d.t, addon = true }
    local n, plusVieux, tVieux = 0, nil, math.huge
    for k, e in pairs(m) do
        n = n + 1
        if (e.t or 0) < tVieux then plusVieux, tVieux = k, e.t or 0 end
    end
    if n > VH.MONDE_MAX and plusVieux then m[plusVieux] = nil end
end

local GROUPE = { PARTY = true, RAID = true, INSTANCE_CHAT = true }

local function canalGroupe()
    if IsInGroup and LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
    if IsInRaid and IsInRaid() then return "RAID" end
    if IsInGroup and IsInGroup() then return "PARTY" end
end

local dernierGroupe = -1000
-- Mes chiffres au groupe (et la demande des leurs), au plus toutes les 10 s.
function VH.partagerGroupe(demander)
    if ns.Reglages.get("vhMonde") == false then return false end
    local c = canalGroupe()
    if not (c and C_ChatInfo and C_ChatInfo.SendAddonMessage) then return false end
    local t = GetTime and GetTime() or 0
    if t - dernierGroupe < VH.PAUSE_GROUPE then return false end
    dernierGroupe = t
    pcall(C_ChatInfo.SendAddonMessage, VH.PREFIXE, VH.message(VH.moi()), c)
    if demander then pcall(C_ChatInfo.SendAddonMessage, VH.PREFIXE, "Q", c) end
    return true
end

-- Le groupe change (quelqu'un arrive, je rejoins) : je me présente.
function VH.surGroupe() return VH.partagerGroupe(true) end

function VH.surMessage(prefixe, msg, canal, envoyeur)
    if prefixe ~= VH.PREFIXE then return end
    local groupe = GROUPE[canal]
    if canal == "GUILD" then
        if ns.Reglages.get("vhGuilde") == false then return end
    elseif not (groupe and ns.Reglages.get("vhMonde") ~= false) then
        return
    end
    local nom = court(envoyeur)
    if not nom or nom == VH.monNom() then return end
    if msg == "Q" then
        -- Chacun répond un peu plus tard, pas tous en même temps.
        local delai = 1 + (math.random and math.random() * 6 or 3)
        local repondre = function() if groupe then VH.partagerGroupe(false) else VH.partager(true) end end
        if C_Timer then C_Timer.After(delai, repondre) else repondre() end
        return
    end
    local d = VH.lire(msg)
    if not d then return end
    d.t, d.vu, d.addon = maintenant(), nil, true
    noterMonde(nom, d)
    local b = canal == "GUILD" and base(guilde())
    if b then b[nom] = d end
    if VH.rafraichir then VH.rafraichir() end
end

-- A SuperRsk : il a envoyé ses chiffres lui-même (au moins une fois).
function VH.aLAddon(d)
    return type(d) == "table" and (d.addon == true or (d.vu == nil and d.total ~= nil)) or false
end

-- Nom court -> a SuperRsk ? (membres de ma guilde connus).
function VH.connuAvecAddon(nom)
    local k = court(nom)
    if not k then return false end
    local b = base(guilde())
    if b and VH.aLAddon(b[k]) then return true end
    return monde()[k] ~= nil
end

-- Boussole de SuperRsk dans un texte : cyan = a l'addon, gris = ne l'a pas.
function VH.icone(oui, taille)
    taille = taille or 12
    local c = oui and "79:216:255" or "110:120:137"
    return ("|TInterface\\AddOns\\%s\\Media\\Icones\\boussole:%d:%d:0:0:64:64:0:64:0:64:%s|t"):format(ADDON, taille, taille, c)
end

-- Classement : { { nom, total, rang, classe, moi } } trié, sans les oubliés.
function VH.classement()
    local b = base(guilde())
    local l, limite, moi = {}, maintenant() - VH.OUBLI, VH.monNom()
    for nom, d in pairs(b or {}) do
        if type(d) == "table" and tonumber(d.total) and (d.t or 0) >= limite then
            l[#l + 1] = { nom = nom, total = d.total, rang = d.rang, classe = d.classe, moi = nom == moi,
                          vu = d.vu and d.t or nil, addon = VH.aLAddon(d) }
        end
    end
    table.sort(l, function(a, c)
        if a.total ~= c.total then return a.total > c.total end
        return a.nom < c.nom
    end)
    return l
end

-- Tout le monde : joueurs avec SuperRsk rencontrés (guilde comprise) et moi,
-- triés par victoires.
function VH.classementMonde()
    local vus, l, moi = {}, {}, VH.monNom()
    local limite = maintenant() - VH.OUBLI * 2
    local function ajouter(nom, d)
        if vus[nom] or type(d) ~= "table" or not tonumber(d.total) then return end
        vus[nom] = true
        l[#l + 1] = { nom = nom, total = d.total, rang = d.rang, classe = d.classe, moi = nom == moi, addon = true }
    end
    if moi then
        local m = VH.moi()
        ajouter(moi, { total = m.total, rang = m.rang, classe = m.classe })
    end
    for nom, d in pairs(monde()) do if (d.t or 0) >= limite then ajouter(nom, d) end end
    for nom, d in pairs(base(guilde()) or {}) do if VH.aLAddon(d) then ajouter(nom, d) end end
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

-- « 1.  Nom (toi) vu le 12/11 » : rang en couleur de médaille, nom en couleur de classe.
local function gaucheClassement(i, e)
    local medaille = (i == 1 and "|cffffd100") or (i == 2 and "|cffc0c0c0") or (i == 3 and "|cffcd7f32") or "|cff9aa3b2"
    local gauche = medaille .. i .. ".|r  " .. VH.icone(e.addon) .. " |c" .. couleurClasse(e.classe) .. e.nom .. "|r"
    if e.moi then gauche = gauche .. " |cff4fd8ff" .. L["(toi)"] .. "|r" end
    if e.vu and date then gauche = gauche .. " |cff6f7889" .. L["vu le %s"]:format(date("%d/%m", e.vu)) .. "|r" end
    return gauche
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
        GameTooltip:AddLine(L["Guilde"], 0.31, 0.85, 1)
        local top = tonumber(ns.Reglages.get("vhTop")) or 10
        local maPlace
        for i, e in ipairs(l) do if e.moi then maPlace = i end end
        for i = 1, math.min(top, #l) do
            local e = l[i]
            GameTooltip:AddDoubleLine(gaucheClassement(i, e), VH.nombre(e.total), 1, 1, 1, 1, 1, 1)
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
    GameTooltip:AddLine(L["Clic : classement complet. Glisser : déplacer."], 0.5, 0.5, 0.5)
    GameTooltip:Show()
end

-- Liste complète (clic sur le widget) --------------------------------------

local liste
local LIGNE_VH = 20
local derniereDemande = -1000
VH.RELANCE = 60   -- au plus une demande à la guilde par minute en ouvrant la liste

local function classementVisible()
    return guilde() and ns.Reglages.get("vhGuilde") ~= false
end

-- Colonnes : rang (aligné à droite), boussole, nom, « vu le », total.
local LARGEUR_VH, COL_RANG, COL_ICONE, COL_NOM = 300, 26, 14, 34 + 14 + 6
local MEDAILLES = { { 1, 0.82, 0 }, { 0.75, 0.75, 0.75 }, { 0.8, 0.5, 0.2 } }

local function cheminIcone() return "Interface\\AddOns\\" .. ADDON .. "\\Media\\Icones\\boussole" end

local function ligneListe(i)
    local r = liste.lignes[i]
    if r then return r end
    local T, C = ns.Theme, ns.Controles
    r = CreateFrame("Frame", nil, liste.contenu)
    r:SetSize(liste.contenu:GetWidth(), LIGNE_VH)
    r:SetPoint("TOPLEFT", 0, -(i - 1) * LIGNE_VH)
    if i % 2 == 0 then
        local zebre = r:CreateTexture(nil, "BACKGROUND")
        zebre:SetAllPoints()
        zebre:SetColorTexture(1, 1, 1, 0.03)
    end
    r.rang = C.texte(r, "petit", "texteDoux")
    r.rang:SetPoint("LEFT", 4, 0)
    r.rang:SetWidth(COL_RANG)
    r.rang:SetJustifyH("RIGHT")
    r.icone = r:CreateTexture(nil, "ARTWORK")
    r.icone:SetSize(COL_ICONE, COL_ICONE)
    r.icone:SetPoint("LEFT", 4 + COL_RANG + 6, 0)
    r.icone:SetTexture(cheminIcone())
    r.total = C.texte(r, "petit", "texte")
    r.total:SetPoint("RIGHT", -6, 0)
    r.total:SetWidth(44)
    r.total:SetJustifyH("RIGHT")
    r.vu = C.texte(r, "petit", "textePale")
    r.vu:SetPoint("RIGHT", r.total, "LEFT", -8, 0)
    r.vu:SetJustifyH("RIGHT")
    r.nom = C.texte(r, "petit", "texte")
    r.nom:SetPoint("LEFT", 4 + COL_NOM + 6, 0)
    r.nom:SetPoint("RIGHT", r.vu, "LEFT", -6, 0)
    r.nom:SetJustifyH("LEFT")
    r.nom:SetWordWrap(false)
    liste.lignes[i] = r
    return r
end

local function remplirListe()
    local T = ns.Theme
    local tous = liste.onglet == "monde"
    for nom, b in pairs(liste.onglets) do
        b.texte:SetTextColor(T.rgb(nom == liste.onglet and "accent" or "texteDoux"))
    end
    local visible = tous and ns.Reglages.get("vhMonde") ~= false or (not tous and classementVisible())
    local l = visible and (tous and VH.classementMonde() or VH.classement()) or {}
    for i, e in ipairs(l) do
        local r = ligneListe(i)
        local med = MEDAILLES[i]
        r.rang:SetText(i .. ".")
        if med then r.rang:SetTextColor(unpack(med)) else r.rang:SetTextColor(T.rgb("texteDoux")) end
        if e.addon then r.icone:SetVertexColor(T.rgb("accent")) else r.icone:SetVertexColor(T.rgb("textePale")) end
        r.nom:SetText("|c" .. couleurClasse(e.classe) .. e.nom .. "|r" .. (e.moi and (" |cff4fd8ff" .. L["(toi)"] .. "|r") or ""))
        r.vu:SetText(e.vu and date and date("%d/%m", e.vu) or "")
        r.total:SetText(VH.nombre(e.total))
        r:Show()
    end
    for i = #l + 1, #liste.lignes do liste.lignes[i]:Hide() end
    liste.contenu:SetHeight(math.max(1, #l * LIGNE_VH))
    if tous and not visible then
        liste.vide:SetText(L["Coupé : option « Partager avec mes groupes » du module."])
        liste.vide:Show()
    elseif tous and #l <= 1 then
        liste.vide:SetText(L["Les joueurs qui ont SuperRsk apparaissent quand tu es en groupe, en raid ou en champ de bataille avec eux."])
        liste.vide:Show()
    elseif not visible then
        liste.vide:SetText(L["Le classement de la guilde demande une guilde et l'option « Partager avec ma guilde »."])
        liste.vide:Show()
    elseif #l <= 1 then
        liste.vide:SetText(L["Les membres qui ont SuperRsk apparaissent en se connectant ; les autres quand tu passes près d'eux."])
        liste.vide:Show()
    else
        liste.vide:Hide()
    end
end

local function creerListe()
    local T, C = ns.Theme, ns.Controles
    liste = CreateFrame("Frame", "SuperGuideVHListe", UIParent)
    liste:SetSize(LARGEUR_VH, 352)
    liste:SetFrameStrata("DIALOG")
    liste:SetClampedToScreen(true)
    liste:EnableMouse(true)
    T.fond(liste, "panneau", 0.96, "bordFort")
    -- En-tête : titre et croix, puis les onglets.
    liste.titre = C.texte(liste, "texte", "texte")
    liste.titre:SetPoint("TOPLEFT", 12, -12)
    liste.titre:SetText(L["Victoires honorables"])
    local fermer = C.bouton(liste, "X", "texteDoux", function() liste:Hide() end, 24)
    fermer:SetPoint("TOPRIGHT", -8, -8)
    -- Onglets : Guilde / Tout le monde.
    liste.onglet, liste.onglets = "guilde", {}
    local xo = 12
    for _, o in ipairs({ { "guilde", L["Guilde"] }, { "monde", L["Tout le monde"] } }) do
        local b = C.bouton(liste, o[2], "texteDoux", function() liste.onglet = o[1]; remplirListe() end, 110)
        b:SetPoint("TOPLEFT", xo, -36)
        liste.onglets[o[1]] = b
        xo = xo + 116
    end
    -- Séparateur, puis la liste qui défile (marge en bas : rien de coupé).
    local trait = liste:CreateTexture(nil, "ARTWORK")
    trait:SetColorTexture(T.rgb("bord"))
    trait:SetHeight(1)
    trait:SetPoint("TOPLEFT", 8, -68)
    trait:SetPoint("TOPRIGHT", -8, -68)
    local defile = CreateFrame("ScrollFrame", nil, liste)
    defile:SetPoint("TOPLEFT", 8, -74)
    defile:SetPoint("BOTTOMRIGHT", -8, 12)
    liste.contenu = CreateFrame("Frame", nil, defile)
    liste.contenu:SetSize(LARGEUR_VH - 16, 1)
    defile:SetScrollChild(liste.contenu)
    defile:EnableMouseWheel(true)
    defile:SetScript("OnMouseWheel", function(self, d)
        local max = math.max(0, liste.contenu:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(math.min(max, math.max(0, self:GetVerticalScroll() - d * LIGNE_VH * 3)))
    end)
    liste.vide = C.texte(liste, "petit", "texteDoux")
    liste.vide:SetPoint("BOTTOMLEFT", 12, 14)
    liste.vide:SetPoint("BOTTOMRIGHT", -12, 14)
    liste.lignes = {}
    liste:Hide()
    if UISpecialFrames then table.insert(UISpecialFrames, "SuperGuideVHListe") end
end

-- Clic sur le widget : ouvre ou ferme la liste, sous le widget (au-dessus
-- s'il est trop bas). Demande les derniers chiffres à la guilde.
function VH.basculerListe()
    if not widget then return end
    if not liste then creerListe() end
    if liste:IsShown() then liste:Hide(); return end
    liste:ClearAllPoints()
    if (widget:GetBottom() or 1000) < 360 then
        liste:SetPoint("BOTTOM", widget, "TOP", 0, 4)
    else
        liste:SetPoint("TOP", widget, "BOTTOM", 0, -4)
    end
    remplirListe()
    liste:Show()
    if classementVisible() and maintenant() - derniereDemande >= VH.RELANCE then
        derniereDemande = maintenant()
        envoyer("Q")
    end
end

-- Aperçu : une copie (même construction, sans liste ni infobulle) dans la
-- bannière du menu, avec mes chiffres ; le vrai widget reste à sa place.
local apercuVH = false
local copieVH

-- L'icône PvP et les deux nombres (total, « +jour »), sans les clics.
local function construireVH(nom)
    local T = ns.Theme
    local w = CreateFrame("Button", nom, UIParent)
    w:SetSize(110, 28)
    w:SetFrameStrata("MEDIUM")
    w:SetClampedToScreen(true)
    T.fond(w, "panneau", 0.92, "bordFort")
    local ic = w:CreateTexture(nil, "ARTWORK")
    ic:SetSize(26, 26)
    ic:SetPoint("LEFT", 5, -1)
    local tex, badge = icone()
    ic:SetTexture(tex)
    if badge then ic:SetTexCoord(0, 0.625, 0, 0.625) else ic:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    w.texte = w:CreateFontString(nil, "OVERLAY")
    w.texte:SetFont(T.MEDIA .. "Polices\\Archivo-BoldCondensed.ttf", 15, "")
    w.texte:SetTextColor(T.rgb("texte"))
    w.texte:SetPoint("LEFT", ic, "RIGHT", 5, 1)
    w.jour = w:CreateFontString(nil, "OVERLAY")
    w.jour:SetFont(T.MEDIA .. "Polices\\Archivo-BoldCondensed.ttf", 11, "")
    w.jour:SetPoint("LEFT", w.texte, "RIGHT", 6, 0)
    return w
end

-- Met le cadre w en forme avec mes chiffres m.
local function rendreVH(w, m)
    w.texte:SetText(VH.nombre(m.total))
    local suffixe = m.jour > 0 and ("|cff6fdc6f+" .. VH.nombre(m.jour) .. "|r") or ""
    w.jour:SetText(suffixe)
    w:SetWidth(36 + math.max(w.texte:GetStringWidth() or 30, 20) + (m.jour > 0 and ((w.jour:GetStringWidth() or 0) + 6) or 0) + 10)
    w:Show()
end

-- Copie montrée dans la bannière d'aperçu du menu (le vrai reste en place).
function VH.vitrine()
    if not copieVH then
        copieVH = construireVH(nil)
        copieVH:EnableMouse(false)
        copieVH:Hide()
        if apercuVH then rendreVH(copieVH, VH.moi()) end
    end
    return copieVH, "vh", true
end

function VH.apercu(oui)
    apercuVH = oui and true or false
    VH.rafraichir()
end

-- Le vrai widget (visible si le module est allumé) et la copie de l'aperçu.
function VH.rafraichir()
    local m
    if copieVH then
        if apercuVH then m = VH.moi(); rendreVH(copieVH, m) else copieVH:Hide() end
    end
    if not widget then return end
    if ns.Reglages.get("vhActif") == false then widget:Hide(); return end
    rendreVH(widget, m or VH.moi())
    if GameTooltip:IsOwned(widget) then infobulle(widget) end
    if liste and liste:IsShown() then remplirListe() end
end

-- Position : par le mode Déplacer (ancienne position du widget reprise).
local function placer()
    if not ns.Deplacement then
        widget:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 417, -312)
        return
    end
    ns.Deplacement.inscrire(widget, L["Victoires honorables"], "vh", { "TOPLEFT", 417, -312 })
    SuperGuideDB = SuperGuideDB or {}
    if SuperGuideDB.vhPos then
        ns.Deplacement.reprendre("vh", SuperGuideDB.vhPos)
        SuperGuideDB.vhPos = nil
    end
end

-- Bouton du module : le widget revient à sa place par défaut (en haut à gauche).
function VH.recentrer()
    if widget and ns.Deplacement then ns.Deplacement.remettre("vh"); VH.rafraichir() end
end

-- Infobulle d'un joueur : « SuperRsk » avec la boussole s'il a l'addon.
local function ligneInfobulle(tt)
    if ns.Reglages.get("vhGuilde") == false or not (tt and tt.GetUnit) then return end
    local ok, _, unite = pcall(tt.GetUnit, tt)
    if not ok or type(unite) ~= "string" or secret(unite) then return end
    if not (UnitIsPlayer and UnitIsPlayer(unite)) or not UnitName then return end
    local premier, second = UnitName(unite)
    local complet = ns.SwapGroupe and ns.SwapGroupe.nomComplet and ns.SwapGroupe.nomComplet(premier, second)
    if VH.connuAvecAddon(complet) or VH.connuAvecAddon(premier) then
        tt:AddLine(VH.icone(true, 14) .. " SuperRsk", 0.31, 0.85, 1)
        tt:Show()
    end
end

function VH.creer()
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tt)
            if tt == GameTooltip then ligneInfobulle(tt) end
        end)
    elseif GameTooltip and GameTooltip.HookScript then
        pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipSetUnit", ligneInfobulle)
    end
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        pcall(C_ChatInfo.RegisterAddonMessagePrefix, VH.PREFIXE)
    end
    widget = construireVH("SuperGuideVH")
    widget:SetMovable(true)
    widget:RegisterForDrag("LeftButton")
    placer()
    widget:RegisterForClicks("LeftButtonUp")
    widget:SetScript("OnClick", function(self)
        if self.finGlisser and GetTime() - self.finGlisser < 0.3 then return end
        GameTooltip:Hide()
        VH.basculerListe()
    end)
    -- Un glisser ne doit pas ouvrir la liste en lâchant.
    widget:HookScript("OnDragStop", function(self) self.finGlisser = GetTime() end)
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
        b[attente.nom] = { total = d.total, rang = d.rang, classe = attente.classe, t = maintenant(), vu = true,
                           addon = ancien and ancien.addon or nil }
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
