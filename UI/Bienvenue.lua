-- Bienvenue : au premier lancement, une fenêtre en quatre étapes courtes
-- pour être à l'aise tout de suite.
--   1. le logo animé, le nom, un merci ;
--   2. la touche de pêche (le seul vrai réglage à faire) ;
--   3. les modules phares, à cocher (tout est déjà réglé pour toi) ;
--   4. c'est prêt : où retrouver le menu.
-- Une seule fois par compte (SuperGuideDB.bienvenueVue) ; /sg bienvenue la
-- rouvre. Jamais en combat : elle se ferme et revient après.
-- Méthode de travail : un nouveau module phare a sa ligne dans PHARES.

local ADDON, ns = ...

local Bienvenue = {}
ns.Bienvenue = Bienvenue

local L = ns.L or setmetatable({}, { __index = function(_, k) return k end })

local LARGEUR, HAUTEUR = 520, 470
local ENTETE = 58   -- bandeau de la marque, sur toutes les étapes
local cadre, etape, pages, points, tournerLogo
local enAttente = false   -- à rouvrir après le combat

-- Modules phares : réglage, nom, ce qu'il fait en une ligne.
local PHARES = {
    { "pecheActif", "Auto Fishing", L["Une touche pour pêcher : canne, appât, lancer, ferrer."] },
    { "proposerEquipement", "Auto Equip", L["Propose tes améliorations d'équipement en un clic."] },
    { "tenuesActif", "Auto Sets", L["Tenues qui se mettent seules : monture, récolte, métiers."] },
    { "butinRapide", "Auto Loot", L["Ramassage instantané, avec la liste du butin."] },
    { "marchandActif", "Auto Sell & Repair", L["Vend tes gris et répare chez chaque marchand."] },
    { "butinPoubelle", L["Poubelle (sacs pleins)"], L["Sacs pleins : propose quoi jeter, au plus juste."] },
    { "barreXP", L["Barre d'XP"], L["Ton XP avec celle de tes quêtes finies et en cours."] },
}

local function T() return ns.Theme end
local function C() return ns.Controles end

local function enCombat()
    return InCombatLockdown() or (UnitAffectingCombat and UnitAffectingCombat("player"))
end

local function police(f, nom, taille)
    f:SetFont(T().MEDIA .. "Polices\\" .. nom, taille, "")
end

local function montrerEtape(n)
    etape = n
    for i, p in ipairs(pages) do p:SetShown(i == n) end
    for i, pt in ipairs(points) do
        pt:SetVertexColor(T().rgb(i == n and "accent" or "bordFort"))
        pt:SetSize(i == n and 10 or 7, i == n and 10 or 7)
    end
    if pages[n].maj then pages[n].maj() end   -- page 1 : l'intro se rejoue
end

local function terminer()
    SuperGuideDB = SuperGuideDB or {}
    SuperGuideDB.bienvenueVue = true
    enAttente = false
    if cadre then cadre:Hide() end
end

-- Une page vide, avec un titre et un texte d'introduction ; rend la page
-- et le y sous l'introduction.
local function nouvellePage(titre, intro)
    local p = CreateFrame("Frame", nil, cadre)
    p:SetPoint("TOPLEFT", 28, -(ENTETE + 14))   -- sous le bandeau de la marque
    p:SetPoint("BOTTOMRIGHT", -28, 84)
    p:Hide()
    if not titre then return p, 0 end
    local t = C().texte(p, "grand", "texte")
    t:SetPoint("TOPLEFT")
    t:SetText(titre)
    local d = C().texte(p, "texte", "texteDoux")
    d:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -8)
    d:SetWidth(LARGEUR - 56)
    d:SetSpacing(3)
    d:SetText(intro)
    return p, -(34 + (d:GetStringHeight() or 20) + 14)
end

local function boutonSuivant(texte, action)
    local b = C().bouton(cadre, texte, "accent", action, 150)
    b.texte:SetTextColor(T().rgb("accent"))
    return b
end

local function creer()
    local Th = T()
    cadre = CreateFrame("Frame", "SuperGuideBienvenue", UIParent)
    cadre:SetSize(LARGEUR, HAUTEUR)
    cadre:SetPoint("CENTER", 0, 40)
    cadre:SetFrameStrata("DIALOG")
    cadre:SetClampedToScreen(true)
    cadre:EnableMouse(true)
    cadre:SetMovable(true)
    cadre:RegisterForDrag("LeftButton")
    cadre:SetScript("OnDragStart", cadre.StartMoving)
    cadre:SetScript("OnDragStop", cadre.StopMovingOrSizing)
    Th.fond(cadre, "panneau", 0.98, "bordFort")
    if UISpecialFrames then table.insert(UISpecialFrames, "SuperGuideBienvenue") end
    -- Fermée par Échap ou la croix : vue quand même (on ne harcèle pas).
    cadre:SetScript("OnHide", function()
        if not enAttente then
            SuperGuideDB = SuperGuideDB or {}
            SuperGuideDB.bienvenueVue = true
        end
    end)
    pages, points = {}, {}

    -- 1. Bienvenue : logo animé, nom, merci.
    local p1 = nouvellePage()
    local logo = p1:CreateTexture(nil, "ARTWORK")
    logo:SetTexture(Th.icone("boussole"))
    logo:SetSize(72, 72)
    logo:SetPoint("TOP", 0, -6)
    logo:SetVertexColor(Th.rgb("accent"))
    tournerLogo = C().animerLogo(logo, logo:GetParent(), 190, nil, 7)
    local nom = p1:CreateFontString(nil, "OVERLAY")
    police(nom, "Archivo-BoldCondensed.ttf", 40)
    nom:SetTextColor(Th.rgb("texte"))
    nom:SetPoint("TOP", logo, "BOTTOM", 0, -26)
    nom:SetText(L["Bienvenue !"])
    local sous = p1:CreateFontString(nil, "OVERLAY")
    police(sous, "Archivo-Medium.ttf", 16)
    sous:SetTextColor(Th.rgb("accent"))
    sous:SetPoint("TOP", nom, "BOTTOM", 0, -6)
    sous:SetText(L["Merci d'avoir installé SuperRsk !"])
    local merci = C().texte(p1, "texte", "texte")
    merci:SetPoint("TOP", sous, "BOTTOM", 0, -26)
    merci:SetWidth(LARGEUR - 80)
    merci:SetJustifyH("CENTER")
    merci:SetSpacing(4)
    merci:SetText("|cff9aa3b2" .. L["Deux réglages rapides et tu es prêt (30 secondes) :"] .. "|r")
    -- Ce qu'il reste à faire, visible d'un coup d'œil.
    local afaire = C().texte(p1, "texte", "texte")
    afaire:SetPoint("TOP", merci, "BOTTOM", 0, -14)
    afaire:SetJustifyH("LEFT")
    afaire:SetSpacing(6)
    local ac = "|cff" .. Th.hex.accent
    afaire:SetText(ac .. "1|r  " .. L["Choisis ta touche de pêche"] .. "\n"
        .. ac .. "2|r  " .. L["Garde ou coupe tes modules"])

    -- Intro : la boussole arrive en quatre morceaux qui se remboîtent d'un
    -- coup sec, la boussole fait son tour avec un éclat de lumière, puis
    -- le nom et le reste apparaissent l'un après l'autre.
    local QUARTS = {
        { 0, 0.5, 0, 0.5, -1, 1 }, { 0.5, 1, 0, 0.5, 1, 1 },
        { 0, 0.5, 0.5, 1, -1, -1 }, { 0.5, 1, 0.5, 1, 1, -1 },
    }
    local morceaux = {}
    for i, q in ipairs(QUARTS) do
        local m = p1:CreateTexture(nil, "ARTWORK")
        m:SetTexture(Th.icone("boussole"))
        m:SetTexCoord(q[1], q[2], q[3], q[4])
        m:SetSize(36, 36)
        m:SetVertexColor(Th.rgb("accent"))
        m:Hide()
        m.dx, m.dy = q[5], q[6]
        morceaux[i] = m
    end
    local apparitions = { { nom, 0.70, -26 }, { sous, 0.85, -6 }, { merci, 1.00, -20 }, { afaire, 1.15, -14 } }
    local ancres = { logo, nom, sous, merci }

    -- Rebond en fin de course (le morceau dépasse un peu, puis s'emboîte).
    local function rebond(x)
        local c1 = 1.70158
        local c3 = c1 + 1
        return 1 + c3 * (x - 1) ^ 3 + c1 * (x - 1) ^ 2
    end
    local function douce(x) return 1 - (1 - x) ^ 3 end
    local EMBOITE, FIN = 0.55, 1.6
    local debut, emboite
    p1:SetScript("OnUpdate", function(self)
        if not debut then return end
        local t = GetTime() - debut
        -- Les quatre morceaux convergent.
        if t < EMBOITE then
            local e = rebond(t / EMBOITE)
            local loin = 70 * (1 - e)
            for _, m in ipairs(morceaux) do
                m:ClearAllPoints()
                m:SetPoint("CENTER", logo, "CENTER", m.dx * (18 + loin), m.dy * (18 + loin))
                m:SetAlpha(math.min(1, t / EMBOITE * 2))
            end
        elseif not emboite then
            -- Clac : la vraie boussole prend la place et tourne.
            emboite = true
            for _, m in ipairs(morceaux) do m:Hide() end
            logo:Show()
            if tournerLogo then tournerLogo() end
        end
        -- Le texte monte en apparaissant, ligne après ligne.
        for i, a in ipairs(apparitions) do
            local x = math.max(0, math.min(1, (t - a[2]) / 0.35))
            local e = douce(x)
            a[1]:SetAlpha(e)
            a[1]:ClearAllPoints()
            a[1]:SetPoint("TOP", ancres[i], "BOTTOM", 0, a[3] - 14 * (1 - e))
        end
        if t > FIN then
            debut = nil
        end
    end)
    p1.maj = function()
        debut, emboite = GetTime(), false
        logo:Hide()
        for _, m in ipairs(morceaux) do m:SetAlpha(0); m:Show() end
        for _, a in ipairs(apparitions) do a[1]:SetAlpha(0) end
    end
    pages[1] = p1

    -- 2. Les modules phares.
    local p2, y = nouvellePage(L["2. Tes modules"],
        L["Les plus utiles sont déjà allumés. Décoche ce que tu ne veux pas : tout se change ensuite dans /sg."])
    local cases = {}
    for _, ph in ipairs(PHARES) do
        local o = ns.Reglages.option(ph[1]) or { cle = ph[1], type = "case" }
        -- Case et nom à gauche, la phrase entière à droite (sur deux lignes
        -- s'il le faut, jamais coupée).
        local c = C().case(p2, { cle = o.cle, type = "case", inverse = o.inverse, libelle = ph[2], info = ph[3] }, 176)
        c:SetPoint("TOPLEFT", 0, y)
        local d = C().texte(p2, "petit", "texteDoux")
        d:SetPoint("LEFT", c, "LEFT", 184, 0)
        d:SetPoint("RIGHT", p2, "RIGHT")
        d:SetWordWrap(true)
        d:SetSpacing(2)
        d:SetText(ph[3])
        cases[#cases + 1] = c
        y = y - 33   -- 7 modules dans la page, au-dessus des points d'étape
    end
    p2.maj = function() for _, c in ipairs(cases) do c.maj() end end
    pages[3] = p2

    -- 3. La touche de pêche.
    local p3, y3 = nouvellePage(L["1. Ta touche de pêche"],
        L["Une seule touche pour tout : elle sort ta canne et ta tenue de pêche, pose l'appât, lance la ligne et ferre le poisson. Ton équipement revient tout seul à cheval ou si on t'attaque."])
    local o = ns.Reglages.option("pecheTouche")
    local touche = o and C().pour(p3, o, LARGEUR - 56)
    if touche then touche:SetPoint("TOPLEFT", 0, y3) end
    local astuce = C().texte(p3, "petit", "textePale")
    astuce:SetPoint("TOPLEFT", 0, y3 - 66)
    astuce:SetWidth(LARGEUR - 56)
    astuce:SetText(L["Astuce : une touche libre près de ta main, comme ², une touche de la souris ou la molette. Avec Espace, la canne doit déjà être en main."])
    -- État de la touche : à faire (orange) tant que c'est Espace par défaut.
    local etat = C().texte(p3, "texte", "orange")
    etat:SetPoint("TOPLEFT", 0, y3 - 100)
    etat:SetWidth(LARGEUR - 56)
    p3.maj = function()
        if touche and touche.maj then touche.maj() end
        local t = ns.Reglages.get("pecheTouche")
        if type(t) == "string" and t ~= "" and t ~= "SPACE" then
            etat:SetTextColor(T().rgb("vert"))
            etat:SetText(L["C'est fait : %s pêche pour toi."]:format(C().nomTouche(t)))
        else
            etat:SetTextColor(T().rgb("orange"))
            etat:SetText(L["À faire : clique sur le bouton ci-dessus, puis appuie sur ta touche."])
        end
    end
    ns.Reglages.ecouter(function(cle)
        if cle == "pecheTouche" and cadre and cadre:IsShown() then p3.maj() end
    end)
    pages[2] = p3

    -- 4. C'est prêt.
    local p4, y4 = nouvellePage(L["C'est prêt !"],
        L["SuperRsk tourne déjà. Voici où tout retrouver :"])
    local a = "|cff" .. Th.hex.accent
    local lignes = C().texte(p4, "texte", "texte")
    lignes:SetPoint("TOPLEFT", 0, y4)
    lignes:SetWidth(LARGEUR - 56)
    lignes:SetSpacing(8)
    lignes:SetText(table.concat({
        a .. "/sg|r   " .. L["le menu : chaque module, allumé ou coupé, et ses réglages"],
        a .. L["Boussole"] .. "|r   " .. L["le bouton de la minicarte ouvre le même menu"],
        a .. L["Déplacer"] .. "|r   " .. L["place barres et fenêtres où tu veux (en haut du menu)"],
        a .. "/sg bienvenue|r   " .. L["revoir cette fenêtre"],
    }, "\n"))
    local fin = C().texte(p4, "texte", "accent")
    fin:SetPoint("TOPLEFT", lignes, "BOTTOMLEFT", 0, -24)
    fin:SetText(L["Merci encore, et bon jeu !"])
    pages[4] = p4

    -- Bas : points d'étape, Passer, Retour, Suivant.
    for i = 1, #pages do
        local pt = cadre:CreateTexture(nil, "ARTWORK")
        pt:SetTexture(Th.MEDIA .. "RondPlein")
        pt:SetPoint("BOTTOM", (i - (#pages + 1) / 2) * 18, 62)
        points[i] = pt
    end
    local passer = C().bouton(cadre, L["Passer"], "texteDoux", terminer, 90)
    passer:SetPoint("BOTTOMLEFT", 20, 20)
    local retour = C().bouton(cadre, L["‹ Retour"], "texteDoux", function() montrerEtape(math.max(1, etape - 1)) end, 90)
    local suivant = boutonSuivant(L["C'est parti ›"], function()
        if etape < #pages then montrerEtape(etape + 1) else terminer() end
    end)
    suivant:SetPoint("BOTTOMRIGHT", -20, 20)
    retour:SetPoint("RIGHT", suivant, "LEFT", -8, 0)
    local ouvrirMenu = C().bouton(cadre, L["Ouvrir le menu"], "texte", function()
        terminer()
        if ns.Menu then ns.Menu.ouvrir("accueil") end
    end, 130)
    ouvrirMenu:SetPoint("RIGHT", suivant, "LEFT", -8, 0)

    local maj = montrerEtape
    montrerEtape = function(n)
        maj(n)
        retour:SetShown(n > 1 and n < #pages)
        passer:SetShown(n < #pages)
        ouvrirMenu:SetShown(n == #pages)
        suivant.texte:SetText(n == 1 and L["C'est parti ›"] or n == #pages and L["Terminer"] or L["Suivant ›"])
    end

    -- Bandeau de la marque, sur toutes les étapes : le logo vivant et le nom.
    local bandeau = CreateFrame("Frame", nil, cadre)
    bandeau:SetPoint("TOPLEFT")
    bandeau:SetPoint("TOPRIGHT")
    bandeau:SetHeight(ENTETE)
    local b = C().marque(bandeau, bandeau, 6)
    b.logo:SetPoint("LEFT", 26, 0)
    local trait = bandeau:CreateTexture(nil, "ARTWORK")
    trait:SetColorTexture(Th.rgb("bordFort"))
    trait:SetHeight(1)
    trait:SetPoint("BOTTOMLEFT", 20, 0)
    trait:SetPoint("BOTTOMRIGHT", -20, 0)

    local fermer = CreateFrame("Button", nil, cadre)
    fermer:SetSize(22, 22)
    fermer:SetPoint("TOPRIGHT", -10, -10)
    local x = fermer:CreateTexture(nil, "ARTWORK")
    x:SetTexture(Th.icone("fermer"))
    x:SetSize(12, 12)
    x:SetPoint("CENTER")
    x:SetVertexColor(Th.rgb("texteDoux"))
    -- Au-dessus du bandeau (qui capte le survol pour faire tourner le logo).
    fermer:SetFrameLevel(bandeau:GetFrameLevel() + 10)
    fermer:RegisterForClicks("LeftButtonUp")
    fermer:SetScript("OnClick", terminer)
    fermer:SetScript("OnEnter", function() x:SetVertexColor(Th.rgb("rouge")) end)
    fermer:SetScript("OnLeave", function() x:SetVertexColor(Th.rgb("texteDoux")) end)
    cadre:Hide()
end

function Bienvenue.ouvrir()
    if enCombat() then
        enAttente = true
        return
    end
    if not cadre then creer() end
    if ns.Menu and ns.Menu.ouvert and ns.Menu.ouvert() then ns.Menu.fermer() end
    enAttente = false
    cadre:Show()
    montrerEtape(1)
end

-- Premier lancement : quelques secondes après l'arrivée en jeu.
function Bienvenue.demarrer()
    if type(SuperGuideDB) == "table" and SuperGuideDB.bienvenueVue then return end
    ns.Jeu.plusTard(4, Bienvenue.ouvrir)
end

-- Combat : on ferme, et on revient après si ce n'était pas fini.
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_REGEN_DISABLED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:SetScript("OnEvent", function(_, e)
    if e == "PLAYER_REGEN_DISABLED" then
        if cadre and cadre:IsShown() then
            enAttente = true
            cadre:Hide()
        end
    elseif enAttente then
        Bienvenue.ouvrir()
    end
end)
