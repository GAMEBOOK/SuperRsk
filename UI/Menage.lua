-- Ménage des objets de quête : la fenêtre (déplaçable). Une ligne par objet
-- (case à cocher, icône, nom, raison), « Jeter la sélection » en bas. Les
-- objets sûrement inutiles sont cochés d'office, les autres non.
-- Décisions dans Core/Menage.lua.

local ADDON, ns = ...

local Menage = ns.Menage
local L = ns.L or setmetatable({}, { __index = function(_, k) return k end })

local cadre
local LARGEUR, LIGNE, VISIBLES = 560, 30, 10
-- tous : tout ce que le tri propose ; liste : ce qui est affiché. Les
-- objets incertains (aucune preuve qu'ils ne servent plus : accès de raid,
-- suite de chaîne inconnue…) restent masqués sauf demande.
local tous, liste, coches, decalage = {}, {}, {}, 0
local voirIncertains = false

local function filtrer()
    liste = {}
    for _, e in ipairs(tous) do
        if e.sur or voirIncertains then liste[#liste + 1] = e end
    end
    decalage = math.min(decalage, math.max(0, #liste - VISIBLES))
end

local function nbIncertains()
    local n = 0
    for _, e in ipairs(tous) do if not e.sur then n = n + 1 end end
    return n
end

local function T() return ns.Theme end

local function nbCoches()
    local n = 0
    for _, e in ipairs(liste) do if coches[e] then n = n + 1 end end
    return n
end

local function dessiner()
    if not cadre then return end
    local vides = #liste == 0
    cadre.vide:SetShown(vides)
    for i, l in ipairs(cadre.lignes) do
        local e = liste[i + decalage]
        l.entree = e
        l:SetShown(e ~= nil)
        if e then
            local o = e.objet
            l.icone:SetTexture(o.icone or "Interface\\Icons\\INV_Misc_QuestionMark")
            l.nom:SetText(o.lien .. (o.nombre > 1 and (" |cffffffffx" .. o.nombre .. "|r") or ""))
            l.raison:SetText(e.raison)
            l.raison:SetTextColor(T().rgb(e.sur and "vert" or "orange"))
            local c = coches[e]
            l.boite:SetTexture(T().icone(c and "case-cochee" or "case"))
            l.boite:SetVertexColor(T().rgb(c and "accent" or "texteDoux"))
        end
    end
    local n = nbCoches()
    cadre.jeter.texte:SetText(n > 1 and L["Jeter : encore %d clics"]:format(n) or L["Jeter la sélection (%d)"]:format(n))
    cadre.jeter:SetAlpha(n > 0 and 1 or 0.45)
    cadre.plus:SetText(#liste > VISIBLES and L["Molette : %d objets en tout"]:format(#liste) or "")
    cadre.source:SetText(ns.Jeu.questieCharge() and L["Proposés : objets dont toutes les quêtes sont terminées (Questie)."]
        or L["Sans Questie, seuls les objets sûrs sont proposés. Installe Questie pour en trouver plus."])
    local ni = nbIncertains()
    cadre.incertains:SetShown(ni > 0)
    cadre.incertains.texte:SetText(L["Montrer aussi les objets incertains (%d), à vérifier toi-même"]:format(ni))
    cadre.incertains.boite:SetTexture(T().icone(voirIncertains and "case-cochee" or "case"))
    cadre.incertains.boite:SetVertexColor(T().rgb(voirIncertains and "orange" or "texteDoux"))
end

-- Relit les sacs et les quêtes ; les sûrs sont cochés d'office.
local rouvrir = false
function Menage.ouvrir()
    if not cadre then return end
    if InCombatLockdown() or (UnitAffectingCombat and UnitAffectingCombat("player")) then
        rouvrir = true
        ns.Jeu.message(L["Pas pendant un combat : le ménage s'ouvrira à la fin du combat."])
        return
    end
    -- Rouverte après un clic : les cases de chaque objet restent comme tu
    -- les as laissées ; un nouvel objet prend la case par défaut.
    local avant = {}
    if cadre:IsShown() then
        for e, c in pairs(coches) do avant[e.objet.lien] = c end
    end
    if not cadre:IsShown() then voirIncertains = false end
    tous, coches, decalage = Menage.liste(), {}, 0
    for _, e in ipairs(tous) do
        local c = avant[e.objet.lien]
        if c == nil then c = e.sur end
        coches[e] = c
    end
    filtrer()
    cadre:Show()
    dessiner()
end

-- Mode photo : la vraie fenêtre, remplie d'objets d'exemple (rien ne se
-- jette). Rend le cadre ; oui = false remet la fenêtre comme avant.
local enExemple = false
local function exemple(nom, icone, nombre, sur, raison)
    return { objet = { lien = "|cffffffff[" .. nom .. "]|r", icone = "Interface\\Icons\\" .. icone, nombre = nombre },
             sur = sur, raison = raison }
end
function Menage.exemple(oui)
    if not cadre then return nil end
    if not oui then
        enExemple = false
        tous, liste, coches = {}, {}, {}
        cadre:Hide()
        return cadre
    end
    enExemple = true
    voirIncertains = true
    tous = {
        exemple("Sealed Letter", "INV_Letter_15", 1, true, L["sa quête est terminée"]),
        exemple("Wolf Paw", "INV_Misc_MonsterClaw_04", 8, true, L["sa quête est terminée"]),
        exemple("Murloc Fin", "INV_Misc_Fish_14", 6, true, L["toutes ses quêtes sont terminées"]),
        exemple("Broken Totem", "INV_Misc_Bone_08", 1, true, L["sa quête est terminée"]),
        exemple("Old Map Fragment", "INV_Misc_Map_01", 1, false, L["aucune quête en cours n'en parle"]),
    }
    coches, decalage = {}, 0
    for _, e in ipairs(tous) do coches[e] = e.sur end
    filtrer()
    cadre:Show()
    dessiner()
    return cadre
end

function Menage.basculer()
    if cadre and cadre:IsShown() then cadre:Hide() else Menage.ouvrir() end
end

local function creerLigne(i)
    local C = ns.Controles
    local l = CreateFrame("Button", nil, cadre)
    l:SetSize(LARGEUR - 24, LIGNE - 2)
    l:SetPoint("TOPLEFT", 12, -44 - (i - 1) * LIGNE)
    local survol = l:CreateTexture(nil, "BACKGROUND")
    survol:SetAllPoints()
    survol:SetColorTexture(T().rgb("flot"))
    survol:Hide()
    l.boite = l:CreateTexture(nil, "ARTWORK")
    l.boite:SetSize(16, 16)
    l.boite:SetPoint("LEFT", 4, 0)
    l.icone = l:CreateTexture(nil, "ARTWORK")
    l.icone:SetSize(22, 22)
    l.icone:SetPoint("LEFT", l.boite, "RIGHT", 8, 0)
    l.icone:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    l.nom = C.texte(l, "texte", "texte")
    l.nom:SetPoint("LEFT", l.icone, "RIGHT", 8, 0)
    l.nom:SetWidth(240)
    l.nom:SetWordWrap(false)
    l.raison = C.texte(l, "petit", "texteDoux")
    l.raison:SetPoint("RIGHT", -6, 0)
    l.raison:SetJustifyH("RIGHT")
    l.raison:SetWidth(230)
    l.raison:SetWordWrap(false)
    l:SetScript("OnClick", function(self)
        local e = self.entree
        if not e then return end
        coches[e] = not coches[e]
        dessiner()
    end)
    l:SetScript("OnEnter", function(self)
        survol:Show()
        local o = self.entree and self.entree.objet
        if not (o and o.sac) then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetBagItem(o.sac, o.case)
        GameTooltip:Show()
    end)
    l:SetScript("OnLeave", function() survol:Hide(); GameTooltip:Hide() end)
    return l
end

function Menage.creer()
    local C = ns.Controles
    cadre = CreateFrame("Frame", "SuperGuideMenage", UIParent)
    cadre:SetSize(LARGEUR, 44 + VISIBLES * LIGNE + 98)
    cadre:SetFrameStrata("DIALOG")
    cadre:SetClampedToScreen(true)
    T().fond(cadre, "panneau", 0.97, "bordFort")
    local titre = C.texte(cadre, "titre", "texte")
    titre:SetPoint("TOPLEFT", 14, -14)
    titre:SetText(L["Ménage des objets de quête"])
    local fermer = C.bouton(cadre, "X", "texteDoux", function() cadre:Hide() end, 24)
    fermer:SetPoint("TOPRIGHT", -10, -10)

    cadre.lignes = {}
    for i = 1, VISIBLES do cadre.lignes[i] = creerLigne(i) end
    cadre.vide = C.texte(cadre, "texte", "texteDoux")
    cadre.vide:SetPoint("TOP", 0, -60)
    cadre.vide:SetText(L["Aucun objet de quête inutile dans tes sacs."])

    cadre:EnableMouseWheel(true)
    cadre:SetScript("OnMouseWheel", function(_, delta)
        decalage = math.max(0, math.min(#liste - VISIBLES, decalage - delta))
        dessiner()
    end)

    cadre.source = C.texte(cadre, "petit", "textePale")
    cadre.source:SetPoint("BOTTOMLEFT", 14, 72)
    cadre.plus = C.texte(cadre, "petit", "accent")
    cadre.plus:SetPoint("BOTTOMRIGHT", -14, 72)

    -- Case « objets incertains » : décochée à chaque ouverture.
    local inc = CreateFrame("Button", nil, cadre)
    inc:SetSize(LARGEUR - 28, 20)
    inc:SetPoint("BOTTOMLEFT", 12, 44)
    inc.boite = inc:CreateTexture(nil, "ARTWORK")
    inc.boite:SetSize(14, 14)
    inc.boite:SetPoint("LEFT", 2, 0)
    inc.texte = C.texte(inc, "petit", "orange")
    inc.texte:SetPoint("LEFT", inc.boite, "RIGHT", 8, 0)
    inc:SetScript("OnClick", function()
        voirIncertains = not voirIncertains
        filtrer()
        dessiner()
    end)
    C.infobulle(inc, L["Objets incertains"], L["Rien ne prouve qu'ils ne servent plus : accès de raid ou de donjon, suite d'une chaîne, objet que Questie ne connaît pas. Ils ne sont jamais cochés pour toi : vérifie chacun avant de le jeter."])
    cadre.incertains = inc

    cadre.jeter = C.bouton(cadre, L["Jeter la sélection (%d)"]:format(0), "rouge", function()
        if enExemple then return end
        local selection = {}
        for _, e in ipairs(liste) do if coches[e] then selection[#selection + 1] = e end end
        if #selection == 0 then return end
        -- Un objet par clic (règle du jeu).
        local jete = Menage.jeter(selection)
        if jete then
            coches[jete] = false
            dessiner()
            local o = jete.objet
            C.aideJeter(function() return ns.Jeu.lienSac(o.sac, o.case) ~= o.lien end,
                function() ns.Jeu.message(L["Jeté : %s."]:format(o.lien .. (o.nombre > 1 and (" x" .. o.nombre) or ""))) end)
        end
        -- Les sacs changent dans la foulée : on relit un peu après.
        ns.Jeu.plusTard(0.5, function() if cadre:IsShown() then Menage.ouvrir() end end)
    end, 200)
    cadre.jeter:SetPoint("BOTTOMRIGHT", -12, 12)
    cadre.jeter.texte:SetTextColor(T().rgb("rouge"))
    C.infobulle(cadre.jeter, L["Jeter"], L["Un clic met un objet coché dans ta main : clique ensuite dans le vide puis sur Oui, le jeu le détruit. Un objet à la fois (seule façon permise par le jeu)."])
    local tout = C.bouton(cadre, L["Tout cocher"], "texteDoux", function()
        for _, e in ipairs(liste) do coches[e] = true end
        dessiner()
    end, 110)
    tout:SetPoint("BOTTOMLEFT", 12, 12)
    local rien = C.bouton(cadre, L["Tout décocher"], "texteDoux", function()
        coches = {}
        dessiner()
    end, 110)
    rien:SetPoint("LEFT", tout, "RIGHT", 6, 0)

    cadre:Hide()
    if ns.Deplacement then
        ns.Deplacement.inscrire(cadre, L["Ménage des objets de quête"], "menage", { "CENTER", 0, 40 }, true)
    end
    if UISpecialFrames then table.insert(UISpecialFrames, "SuperGuideMenage") end   -- Échap la ferme
    -- Index des quêtes de Questie, construit doucement après la connexion.
    ns.Jeu.plusTard(20, function() pcall(ns.Jeu.lancerIndexQuestie) end)
end

-- Une quête rendue : un peu après (sacs et journal à jour), on signale.
local f = CreateFrame("Frame")
f:RegisterEvent("QUEST_TURNED_IN")
f:RegisterEvent("PLAYER_REGEN_DISABLED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:SetScript("OnEvent", function(_, e)
    if e == "QUEST_TURNED_IN" then
        ns.Jeu.plusTard(2, function() pcall(Menage.verifier) end)
    elseif e == "PLAYER_REGEN_DISABLED" then
        if cadre and cadre:IsShown() then cadre:Hide(); rouvrir = true end
    elseif e == "PLAYER_REGEN_ENABLED" then
        if rouvrir then rouvrir = false; Menage.ouvrir() end
        if Menage.enAttente then ns.Jeu.plusTard(1, function() pcall(Menage.verifier) end) end
    end
end)
