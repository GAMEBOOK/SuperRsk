-- Barre d'XP à part : XP actuelle, quêtes à rendre, quêtes en cours et repos
-- en segments, temps à ce niveau, temps de session et rythme. Calculs dans
-- Core/BarreXP.lua ; ici le cadre et les événements.

local ADDON, ns = ...

local BarreXP = ns.BarreXP
local L = ns.L or setmetatable({}, { __index = function(_, k) return k end })

local BLANC = "Interface\\Buttons\\WHITE8x8"
local H_BARRE = 22

-- session : { debut, gagne } (SuperGuideCharDB.sessionXP) ; dernier : dernier
-- relevé { niveau, xp, max } ; temps : { secondes, recu } ou nil.
BarreXP.etat = {}
local etat = BarreXP.etat

local cadre, barre, remplissage, segs, txt = nil, nil, nil, {}, {}
local contour
local etincelle
local blizzardEnAttente = false

local function R(cle) return ns.Reglages.get(cle) end

local function releve()
    return { niveau = ns.Jeu.niveau(), xp = ns.Jeu.xp(), max = ns.Jeu.xpMax() }
end

-- Ajoute à la session l'XP gagnée depuis le dernier relevé.
local function compter()
    local actuel = releve()
    if not etat.dernier then etat.dernier = actuel; return end
    local g = BarreXP.gain(etat.dernier, actuel)
    if g then
        if etat.session then etat.session.gagne = etat.session.gagne + g end
        etat.dernier = actuel
    end
end

local function nouvelleSession()
    etat.session = BarreXP.nouvelleSession(time())
    SuperGuideCharDB.sessionXP = etat.session
    etat.dernier = releve()
end

-- Couleur d'un élément : celle choisie dans les réglages, sinon le thème.
local function teinte(cle, theme)
    local c = R(cle)
    if c then return c[1], c[2], c[3] end
    return ns.Theme.rgb(theme)
end

local function couleur(cle, theme, texte)
    local r, g, b = teinte(cle, theme)
    return ("|cff%02x%02x%02x"):format(r * 255, g * 255, b * 255) .. texte .. "|r"
end

local function degrade(tex)
    local T = ns.Theme
    -- Violet à gauche, accent (clair) au bout de la progression.
    local r1, g1, b1 = T.rgb("violet")
    local r2, g2, b2 = T.rgb("accent")
    if R("xpCouleurXP") then r1, g1, b1, r2, g2, b2 = BarreXP.degradeDe(teinte("xpCouleurXP", "accent")) end
    if tex.SetGradient and CreateColor then
        tex:SetGradient("HORIZONTAL", CreateColor(r1, g1, b1, 1), CreateColor(r2, g2, b2, 1))
    elseif tex.SetGradientAlpha then
        tex:SetGradientAlpha("HORIZONTAL", r1, g1, b1, 1, r2, g2, b2, 1)
    end
end

-- Textures de barre : les nôtres (Media/Barres), puis celles que les autres
-- addons ont enregistrées dans LibSharedMedia s'il est chargé.
local INTEGREES = {
    { valeur = "lisse", nom = "Lisse (SuperRsk)", chemin = BLANC },
    { valeur = "d1", nom = "d1", chemin = "Interface\\AddOns\\" .. ADDON .. "\\Media\\Barres\\d1.tga" },
}

local function lsm()
    local m = LibStub and LibStub("LibSharedMedia-3.0", true)
    if m and m.List and m.Fetch then return m end
end

local function integree(nom)
    for _, e in ipairs(INTEGREES) do if e.valeur == nom then return e end end
end

function BarreXP.textures()
    local l = {}
    for _, e in ipairs(INTEGREES) do l[#l + 1] = { valeur = e.valeur, nom = L[e.nom], chemin = e.chemin } end
    local m = lsm()
    if m then
        for _, nom in ipairs(m:List("statusbar") or {}) do
            local c = not integree(nom) and m:Fetch("statusbar", nom, true)
            if c then l[#l + 1] = { valeur = nom, nom = nom, chemin = c } end
        end
    end
    return l
end

-- Chemin de la texture choisie ; une texture disparue redevient « Lisse ».
function BarreXP.chemin(nom)
    local e = integree(nom)
    if e then return e.chemin end
    local m = lsm()
    return m and m:Fetch("statusbar", nom, true) or BLANC
end

function BarreXP.couleurContour(nom)
    local T = ns.Theme
    if nom == "noir" then return 0, 0, 0 end
    if nom == "gris" then return T.rgb("textePale") end
    if nom == "classe" then
        local _, classe = UnitClass("player")
        local c = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS or {})[classe]
        if c then return c.r, c.g, c.b end
    end
    return T.rgb("accent")
end

-- Texture de la barre et des segments, contour.
local function habiller()
    local chemin = BarreXP.chemin(R("xpTexture"))
    remplissage:SetTexture(chemin)
    degrade(remplissage)
    for _, s in pairs(segs) do s:SetTexture(chemin) end
    segs.termine:SetVertexColor(teinte("xpCouleurQuetes", "orange"))
    segs.enCours:SetVertexColor(teinte("xpCouleurEnCours", "orange"))
    segs.repos:SetVertexColor(teinte("xpCouleurRepos", "repos"))
    local c = R("xpContour")
    if c == "aucun" then contour:Hide(); return end
    local r, g, b = BarreXP.couleurContour(c)
    for _, t in ipairs(contour.bords) do t:SetColorTexture(r, g, b, 1) end
    contour:Show()
end

local function contourTexte()
    local nom = R("xpContourTexte")
    local d = BarreXP.drapeauPolice(nom)
    for _, fs in pairs(txt) do
        local police, taille = fs:GetFont()
        if police and taille then fs:SetFont(police, taille, d) end
        fs:SetShadowColor(0, 0, 0, 1)
        fs:SetShadowOffset(BarreXP.ombrePolice(nom))
    end
end

local function masquerBlizzard(oui)
    blizzardEnAttente = ns.Jeu.barreJeuCachee(oui) == false
end

function BarreXP.creer()
    local T, C = ns.Theme, ns.Controles
    etat.session = SuperGuideCharDB.sessionXP

    cadre = CreateFrame("Frame", "SuperGuideBarreXP", UIParent)
    cadre:SetClampedToScreen(true)
    cadre:SetSize(R("barreXPLargeur"), H_BARRE)
    ns.Deplacement.inscrire(cadre, L["Barre d'XP"], "barreXP", { "BOTTOM", 0, 140 })

    barre = CreateFrame("Frame", nil, cadre)
    barre:SetHeight(H_BARRE)
    local fond = barre:CreateTexture(nil, "BACKGROUND")
    fond:SetAllPoints()
    fond:SetColorTexture(T.rgb("panneau"))
    fond:SetAlpha(0.9)

    remplissage = barre:CreateTexture(nil, "BORDER")
    remplissage:SetTexture(BLANC)
    remplissage:SetPoint("TOPLEFT")
    remplissage:SetPoint("BOTTOMLEFT")
    degrade(remplissage)
    -- Étincelle : un trait clair à la tête de la progression.
    etincelle = barre:CreateTexture(nil, "ARTWORK", nil, 2)
    etincelle:SetColorTexture(1, 1, 1, 0.85)
    etincelle:SetWidth(2)
    etincelle:SetPoint("TOP", remplissage, "TOPRIGHT")
    etincelle:SetPoint("BOTTOM", remplissage, "BOTTOMRIGHT")

    local teintes = {
        termine = { "orange", 1 }, enCours = { "orange", 0.4 }, repos = { "repos", 0.85 },
    }
    for nom, t in pairs(teintes) do
        local s = barre:CreateTexture(nil, "BORDER")
        s:SetTexture(BLANC)
        s:SetVertexColor(T.rgb(t[1]))
        s:SetAlpha(t[2])
        segs[nom] = s
    end

    -- Contour d'un pixel autour de la barre. Pas de case à part pour les
    -- pourcentages : collée au bout, elle se lisait comme de l'XP manquante.
    contour = CreateFrame("Frame", "SuperGuideBarreXPContour", cadre)
    contour:SetPoint("TOPLEFT", barre, "TOPLEFT", -1, 1)
    contour:SetPoint("BOTTOMRIGHT", barre, "BOTTOMRIGHT", 1, -1)
    contour.bords = {}
    for i, p in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" },
                         { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local t = contour:CreateTexture(nil, "OVERLAY")
        t:SetPoint(p[1]); t:SetPoint(p[2])
        if i <= 2 then t:SetHeight(1) else t:SetWidth(1) end
        contour.bords[i] = t
    end

    txt.niveau = C.texte(barre, "texte", "texte")
    txt.niveau:SetPoint("LEFT", 6, 0)
    txt.centre = C.texte(barre, "texte", "texte")
    txt.centre:SetPoint("CENTER")
    txt.pct = C.texte(barre, "texte", "texte")
    txt.pct:SetPoint("RIGHT", -6, 0)
    txt.hautG = C.texte(cadre, "texte", "texte")
    txt.hautD = C.texte(cadre, "texte", "texte")
    txt.bas1 = C.texte(cadre, "texte", "texte")
    txt.bas2 = C.texte(cadre, "texte", "texte")
    for _, f in pairs(txt) do f:SetWordWrap(false) end

    if R("xpMasquerBlizzard") then masquerBlizzard(true) end
    habiller()
    contourTexte()
    BarreXP.maj()
end

local function cacher(o, oui) if oui then o:Hide() else o:Show() end end

-- Pose un segment à partir de la fraction « debut », sur « frac » de la barre.
local function poser(tex, debut, frac, largeur)
    if frac <= 0 then tex:Hide(); return end
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT", barre, "TOPLEFT", debut * largeur, 0)
    tex:SetPoint("BOTTOMLEFT", barre, "BOTTOMLEFT", debut * largeur, 0)
    tex:SetWidth(frac * largeur)
    tex:Show()
end

function BarreXP.visible()
    if not R("barreXP") then return false end
    return ns.Jeu.niveau() < ns.Jeu.niveauMax() or R("xpNiveauMax")
end

function BarreXP.maj()
    if not cadre then return end
    compter()
    if not BarreXP.visible() then cadre:Hide(); return end

    local fr = GetLocale() == "frFR"
    local sep = fr and " " or ","
    local niveau, xp, max = ns.Jeu.niveau(), ns.Jeu.xp(), ns.Jeu.xpMax()
    local auMax = niveau >= ns.Jeu.niveauMax()
    local quetes = not auMax and BarreXP.quetes(ns.Jeu.xpQuetes()) or nil
    local repos = auMax and 0 or ns.Jeu.xpRepos()
    local maintenant = time()

    -- Disposition : les lignes masquées ne laissent pas de trou.
    local vis = BarreXP.lignesVisibles(R("xpTextes"), auMax)
    local y, hauteur = BarreXP.disposition(vis)
    local largeur = R("barreXPLargeur")
    cadre:SetSize(largeur, hauteur)
    local lb = largeur
    barre:ClearAllPoints()
    barre:SetPoint("TOPLEFT", cadre, "TOPLEFT", 0, y.barre)
    barre:SetWidth(lb)

    -- Barre et segments.
    local termine = quetes and R("xpBarreQuetes") and quetes.termine or 0
    local enCours = quetes and R("xpBarreEnCours") and quetes.enCours or 0
    local s = auMax and { xp = 1, termine = 0, enCours = 0, repos = 0 }
        or BarreXP.segments(xp, max, termine, enCours, R("xpBarreRepos") and repos or 0)
    if s.xp > 0 then remplissage:SetWidth(s.xp * lb); remplissage:Show() else remplissage:Hide() end
    etincelle:SetShown(s.xp > 0 and s.xp < 1)
    poser(segs.termine, s.xp, s.termine, lb)
    poser(segs.enCours, s.xp + s.termine, s.enCours, lb)
    poser(segs.repos, s.xp + s.termine + s.enCours, s.repos, lb)

    -- Textes de la barre.
    txt.niveau:SetText(L["Niveau %d"]:format(niveau))
    if auMax then
        txt.centre:SetText(L["Niveau max"])
        txt.pct:SetText(BarreXP.pct(100, fr))
    else
        txt.centre:SetText(("%s / %s (%s)"):format(BarreXP.nombre(xp, sep), BarreXP.nombre(max, sep),
            BarreXP.nombre(max - xp, sep)))
        local p = BarreXP.pct(BarreXP.pourcent(xp, max), fr)
        local qt = quetes and quetes.termine or 0
        if qt > 0 then p = p .. " (" .. BarreXP.pct(BarreXP.pourcent(math.min(xp + qt, max), max), fr) .. ")" end
        txt.pct:SetText(p)
    end

    -- Ligne du haut : temps à ce niveau, temps de session.
    local function ligne(f, yy) f:ClearAllPoints(); f:SetPoint("TOPLEFT", cadre, "TOPLEFT", 4, yy) end
    cacher(txt.hautG, not vis.haut)
    cacher(txt.hautD, not vis.haut)
    if vis.haut then
        ligne(txt.hautG, y.haut)
        txt.hautD:ClearAllPoints()
        txt.hautD:SetPoint("TOPRIGHT", cadre, "TOPRIGHT", -4, y.haut)
        local tn = BarreXP.tempsNiveau(etat.temps, GetTime())
        txt.hautG:SetText(L["Temps à ce niveau : %s"]:format(tn and BarreXP.duree(tn) or "--"))
        local debut = etat.session and etat.session.debut or maintenant
        txt.hautD:SetText(L["Session : %s"]:format(BarreXP.duree(maintenant - debut)))
    end

    -- Ligne du bas : quêtes terminées et repos à gauche, rythme à droite.
    cacher(txt.bas1, not vis.bas1)
    if vis.bas1 then
        ligne(txt.bas1, y.bas)
        local r = L["Repos : %s"]:format(couleur("xpCouleurRepos", "repos", BarreXP.pct(BarreXP.pourcent(repos, max), fr)))
        if quetes then
            local q = L["Quêtes terminées : %s"]:format(couleur("xpCouleurQuetes", "orange", BarreXP.pct(BarreXP.pourcent(quetes.termine, max), fr)))
            txt.bas1:SetText(q .. "  -  " .. r)
        else
            txt.bas1:SetText(r)
        end
    end
    cacher(txt.bas2, not vis.bas2)
    if vis.bas2 then
        txt.bas2:ClearAllPoints()
        txt.bas2:SetPoint("TOPRIGHT", cadre, "TOPRIGHT", -4, y.bas)
        local parHeure, secondes = BarreXP.rythme(etat.session or BarreXP.nouvelleSession(maintenant), maintenant, max - xp)
        txt.bas2:SetText(L["Niveau suivant dans : %s (%s XP/h)"]:format(secondes and BarreXP.duree(secondes) or "--",
            BarreXP.nombre(parHeure, sep)))
    end

    cadre:Show()
end

-- Minuteur d'une seconde : les durées avancent, seulement si la barre se voit.
function BarreXP.tic()
    if cadre and cadre:IsShown() then BarreXP.maj() end
end

BarreXP.EVENEMENTS = {
    "PLAYER_XP_UPDATE", "UPDATE_EXHAUSTION", "PLAYER_LEVEL_UP", "QUEST_LOG_UPDATE",
    "TIME_PLAYED_MSG", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED",
}

-- État (session, temps joué) mis à jour tout de suite ; l'appelant demande
-- ensuite un BarreXP.maj() regroupé par image.
function BarreXP.surEvenement(e, ...)
    if e == "PLAYER_ENTERING_WORLD" then
        local connexion, rechargement = ...
        if connexion or (rechargement and R("xpResetReload")) or not etat.session then
            nouvelleSession()
        end
        if connexion or not etat.temps then ns.Jeu.demanderTempsJoue() end
    elseif e == "TIME_PLAYED_MSG" then
        local _, auNiveau = ...
        etat.temps = { secondes = auNiveau or 0, recu = GetTime() }
        ns.Jeu.tempsJoueRecu()
    elseif e == "PLAYER_LEVEL_UP" then
        etat.temps = { secondes = 0, recu = GetTime() }
    elseif e == "PLAYER_REGEN_ENABLED" then
        if blizzardEnAttente then masquerBlizzard(R("xpMasquerBlizzard")) end
    end
end

local CLES = {
    barreXP = true, barreXPLargeur = true, xpTextes = true, xpCouleurQuetes = true, xpCouleurRepos = true, xpBarreQuetes = true, xpBarreEnCours = true, xpBarreRepos = true,
    xpNiveauMax = true, xpResetReload = true, xpMasquerBlizzard = true,
}

function BarreXP.appliquer(cle, v)
    if not cadre then return end
    if cle == "xpMasquerBlizzard" then masquerBlizzard(v) end
    if cle == "xpTexture" or cle == "xpContour" or cle:find("^xpCouleur") then habiller() end
    if cle == "xpContourTexte" then contourTexte() end
    if cle == "positions" then
        ns.Deplacement.reinitialiser()
    end
    if CLES[cle] or cle == "positions" then BarreXP.maj() end
end
