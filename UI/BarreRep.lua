-- Barre de réputation à part, comme la barre d'XP : la faction suivie
-- (« Afficher en barre d'XP » dans la fenêtre Réputation), son rang, où tu
-- en es, ce que tu as gagné pendant la session et le temps jusqu'au rang
-- suivant. Calculs dans Core/BarreRep.lua ; mise en forme de la barre d'XP
-- (textures, contours, nombres) reprise de ns.BarreXP.

local ADDON, ns = ...

local BarreRep = ns.BarreRep
local L = ns.L or setmetatable({}, { __index = function(_, k) return k end })

local BLANC = "Interface\\Buttons\\WHITE8x8"
local H_BARRE = 22

-- session : { debut, gagne, id } ; dernier : dernier relevé de la faction.
BarreRep.etat = {}
local etat = BarreRep.etat

-- cadre : la vraie barre ; copie : la même, montrée dans la bannière
-- d'aperçu du menu (construite à la demande).
local cadre, copie
local blizzardEnAttente = false
local apercu = false

local function R(cle) return ns.Reglages.get(cle) end
local function X() return ns.BarreXP end

local function nouvelleSession(f)
    etat.session = X().nouvelleSession(time())
    etat.session.id = f and (f.id or f.nom)
    SuperGuideCharDB.sessionRep = etat.session
end

-- Ajoute à la session ce qui a été gagné depuis le dernier relevé ; une autre
-- faction suivie repart d'une session neuve.
local function compter(f)
    if not f then return end
    local cle = f.id or f.nom
    if not etat.session or etat.session.id ~= cle then
        nouvelleSession(f)
        etat.dernier = f
        return
    end
    local g = BarreRep.gain(etat.dernier, f)
    if g then etat.session.gagne = etat.session.gagne + g end
    etat.dernier = f
end

local function masquerBlizzard()
    local oui = R("barreRep") == true and R("repMasquerBlizzard") ~= false
    blizzardEnAttente = ns.Jeu.barreJeuCachee(oui, "rep") == false
end

local function habiller(w)
    local contour = w.contour
    w.remplissage:SetTexture(X().chemin(R("repTexture")))
    local c = R("repContour")
    if c == "aucun" then contour:Hide(); return end
    local r, g, b = X().couleurContour(c)
    for _, t in ipairs(contour.bords) do t:SetColorTexture(r, g, b, 1) end
    contour:Show()
end

local function contourTexte(w)
    local nom = R("repContourTexte")
    local d = X().drapeauPolice(nom)
    for _, fs in pairs(w.txt) do
        local police, taille = fs:GetFont()
        if police and taille then fs:SetFont(police, taille, d) end
        fs:SetShadowColor(0, 0, 0, 1)
        fs:SetShadowOffset(X().ombrePolice(nom))
    end
end

local function teinter(w, f)
    local remplissage = w.remplissage
    local r, g, b = BarreRep.couleur(f, FACTION_BAR_COLORS)
    local r1, g1, b1, r2, g2, b2 = X().degradeDe(r, g, b)
    if remplissage.SetGradient and CreateColor then
        remplissage:SetGradient("HORIZONTAL", CreateColor(r1, g1, b1, 1), CreateColor(r2, g2, b2, 1))
    elseif remplissage.SetGradientAlpha then
        remplissage:SetGradientAlpha("HORIZONTAL", r1, g1, b1, 1, r2, g2, b2, 1)
    else
        remplissage:SetVertexColor(r, g, b)
    end
end

-- Fabrique une barre (la vraie avec son nom, la copie de l'aperçu sans nom).
local function construire(nom)
    local T, C = ns.Theme, ns.Controles
    local w = CreateFrame("Frame", nom, UIParent)
    w.txt = {}
    w:SetClampedToScreen(true)
    w:SetSize(R("barreRepLargeur"), H_BARRE)

    local barre = CreateFrame("Frame", nil, w)
    w.barre = barre
    barre:SetHeight(H_BARRE)
    local fond = barre:CreateTexture(nil, "BACKGROUND")
    fond:SetAllPoints()
    fond:SetColorTexture(T.rgb("panneau"))
    fond:SetAlpha(0.9)

    local remplissage = barre:CreateTexture(nil, "BORDER")
    w.remplissage = remplissage
    remplissage:SetTexture(BLANC)
    remplissage:SetPoint("TOPLEFT")
    remplissage:SetPoint("BOTTOMLEFT")
    local etincelle = barre:CreateTexture(nil, "ARTWORK", nil, 2)
    w.etincelle = etincelle
    etincelle:SetColorTexture(1, 1, 1, 0.85)
    etincelle:SetWidth(2)
    etincelle:SetPoint("TOP", remplissage, "TOPRIGHT")
    etincelle:SetPoint("BOTTOM", remplissage, "BOTTOMRIGHT")

    local contour = CreateFrame("Frame", nom and (nom .. "Contour") or nil, w)
    w.contour = contour
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

    local txt = w.txt
    txt.nom = C.texte(barre, "texte", "texte")
    txt.nom:SetPoint("LEFT", 6, 0)
    txt.centre = C.texte(barre, "texte", "texte")
    txt.centre:SetPoint("CENTER")
    txt.rang = C.texte(barre, "texte", "texte")
    txt.rang:SetPoint("RIGHT", -6, 0)
    txt.bas1 = C.texte(w, "texte", "texte")
    txt.bas2 = C.texte(w, "texte", "texte")
    for _, f in pairs(txt) do f:SetWordWrap(false) end

    habiller(w)
    contourTexte(w)
    w:Hide()
    return w
end

function BarreRep.creer()
    etat.session = SuperGuideCharDB.sessionRep
    cadre = construire("SuperGuideBarreRep")
    ns.Deplacement.inscrire(cadre, L["Barre de réputation"], "barreRep", { "TOP", 0, -100 })
    masquerBlizzard()
    BarreRep.maj()
end

-- Copie montrée dans la bannière d'aperçu du menu (la vraie reste en place).
function BarreRep.vitrine()
    if not copie then copie = construire(nil) end
    BarreRep.maj()
    return copie, "barreRep", true
end

function BarreRep.apercu(oui)
    apercu = oui and true or false
    BarreRep.maj()
end

local function montrer(o, oui) if oui then o:Show() else o:Hide() end end

-- Met le cadre w en forme pour la faction f (nil : la marche à suivre).
local function rendre(w, f)
    local barre, remplissage, txt = w.barre, w.remplissage, w.txt
    local fr = GetLocale() == "frFR"
    local sep = fr and " " or ","
    local largeur = R("barreRepLargeur")
    local fait, total, auMax = 0, 1, true
    if f then fait, total, auMax = BarreRep.progression(f) end

    local vis = BarreRep.lignesVisibles(R("repTextes"), auMax or not f)
    local y, hauteur = X().disposition(vis)
    w:SetSize(largeur, hauteur)
    barre:ClearAllPoints()
    barre:SetPoint("TOPLEFT", w, "TOPLEFT", 0, y.barre)
    barre:SetWidth(largeur)

    if not f then
        -- Aperçu sans faction suivie : la marche à suivre.
        remplissage:Hide()
        w.etincelle:Hide()
        txt.nom:SetText("")
        txt.rang:SetText("")
        txt.centre:SetText(L["Aucune faction suivie : Réputation > « Afficher en barre d'XP »"])
    else
        teinter(w, f)
        local frac = fait / total
        if frac > 0 then remplissage:SetWidth(frac * largeur); remplissage:Show() else remplissage:Hide() end
        w.etincelle:SetShown(frac > 0 and frac < 1)
        txt.nom:SetText(f.nom)
        local rang = f.parangon and L["Parangon"] or f.rang
        if auMax then
            txt.centre:SetText("")
            txt.rang:SetText(rang)
        else
            txt.centre:SetText(("%s / %s (%s)"):format(X().nombre(fait, sep), X().nombre(total, sep),
                X().nombre(total - fait, sep)))
            txt.rang:SetText(rang .. "  " .. X().pct(X().pourcent(fait, total), fr))
        end
    end

    montrer(txt.bas1, vis.bas1)
    montrer(txt.bas2, vis.bas2)
    local maintenant = time()
    local session = etat.session or X().nouvelleSession(maintenant)
    if vis.bas1 then
        txt.bas1:ClearAllPoints()
        txt.bas1:SetPoint("TOPLEFT", w, "TOPLEFT", 4, y.bas)
        txt.bas1:SetText(L["Session : +%s (%s)"]:format(X().nombre(session.gagne or 0, sep),
            X().duree(maintenant - (session.debut or maintenant))))
    end
    if vis.bas2 then
        txt.bas2:ClearAllPoints()
        txt.bas2:SetPoint("TOPRIGHT", w, "TOPRIGHT", -4, y.bas)
        local parHeure, secondes = X().rythme(session, maintenant, total - fait)
        txt.bas2:SetText(L["Rang suivant dans : %s (%s rép/h)"]:format(secondes and X().duree(secondes) or "--",
            X().nombre(parHeure, sep)))
    end
    w:Show()
end

-- La vraie barre (module allumé et faction suivie) et la copie de l'aperçu,
-- pâlie quand le module est coupé ou sans faction suivie.
function BarreRep.maj()
    if not cadre then return end
    local f = ns.Jeu.factionSuivie()
    compter(f)
    if R("barreRep") and f then
        rendre(cadre, f)
        cadre:SetAlpha(1)
    else
        cadre:Hide()
    end
    if not copie then return end
    if not apercu then copie:Hide(); return end
    local exemple = f
    -- Mode photo sans faction suivie : une faction d'exemple (copie seulement).
    if not exemple and BarreRep.photo then
        exemple = { nom = L["Aube d'argent"], reaction = 6, min = 9000, max = 21000, valeur = 17350,
                    rang = _G.FACTION_STANDING_LABEL6 or "Honored" }
    end
    rendre(copie, exemple)
    copie:SetAlpha((not R("barreRep") or not exemple) and 0.6 or 1)
end

-- Minuteur : la durée de session et le rythme avancent.
function BarreRep.tic()
    if (cadre and cadre:IsShown()) or (copie and apercu) then BarreRep.maj() end
end

BarreRep.EVENEMENTS = { "UPDATE_FACTION", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED" }

function BarreRep.surEvenement(e, ...)
    if e == "PLAYER_ENTERING_WORLD" then
        local connexion = ...
        -- Nouvelle session à la connexion ; au /reload, on garde.
        if connexion then
            etat.session = nil
            etat.dernier = nil
        end
    elseif e == "PLAYER_REGEN_ENABLED" then
        if blizzardEnAttente then masquerBlizzard() end
    end
end

local CLES = { barreRep = true, barreRepLargeur = true, repTextes = true, repMasquerBlizzard = true }

function BarreRep.appliquer(cle)
    if not cadre then return end
    if cle == "repMasquerBlizzard" or cle == "barreRep" then masquerBlizzard() end
    for _, w in ipairs({ cadre, copie }) do
        if cle == "repTexture" or cle == "repContour" then habiller(w) end
        if cle == "repContourTexte" then contourTexte(w) end
    end
    if CLES[cle] or cle == "positions" then BarreRep.maj() end
end
