-- Menu principal : barre latérale à gauche, contenu défilant à droite.
-- Sections : Accueil (tous les modules d'un coup d'œil), Réglages (générés
-- depuis ns.Reglages.CATEGORIES), une page par module, À propos.
--
-- Ouverture : bouton de la minicarte, /sg. Échap ferme.

local ADDON, ns = ...

local Menu = {}
ns.Menu = Menu
local L = ns.L or setmetatable({}, { __index = function(_, k) return k end })

---------------------------------------------------------------------------
-- Logique pure (testée hors jeu)
---------------------------------------------------------------------------

-- Entrées visibles de la barre latérale, de haut en bas : { nom, y, sous,
-- groupe, def }. Le groupe « modules » déplié montre un bouton par module.
local PAS = { normal = 34, groupe = 34, sous = 26 }
function Menu.disposition(sections, modules, deplie)
    local l, y = {}, -12
    for _, s in ipairs(sections) do
        l[#l + 1] = { nom = s.nom, y = y, groupe = s.groupe, def = s }
        y = y - (s.groupe and PAS.groupe or PAS.normal)
        if s.groupe and deplie then
            for _, m in ipairs(modules) do
                l[#l + 1] = { nom = "module:" .. m.nom, y = y, sous = true, def = m }
                y = y - PAS.sous
            end
        end
    end
    return l
end

---------------------------------------------------------------------------
-- Fenêtre
---------------------------------------------------------------------------

local LARGEUR, HAUTEUR = 762, 480
local ENTETE, LATERALE, MARGE = 54, 210, 18
local W = LARGEUR - LATERALE - 2 * MARGE - 10   -- largeur utile du contenu
local VITRINE = 100   -- hauteur de la bannière d'aperçu

local T, C
local cadre, defile, ascenseur, sousTitre
local tournerLogo = function() end   -- tour de boussole (posé à la création)
local nav, pages, actuelle = {}, {}, nil

-- Question Oui / Non (fenêtre du jeu) ; sans elle, l'action directement.
local function confirmer(question, action)
    if not (StaticPopupDialogs and StaticPopup_Show) then return action() end
    StaticPopupDialogs.SUPERGUIDE_CONFIRMER = StaticPopupDialogs.SUPERGUIDE_CONFIRMER or {
        text = "%s", button1 = YES, button2 = NO,
        OnAccept = function(_, rappel) rappel() end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
    local f = StaticPopup_Show("SUPERGUIDE_CONFIRMER", question, nil, action)
    if f then f:ClearAllPoints(); f:SetPoint("CENTER", UIParent, "CENTER") end
end
Menu.confirmer = confirmer

---------------------------------------------------------------------------
-- Sauvegarde des réglages : texte à copier / coller (fenêtre du jeu)
---------------------------------------------------------------------------

local function boiteTexte(f) return f.editBox or f.EditBox or (f.GetEditBox and f:GetEditBox()) end

local function fenetreTexte(nom, def)
    if not (StaticPopupDialogs and StaticPopup_Show) then return end
    def.hasEditBox, def.editBoxWidth, def.maxLetters = true, 350, 0
    def.timeout, def.whileDead, def.hideOnEscape, def.preferredIndex = 0, true, true, 3
    def.EditBoxOnEscapePressed = function(e) e:GetParent():Hide() end
    StaticPopupDialogs[nom] = StaticPopupDialogs[nom] or def
end

function Menu.exporterReglages()
    local texte = ns.Sauvegarde.exporter(SuperGuideDB, ns.Reglages.DEFAUTS)
    fenetreTexte("SUPERGUIDE_EXPORTER", {
        text = L["Copie ce texte (Ctrl+C) et garde-le : il contient tous tes réglages."],
        button1 = CLOSE or OKAY,
        OnShow = function(f, t)
            local e = boiteTexte(f)
            if e then e:SetText(t or ""); e:HighlightText(); e:SetFocus() end
        end,
    })
    if StaticPopup_Show then StaticPopup_Show("SUPERGUIDE_EXPORTER", nil, nil, texte) end
end

local function importer(f)
    local e = boiteTexte(f)
    local t = ns.Sauvegarde.lire(e and e:GetText())
    if not t then
        ns.Jeu.message(L["Ce texte n'est pas une sauvegarde de SuperRsk valide : rien n'a changé."])
        return
    end
    ns.Jeu.message(L["%d réglages importés, rechargement de l'interface…"]:format(ns.Sauvegarde.importer(t)))
    ReloadUI()
end

function Menu.importerReglages()
    fenetreTexte("SUPERGUIDE_IMPORTER", {
        text = L["Colle ici un texte de sauvegarde (Ctrl+V). Tes réglages seront remplacés et l'interface rechargée."],
        button1 = L["Importer"], button2 = CANCEL,
        OnAccept = importer,
        EditBoxOnEnterPressed = function(e) importer(e:GetParent()); e:GetParent():Hide() end,
        OnShow = function(f) local e = boiteTexte(f); if e then e:SetText(""); e:SetFocus() end end,
    })
    if StaticPopup_Show then StaticPopup_Show("SUPERGUIDE_IMPORTER") end
end

-- Intitulé « RÉCENTS » suivi d'un trait, à la largeur du contenu.
local function intitule(parent, texte)
    local f = C.texte(parent, "libelle", "textePale")
    f:SetText(texte)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetColorTexture(T.rgb("bord"))
    t:SetHeight(1)
    t:SetPoint("LEFT", f, "RIGHT", 8, 0)
    t:SetPoint("RIGHT", parent, "LEFT", W, 0)
    f.trait = t
    return f
end

local function placer(f, y, x)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", f.parentPage or f:GetParent(), "TOPLEFT", x or 0, y)
end

-- Titre et description en tête de page ; renvoie le y suivant.
local function enTete(p, titre, desc)
    if p.sansEnTete then return 0 end
    local t = C.texte(p.cadre, "grand", "texte")
    t:SetPoint("TOPLEFT", 0, 0)
    t:SetText(titre)
    local d = C.texte(p.cadre, "texte", "texteDoux")
    d:SetPoint("TOPLEFT", 0, -26)
    d:SetWidth(W)
    d:SetText(desc)
    return -26 - (d:GetStringHeight() or 14) - 16
end

---------------------------------------------------------------------------
-- Accueil : tous les modules d'un coup d'œil (allumer, couper, ouvrir)
---------------------------------------------------------------------------

local accueil = {}

local function resumeModule(m, actif)
    local manque = ns.Reglages.manquant and ns.Reglages.manquant(m)
    if manque then return L["Nécessite %s"]:format(manque), "orange" end
    if not actif then return L["Coupé"], "textePale" end
    return L["Actif"], "vert"
end

-- Une ligne par module, tout tient sans défiler : case (allumer, couper),
-- nom ; l'état n'apparaît que s'il y a quelque chose à dire (coupé, addon
-- manquant). Un clic sur la ligne ouvre sa page, le survol la décrit.
-- Une carte par famille, sur deux colonnes équilibrées.
local LIGNE = 24
local TITRE_FAMILLE = 28   -- intitulé en haut de chaque carte
local ECART = 12

local function ligneModule(p, carte, m, y, largeur, premiere)
    local l = CreateFrame("Button", nil, carte)
    l:SetSize(largeur - 8, LIGNE)
    l:SetPoint("TOPLEFT", 4, -y)
    local survol = l:CreateTexture(nil, "BACKGROUND")
    survol:SetAllPoints()
    survol:SetColorTexture(T.rgb("accent"))
    survol:SetAlpha(0)
    if not premiere then
        local trait = l:CreateTexture(nil, "BORDER")
        trait:SetColorTexture(T.rgb("bordFort"))
        trait:SetAlpha(0.35)
        trait:SetHeight(1)
        trait:SetPoint("TOPLEFT", 8, 0)
        trait:SetPoint("TOPRIGHT", -8, 0)
    end
    if m.interrupteur then
        l.case = C.pour(l, { cle = m.interrupteur, type = "case", libelle = "" }, 20)
        l.case:SetPoint("LEFT", 6, 0)
        p.controles[#p.controles + 1] = l.case
    end
    local fleche = C.texte(l, "texte", "textePale")
    fleche:SetPoint("RIGHT", -8, 0)
    fleche:SetText("›")
    l.resume = C.texte(l, "petit", "texteDoux")
    l.resume:SetPoint("RIGHT", fleche, "LEFT", -6, 0)
    l.resume:SetJustifyH("RIGHT")
    l.titre = C.texte(l, "texte", "texte")
    l.titre:SetPoint("LEFT", 32, 0)
    l.titre:SetPoint("RIGHT", l.resume, "LEFT", -6, 0)
    l.titre:SetWordWrap(false)
    l.titre:SetText(m.titre)
    l:SetScript("OnClick", function() Menu.ouvrir("module:" .. m.nom) end)
    l:SetScript("OnEnter", function(self)
        survol:SetAlpha(0.08)
        fleche:SetTextColor(T.rgb("accent"))
        if m.desc then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(m.titre)
            GameTooltip:AddLine(m.desc, 1, 1, 1, true)
            GameTooltip:AddLine(L["Clic : régler ce module."], 0.45, 0.48, 0.54)
            GameTooltip:Show()
        end
    end)
    l:SetScript("OnLeave", function()
        survol:SetAlpha(0)
        fleche:SetTextColor(T.rgb("textePale"))
        GameTooltip:Hide()
    end)
    l.module = m
    p.lignes[#p.lignes + 1] = l
end

function accueil.construire(p)
    p.y0 = enTete(p, L["Accueil"], L["Coche pour allumer ou couper un module, clique sur sa ligne pour le régler."])
    p.lignes, p.controles = {}, {}
    p.liste = CreateFrame("Frame", nil, p.cadre)
    -- Familles dans l'ordre des modules (les modules sans famille à la fin).
    local familles, parNom = {}, {}
    for _, m in ipairs(ns.Reglages.MODULES) do
        local f = m.famille or { cle = "autres", titre = L["Autres"] }
        if not parNom[f.cle] then
            parNom[f.cle] = { titre = f.titre, modules = {} }
            familles[#familles + 1] = parNom[f.cle]
        end
        table.insert(parNom[f.cle].modules, m)
    end
    local largeur = math.floor((W - ECART) / 2)
    local hauts = { 0, 0 }
    for _, f in ipairs(familles) do
        local col = hauts[2] < hauts[1] and 2 or 1
        local carte = C.carte(p.liste)
        local h = TITRE_FAMILLE + #f.modules * LIGNE + 6
        carte:SetSize(largeur, h)
        carte:SetPoint("TOPLEFT", (col - 1) * (largeur + ECART), -hauts[col])
        local t = C.texte(carte, "libelle", "accent")
        t:SetText(f.titre:upper())
        t:SetPoint("TOPLEFT", 12, -11)
        for i, m in ipairs(f.modules) do
            ligneModule(p, carte, m, TITRE_FAMILLE + (i - 1) * LIGNE, largeur, i == 1)
        end
        hauts[col] = hauts[col] + h + ECART
    end
    p.liste:SetSize(W, math.max(hauts[1], hauts[2]) - ECART)
end

function accueil.maj(p)
    for _, l in ipairs(p.lignes) do
        local m = l.module
        if l.case then l.case.maj() end
        local actif = not m.interrupteur or ns.Reglages.get(m.interrupteur) ~= false
        local texte, couleur = resumeModule(m, actif)
        -- « Actif » se voit à la case : on n'écrit que ce qui sort de l'ordinaire.
        if couleur == "vert" then texte = "" end
        l.resume:SetText(texte)
        l.resume:SetTextColor(T.rgb(couleur))
        l.titre:SetTextColor(T.rgb(actif and "texte" or "texteDoux"))
    end
    placer(p.liste, p.y0)
    return -p.y0 + p.liste:GetHeight() + 8
end

---------------------------------------------------------------------------
-- Réglages
---------------------------------------------------------------------------

local reglages = {}

-- Carte titrée à partir de y ; renvoie le y suivant.
local HAUTEURS = { case = 22, curseur = 38, choix = 48, texture = 48, couleur = 22, texte = 48, touche = 48 }
local function carteOptions(p, y, titre, hauteurContenu, remplir)
    local t = intitule(p.cadre, titre:upper())
    t:SetPoint("TOPLEFT", 0, y)
    y = y - 18
    local c = C.carte(p.cadre)
    c:SetPoint("TOPLEFT", 0, y)
    c:SetSize(W, hauteurContenu + 24)
    remplir(c)
    return y - hauteurContenu - 24 - 16
end

-- Une carte de contrôles par catégorie { titre, options } ; renvoie le y suivant.
local function cartesOptions(p, y, categories)
    p.controles = p.controles or {}
    for _, cat in ipairs(categories) do
        local h = 0
        for i, o in ipairs(cat.options) do h = h + HAUTEURS[o.type] + (i > 1 and 12 or 0) end
        y = carteOptions(p, y, cat.titre, h, function(c)
            local yy = -12
            for _, o in ipairs(cat.options) do
                local f = C.pour(c, o, W - 28)
                f:SetPoint("TOPLEFT", 14, yy)
                p.controles[#p.controles + 1] = f
                yy = yy - HAUTEURS[o.type] - 12
            end
        end)
    end
    return y
end

-- Options générales (minicarte, positions, sauvegarde), en tête de la
-- page « Général » : plus de section Réglages à part pour si peu.
local function optionsGenerales(p, y)
    y = cartesOptions(p, y, ns.Reglages.CATEGORIES)
    local function carte(titre, hauteurContenu, remplir)
        y = carteOptions(p, y, titre, hauteurContenu, remplir)
    end
    carte(L["Positions"], 40, function(c)
        local d = C.texte(c, "petit", "texteDoux")
        d:SetPoint("TOPLEFT", 14, -14)
        d:SetWidth(W - 340)
        d:SetText(L["Place où tu veux chaque élément des modules : barres, fenêtres, widget, boutons du swap."])
        local b = C.bouton(c, L["Réinitialiser"], "orange", function()
            confirmer(L["Remettre les barres, les fenêtres et le bouton de la minicarte à leur place ?"],
                function() ns.Reglages.reinitialiserPositions() end)
        end, 110)
        b:SetPoint("RIGHT", -14, 0)
        local dep = C.bouton(c, L["Déplacer les éléments"], "accent", function() ns.Deplacement.ouvrir() end, 170)
        dep:SetPoint("RIGHT", b, "LEFT", -8, 0)
    end)
    carte(L["Sauvegarde des réglages"], 40, function(c)
        local d = C.texte(c, "petit", "texteDoux")
        d:SetPoint("TOPLEFT", 14, -8)
        d:SetWidth(W - 260)
        d:SetText(L["Tes réglages sont communs à tous tes personnages. Un texte à copier pour les remettre sur un autre compte ou après une réinstallation."])
        local imp = C.bouton(c, L["Importer"], "orange", Menu.importerReglages, 100)
        imp:SetPoint("RIGHT", -14, 0)
        local exp = C.bouton(c, L["Exporter"], "accent", Menu.exporterReglages, 100)
        exp:SetPoint("RIGHT", imp, "LEFT", -8, 0)
    end)
    return y
end

function reglages.maj(p)
    for _, f in ipairs(p.controles) do f.maj() end
    return p.hauteur
end

---------------------------------------------------------------------------
-- Marqueurs : la liste des personnes, sous les réglages du module
---------------------------------------------------------------------------

local personnes = {}
local LIGNE_PERSONNE = 30

local function personnesChangees()
    ns.Marqueurs.maj()
    Menu.rafraichir(true)
end

local function ajouterPersonne(q, nom)
    local M = ns.Marqueurs
    local liste = M.personnes()
    local ok, raison = M.ajouter(liste, nom, M.libre(liste, ns.Reglages.get("marqueurMoi")))
    if ok then
        q.champ:SetText("")
        q.champ:ClearFocus()
        personnesChangees()
    elseif raison == "deja" then
        ns.Jeu.message(L["%s est déjà dans la liste."]:format(nom))
    end
end

-- Ligne : nom, les 8 symboles (le choisi en clair), Retirer.
local function lignePersonne(q, i)
    local l = q.lignes[i]
    if l then return l end
    l = CreateFrame("Frame", nil, q.carteListe)
    l:SetSize(W - 28, 26)
    l.nom = C.texte(l, "texte", "texte")
    l.nom:SetPoint("LEFT", 0, 0)
    l.nom:SetWidth(150)
    l.symboles = {}
    for n = 1, 8 do
        local b = CreateFrame("Button", nil, l)
        b:SetSize(22, 22)
        b:SetPoint("LEFT", 156 + (n - 1) * 26, 0)
        b.fond, b.bord = T.fond(b, "flot", 1, "bordFort")
        b.icone = b:CreateTexture(nil, "ARTWORK")
        b.icone:SetPoint("TOPLEFT", 3, -3)
        b.icone:SetPoint("BOTTOMRIGHT", -3, 3)
        b.icone:SetTexture(ns.Marqueurs.texture(n))
        b:SetScript("OnClick", function()
            ns.Marqueurs.personnes()[l.index].icone = n
            personnesChangees()
        end)
        C.infobulle(b, ns.Marqueurs.NOMS[n])
        l.symboles[n] = b
    end
    l.retirer = C.bouton(l, L["Retirer"], "rouge", function()
        table.remove(ns.Marqueurs.personnes(), l.index)
        personnesChangees()
    end, 80)
    l.retirer:SetPoint("RIGHT", 0, 0)
    q.lignes[i] = l
    return l
end

function personnes.construire(q)
    q.y1 = -q.hauteur
    q.titreListe = intitule(q.cadre, L["PERSONNES"])
    local c = C.carte(q.cadre)
    c:SetWidth(W)
    q.carteListe = c
    q.aide = C.texte(c, "petit", "texteDoux")
    q.aide:SetPoint("TOPLEFT", 14, -12)
    q.aide:SetWidth(W - 28)
    q.aide:SetText(L["Leur symbole est posé quand elles sont dans ton groupe. Écris un nom (Nom-Royaume pour un autre royaume) ou cible la personne, puis ajoute-la. Clic sur un symbole pour le changer."])
    q.hauteurAide = q.aide:GetStringHeight() or 28
    q.champ = C.champ(c, W - 28 - 90 - 110 - 16, L["Nom du joueur"], nil, nil,
        function(e) ajouterPersonne(q, e:GetText()) end)
    q.champ:SetPoint("TOPLEFT", 14, -12 - q.hauteurAide - 10)
    q.ajouter = C.bouton(c, L["Ajouter"], "vert", function() ajouterPersonne(q, q.champ:GetText()) end, 90)
    q.ajouter:SetPoint("LEFT", q.champ, "RIGHT", 8, 0)
    q.maCible = C.bouton(c, L["Ma cible"], "accent", function()
        local nom = UnitIsPlayer("target") and GetUnitName("target", true)
        if nom and not (issecretvalue and issecretvalue(nom)) then ajouterPersonne(q, nom)
        else ns.Jeu.message(L["Cible d'abord un joueur."]) end
    end, 110)
    q.maCible:SetPoint("LEFT", q.ajouter, "RIGHT", 8, 0)
    q.vide = C.texte(c, "texte", "textePale")
    q.vide:SetText(L["Personne pour l'instant."])
    q.lignes = {}
end

function personnes.maj(q)
    local liste = ns.Marqueurs.personnes()
    local y = q.y1
    placer(q.titreListe, y)
    y = y - 18
    placer(q.carteListe, y)
    local yy = -12 - q.hauteurAide - 10 - 26 - 14
    for _, l in ipairs(q.lignes) do l:Hide() end
    for i, e in ipairs(liste) do
        local l = lignePersonne(q, i)
        l.index = i
        l.nom:SetText(e.nom)
        for n, b in ipairs(l.symboles) do
            local oui = n == e.icone
            b.icone:SetAlpha(oui and 1 or 0.3)
            b.bord:SetVertexColor(T.rgb(oui and "accent" or "bordFort"))
        end
        placer(l, yy, 14)
        l:Show()
        yy = yy - LIGNE_PERSONNE
    end
    if #liste == 0 then
        placer(q.vide, yy, 14)
        q.vide:Show()
        yy = yy - 20
    else
        q.vide:Hide()
    end
    q.carteListe:SetHeight(-yy + 6)
    return -y - yy + 6 + 16
end

---------------------------------------------------------------------------
-- Module (une page par module de ns.Reglages.MODULES)
---------------------------------------------------------------------------

local module = {}

-- Partie propre à un module, sous ses réglages (construire, puis maj qui
-- rend la hauteur totale).
local EXTRAS = { marqueurs = personnes }

-- Onglets d'un module : { { nom, titre, page } } ; sans entrée, une seule page de réglages.
local ONGLETS = {}

-- Réglages du module dans le cadre q (cartes, puis Déplacer et boutons).
local function construireReglages(q, m)
    local y = cartesOptions(q, 0, m.categories or { { titre = L["Réglages"], options = m.options } })
    -- Boutons du module sur une ligne, à parts égales dans la largeur
    -- (jamais plus de 200 px chacun, jamais au-delà du bord).
    local actions = {}
    if m.deplacer then actions[1] = { texte = L["Déplacer"], action = function() ns.Deplacement.ouvrir() end } end
    for _, d in ipairs(m.boutons or {}) do actions[#actions + 1] = d end
    local x = 0
    local largeur = #actions > 0 and math.min(200, math.floor((W - (#actions - 1) * 8) / #actions)) or 0
    for _, d in ipairs(actions) do
        local b = C.bouton(q.cadre, d.texte, "accent", d.action, largeur)
        b:SetPoint("TOPLEFT", x, y)
        x = x + largeur + 8
    end
    if x > 0 then y = y - 24 - 16 end
    local lignes = m.details and m.details() or {}
    if #lignes > 0 then
        y = carteOptions(q, y, L["Ce que ça change"], #lignes * 18, function(c)
            for i, d in ipairs(lignes) do
                local g = C.texte(c, "petit", "texteDoux")
                g:SetPoint("TOPLEFT", 14, -12 - (i - 1) * 18)
                g:SetText(d[1])
                local v = C.texte(c, "petit", "texte")
                v:SetPoint("TOPRIGHT", -14, -12 - (i - 1) * 18)
                v:SetText(d[2])
            end
        end)
    end
    q.hauteur = -y
    q.extra = EXTRAS[m.nom]
    if q.extra then q.extra.construire(q) end
end

-- Sous-page (onglet) : son propre cadre sous l'en-tête et les onglets.
local function sousPage(p, def)
    local f = CreateFrame("Frame", nil, p.cadre)
    f:SetPoint("TOPLEFT", 0, p.y0)
    f:SetSize(W, 10)
    return { cadre = f, def = p.def, sansEnTete = true, page = def and def.page }
end

function module.construire(p)
    local m = p.def.module
    p.y0 = enTete(p, m.titre, m.desc)
    p.onglets = ONGLETS[m.nom]
    if p.onglets then
        p.boutons = {}
        local x = 0
        for _, o in ipairs(p.onglets) do
            local b = C.bouton(p.cadre, L[o.titre], "texte", function()
                p.onglet = o.nom
                Menu.rafraichir()
            end, 120)
            b:SetPoint("TOPLEFT", x, p.y0)
            x = x + 128
            p.boutons[o.nom] = b
        end
        p.y0 = p.y0 - 24 - 16
        p.onglet = p.onglet or p.onglets[1].nom
    end
    p.sous = {}
end

-- Onglet affiché (construit à la première visite) ; sans onglets : les réglages.
function module.maj(p)
    local m = p.def.module
    local nom = p.onglet or "reglages"
    for k, q in pairs(p.sous) do q.cadre:SetShown(k == nom) end
    local q = p.sous[nom]
    if not q then
        local def
        for _, o in ipairs(p.onglets or {}) do if o.nom == nom then def = o end end
        q = sousPage(p, def)
        if q.page then q.page.construire(q) else q.controles = {}; construireReglages(q, m) end
        p.sous[nom] = q
    end
    q.cadre:Show()
    for k, b in pairs(p.boutons or {}) do
        b.texte:SetTextColor(T.rgb(k == nom and "accent" or "texteDoux"))
    end
    local h
    if q.page then h = q.page.maj(q) else h = reglages.maj(q) end
    if q.extra then h = q.extra.maj(q) end
    q.cadre:SetHeight(math.max(10, h or 10))
    -- Le menu relit les réglages de la page affichée (réglage changé ailleurs).
    p.controles = q.controles
    return -p.y0 + (h or 0)
end

---------------------------------------------------------------------------
-- À propos
---------------------------------------------------------------------------

local apropos = {}

local function version()
    local f = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    return f and f(ADDON, "Version") or "?"
end

function apropos.construire(p)
    local y = enTete(p, L["Options"], L["Version %s · la boîte à outils maison de SuperRsk et ses potes."]:format(version()))
    y = optionsGenerales(p, y)
    local function bloc(titre, lignes)
        local t = intitule(p.cadre, titre)
        t:SetPoint("TOPLEFT", 0, y)
        y = y - 20
        local f = C.texte(p.cadre, "texte", "texteDoux")
        f:SetPoint("TOPLEFT", 0, y)
        f:SetWidth(W)
        f:SetSpacing(5)
        f:SetText(table.concat(lignes, "\n"))
        y = y - (f:GetStringHeight() or 60) - 20
    end
    local a = "|cff" .. T.hex.accent
    bloc(L["COMMANDES"], {
        a .. "/sg|r  " .. L["ce menu (aussi /srsk)"],
        a .. "/sg move|r  " .. L["déplacer les barres et fenêtres"],
        a .. "/sg tenues|r  " .. L["tes tenues Auto Sets"],
        a .. "/sg tir|r  " .. L["armement mesuré du tir auto / de la baguette"],
        a .. "/sg spe|r  " .. L["arbre de talents retenu par Auto Equip"],
    })
    bloc(L["CRÉDITS"], {
        L["Icônes : Lucide (licence ISC)."],
        L["Police : Archivo (SIL Open Font License 1.1)."],
        L["Bibliothèques : LibStub, CallbackHandler-1.0, FlightMasterData."],
    })
    p.hauteur = -y
end

function apropos.maj(p) return reglages.maj(p) end

---------------------------------------------------------------------------
-- Cadre, navigation, défilement
---------------------------------------------------------------------------

local SECTIONS = {
    { nom = "accueil", libelle = "Accueil", icone = "accueil", page = accueil },
    { nom = "modules", libelle = "Module", icone = "liste", groupe = true },
    { nom = "apropos", libelle = "Options", icone = "reglages", page = apropos },
}

local function majAscenseur()
    local max = defile:GetVerticalScrollRange() or 0
    if max <= 0 then ascenseur:Hide(); return end
    local h = defile:GetHeight() or 1
    local hp = h * h / (h + max)
    ascenseur:SetHeight(hp)
    ascenseur:ClearAllPoints()
    ascenseur:SetPoint("TOPRIGHT", defile, "TOPRIGHT", 8, -(h - hp) * (defile:GetVerticalScroll() or 0) / max)
    ascenseur:Show()
end

local function defiler(delta)
    local max = defile:GetVerticalScrollRange() or 0
    local v = math.max(0, math.min(max, (defile:GetVerticalScroll() or 0) - delta * 40))
    defile:SetVerticalScroll(v)
    majAscenseur()
end

local deplie = false

-- Aperçu en direct : le module ouvert montre son élément (barre d'XP,
-- widget…) tant que sa page est affichée.
local apercuActuel, monte, fixe
local HAUT_FIXE = 18 + VITRINE + 14   -- libellé, bannière, marge sous l'en-tête fixe

-- La bannière montre une COPIE de l'élément du module (vitrine() rend
-- cadre, clé, true) : le vrai reste à sa place sur l'écran, visible, et suit
-- les réglages en direct. Copie réduite si elle est trop large.
-- Sans copie (ancien contrat), le vrai élément est emprunté puis rendu.
-- Réduit l'élément de la bannière s'il est trop grand. Une copie est
-- recadrée à chaque réglage changé (sa taille suit les réglages).
local function ajusterVitrine()
    if not monte then return end
    local f = monte.cadre
    if monte.copie then f:SetScale(1) end
    local largeur = (f:GetWidth() or 0) * (f:GetScale() or 1)
    if largeur > W - 40 then f:SetScale((f:GetScale() or 1) * (W - 40) / largeur) end
    local hauteur = (f:GetHeight() or 0) * (f:GetScale() or 1)
    if hauteur > VITRINE - 12 then f:SetScale((f:GetScale() or 1) * (VITRINE - 12) / hauteur) end
end
Menu.ajusterVitrine = ajusterVitrine
local ecouteVitrine = false
local function ecouterVitrine()
    if ecouteVitrine or not (ns.Reglages and ns.Reglages.ecouter) then return end
    ecouteVitrine = true
    ns.Reglages.ecouter(function()
        if monte and monte.copie and C_Timer then C_Timer.After(0, ajusterVitrine) end
    end)
end

local function demonter()
    if not monte then return end
    local f = monte.cadre
    if monte.copie then
        f:Hide()
        f:SetScale(1)
        monte = nil
        return
    end
    f:SetParent(UIParent)
    f:SetScale(1)
    f:SetFrameStrata(monte.strate or "MEDIUM")
    f:EnableMouse(true)
    if ns.Deplacement and ns.Deplacement.replacer then ns.Deplacement.replacer(monte.cle) end
    monte = nil
end

local function monter(m, banniere)
    local f, cle, copie = m.vitrine()
    if not (f and banniere) then return end
    monte = { cadre = f, cle = cle, strate = f:GetFrameStrata(), copie = copie == true }
    ecouterVitrine()
    f:SetParent(banniere)
    f:SetFrameStrata(banniere:GetFrameStrata())
    f:SetFrameLevel((banniere:GetFrameLevel() or 0) + 5)
    f:EnableMouse(false)
    f:ClearAllPoints()
    f:SetPoint("CENTER", banniere, "CENTER", 0, 0)
    ajusterVitrine()
end

local function changerApercu(m, p)
    if apercuActuel == m then return end
    demonter()
    if apercuActuel and apercuActuel.apercu then apercuActuel.apercu(false) end
    apercuActuel = m
    if m and m.apercu then m.apercu(true) end
    if m and m.vitrine and fixe then monter(m, fixe.carte) end
end

-- Ouverture et fermeture en fondu, avec un léger zoom à l'ouverture.
local FONDU_ENTREE, FONDU_SORTIE = 0.18, 0.12
local function fondu(entree)
    local debut = GetTime and GetTime() or 0
    local duree = entree and FONDU_ENTREE or FONDU_SORTIE
    cadre:SetScript("OnUpdate", function(self)
        local t = math.min(1, ((GetTime and GetTime() or debut + duree) - debut) / duree)
        local doux = 1 - (1 - t) * (1 - t)
        self:SetAlpha(entree and doux or (1 - doux))
        if entree then self:SetScale(0.97 + 0.03 * doux) end
        if t >= 1 then
            self:SetScript("OnUpdate", nil)
            self:SetScale(1)
            if not entree then self:Hide(); self:SetAlpha(1) end
        end
    end)
end

local function majNav()
    local visibles = {}
    for _, e in ipairs(Menu.disposition(SECTIONS, ns.Reglages.MODULES, deplie)) do visibles[e.nom] = e end
    for _, b in ipairs(nav) do
        local e = visibles[b.nom]
        b:SetShown(e ~= nil)
        if e then
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", e.sous and 20 or 8, e.y)
        end
        if b.chevron then b.chevron:SetRotation(deplie and -math.pi / 2 or 0) end
        local oui = b.nom == actuelle
        b.fond:SetAlpha(oui and 1 or 0)
        b.bord:SetAlpha(oui and 1 or 0)
        b.barre:SetShown(oui)
        b.icone:SetVertexColor(T.rgb(oui and "accent" or "texteDoux"))
        -- Module : coche s'il est allumé, rien s'il est coupé.
        local m = b.module
        if type(m) == "table" then
            local allume = not m.interrupteur or ns.Reglages.get(m.interrupteur) ~= false
            b.icone:SetAlpha(allume and 1 or 0)
            if not allume and not oui then b.texte:SetTextColor(T.rgb("textePale")) end
        end
        b.texte:SetTextColor(T.rgb(oui and "texte" or "texteDoux"))
    end
end

local function creer()
    if cadre then return end
    T, C = ns.Theme, ns.Controles
    cadre = CreateFrame("Frame", "SuperGuideMenu", UIParent)
    cadre:SetSize(LARGEUR, HAUTEUR)
    cadre:SetPoint("CENTER")
    cadre:SetFrameStrata("HIGH")   -- sous les confirmations (DIALOG)
    cadre:SetToplevel(true)
    cadre:SetClampedToScreen(true)
    cadre:SetMovable(true)
    cadre:EnableMouse(true)
    T.fond(cadre, "panneau", 0.98, "bordFort")
    cadre:Hide()
    if UISpecialFrames then table.insert(UISpecialFrames, "SuperGuideMenu") end

    -- En-tête : logo, titre, section, fermer. On déplace le menu par là.
    local entete = CreateFrame("Frame", nil, cadre)
    entete:SetPoint("TOPLEFT"); entete:SetPoint("TOPRIGHT")
    entete:SetHeight(ENTETE)
    entete:EnableMouse(true)
    entete:RegisterForDrag("LeftButton")
    entete:SetScript("OnDragStart", function() cadre:StartMoving() end)
    entete:SetScript("OnDragStop", function() cadre:StopMovingOrSizing() end)
    -- La marque, comme partout : boussole vivante (un tour à l'ouverture,
    -- au survol et de temps en temps), SuperRsk, All in One QoL.
    local b = C.marque(entete, entete, 12)
    b.logo:SetPoint("LEFT", MARGE, 0)
    tournerLogo = b.tourner
    local point = C.texte(entete, "texte", "textePale")
    point:SetPoint("LEFT", b.qol, "RIGHT", 10, 1)
    point:SetText("·")
    sousTitre = C.texte(entete, "texte", "textePale")
    sousTitre:SetPoint("LEFT", point, "RIGHT", 10, 0)
    local fermer = CreateFrame("Button", nil, entete)
    fermer:SetSize(24, 24)
    fermer:SetPoint("RIGHT", -12, 0)
    T.fond(fermer, "flot", 1, "bordFort")
    local x = fermer:CreateTexture(nil, "ARTWORK")
    x:SetTexture(T.icone("fermer"))
    x:SetSize(13, 13)
    x:SetPoint("CENTER")
    x:SetVertexColor(T.rgb("texteDoux"))
    fermer:SetScript("OnEnter", function() x:SetVertexColor(T.rgb("rouge")) end)
    fermer:SetScript("OnLeave", function() x:SetVertexColor(T.rgb("texteDoux")) end)
    fermer:SetScript("OnClick", function() Menu.fermer() end)
    local deplacer = C.bouton(entete, L["Déplacer"], "accent", function()
        cadre:Hide()
        ns.Deplacement.ouvrir()
    end, 90)
    deplacer:SetPoint("RIGHT", fermer, "LEFT", -8, 0)
    C.infobulle(deplacer, L["Déplacer"], L["Place où tu veux chaque élément des modules : barres, fenêtres, widget, boutons du swap."])

    -- Cadenas : verrouille tous les éléments d'un coup (Maj pour bouger quand même).
    local cadenas = CreateFrame("Button", nil, entete)
    cadenas:SetSize(24, 24)
    cadenas:SetPoint("RIGHT", deplacer, "LEFT", -8, 0)
    local _, bordCadenas = T.fond(cadenas, "flot", 1, "bordFort")
    local ic = cadenas:CreateTexture(nil, "ARTWORK")
    ic:SetSize(14, 14)
    ic:SetPoint("CENTER")
    local function peindre()
        local oui = ns.Reglages.get("elementsVerrouilles") == true
        ic:SetTexture(T.icone(oui and "cadenas" or "cadenas-ouvert"))
        ic:SetVertexColor(T.rgb(oui and "accent" or "texteDoux"))
        if bordCadenas then bordCadenas:SetVertexColor(T.rgb(oui and "accent" or "bordFort")) end
    end
    peindre()
    ns.Reglages.ecouter(function(cle) if cle == "elementsVerrouilles" then peindre() end end)
    cadenas:SetScript("OnClick", function() ns.Deplacement.basculerVerrou() end)
    cadenas:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        local oui = ns.Reglages.get("elementsVerrouilles") == true
        GameTooltip:SetText(oui and L["Éléments verrouillés"] or L["Éléments déverrouillés"], 1, 1, 1)
        GameTooltip:AddLine(oui and L["Rien ne bouge en glissant : Maj + glisser pour en déplacer un. Clic : déverrouiller."]
            or L["Clic : verrouiller tous les éléments (barres, widgets, fenêtres qui s'ouvrent seules, bouton de la minicarte). Les fenêtres que tu ouvres toi-même restent mobiles."], 0.6, 0.64, 0.7, true)
        GameTooltip:Show()
    end)
    cadenas:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- Menu fermé (croix, Échap, /sg) : plus d'aperçu.
    cadre:SetScript("OnHide", function() changerApercu(nil) end)
    local sep = T.separateur(cadre)
    sep:SetPoint("TOPLEFT", 1, -ENTETE)
    sep:SetPoint("TOPRIGHT", -1, -ENTETE)

    -- Barre latérale.
    local cote = CreateFrame("Frame", nil, cadre)
    cote:SetPoint("TOPLEFT", 1, -ENTETE - 1)
    cote:SetPoint("BOTTOMLEFT", 1, 1)
    cote:SetWidth(LATERALE)
    local fc = cote:CreateTexture(nil, "BACKGROUND")
    fc:SetAllPoints()
    local r, g, b = T.rgb("sombre")
    fc:SetColorTexture(r, g, b, 0.6)
    local trait = cote:CreateTexture(nil, "ARTWORK")
    trait:SetColorTexture(T.rgb("bord"))
    trait:SetWidth(1)
    trait:SetPoint("TOPRIGHT"); trait:SetPoint("BOTTOMRIGHT")
    local entrees = {}
    for _, s in ipairs(SECTIONS) do entrees[#entrees + 1] = s end
    for _, m in ipairs(ns.Reglages.MODULES) do
        entrees[#entrees + 1] = { nom = "module:" .. m.nom, libelle = m.titre, icone = "fait", sous = true,
                                  page = module, module = m }
    end
    for i, s in ipairs(entrees) do
        local bt = CreateFrame("Button", nil, cote)
        bt:SetSize(LATERALE - (s.sous and 28 or 16), s.sous and 24 or 32)
        bt.nom = s.nom
        bt.module = s.module
        bt.fond, bt.bord = T.fond(bt, "flot", 1, "bordFort")
        bt.barre = bt:CreateTexture(nil, "OVERLAY")
        bt.barre:SetColorTexture(T.rgb("accent"))
        bt.barre:SetSize(3, 18)
        bt.barre:SetPoint("LEFT", 0, 0)
        bt.icone = bt:CreateTexture(nil, "ARTWORK")
        bt.icone:SetTexture(T.icone(s.icone))
        bt.icone:SetSize(15, 15)
        bt.icone:SetPoint("LEFT", 14, 0)
        bt.texte = C.texte(bt, "texte", "texteDoux")
        bt.texte:SetPoint("LEFT", bt.icone, "RIGHT", 10, 0)
        -- Le libellé reste dans sa colonne (coupé par « … » s'il est trop long).
        bt.texte:SetPoint("RIGHT", bt, "RIGHT", s.groupe and -26 or -6, 0)
        bt.texte:SetJustifyH("LEFT")
        bt.texte:SetWordWrap(false)
        bt.texte:SetText(L[s.libelle])
        bt.chevron = false
        if s.groupe then
            -- Chevron à droite : clic = déplier / replier.
            bt.chevron = bt:CreateTexture(nil, "ARTWORK")
            bt.chevron:SetTexture(T.icone("suivant"))
            bt.chevron:SetSize(12, 12)
            bt.chevron:SetPoint("RIGHT", -10, 0)
            bt.chevron:SetVertexColor(T.rgb("texteDoux"))
        end
        bt:SetScript("OnEnter", function(self) if self.nom ~= actuelle then self.texte:SetTextColor(T.rgb("texte")) end end)
        bt:SetScript("OnLeave", function(self) if self.nom ~= actuelle then self.texte:SetTextColor(T.rgb("texteDoux")) end end)
        bt:SetScript("OnClick", function()
            if s.groupe then deplie = not deplie; majNav() else Menu.ouvrir(s.nom) end
        end)
        nav[i] = bt
    end
    majNav()
    -- La liste dépliée doit tenir au-dessus du pied : la fenêtre grandit
    -- s'il le faut (plus de modules qu'avant).
    -- Bas du dernier bouton (un grand : « À propos »), puis la place du pied.
    local bas = 0
    for _, e in ipairs(Menu.disposition(SECTIONS, ns.Reglages.MODULES, true)) do
        bas = math.min(bas, e.y - (e.sous and PAS.sous or PAS.normal))
    end
    cadre:SetHeight(math.max(HAUTEUR, ENTETE + (-bas) + 44))
    local pied = C.texte(cote, "petit", "textePale")
    pied:SetPoint("BOTTOMLEFT", 16, 14)
    pied:SetText("v" .. version() .. "  ·  /sg menu")

    -- Contenu défilant (molette) avec un ascenseur fin.
    defile = CreateFrame("ScrollFrame", nil, cadre)
    defile:SetPoint("TOPLEFT", LATERALE + MARGE, -ENTETE - MARGE)
    defile:SetPoint("BOTTOMRIGHT", -MARGE - 10, MARGE)
    defile:EnableMouseWheel(true)
    defile:SetScript("OnMouseWheel", function(_, d) defiler(d) end)
    defile:SetScript("OnScrollRangeChanged", majAscenseur)
    ascenseur = cadre:CreateTexture(nil, "OVERLAY")
    ascenseur:SetColorTexture(T.rgb("bordFort"))
    ascenseur:SetWidth(4)
    ascenseur:Hide()

    -- En-tête fixe des modules qui ont un aperçu : il ne défile pas, les
    -- réglages passent dessous. Pastille « en direct » qui pulse, et la
    -- bannière s'illumine un instant à chaque réglage changé.
    fixe = CreateFrame("Frame", nil, cadre)
    fixe:SetPoint("TOPLEFT", LATERALE + MARGE, -ENTETE - MARGE)
    fixe:SetSize(W, HAUT_FIXE)
    fixe.point = fixe:CreateTexture(nil, "OVERLAY")
    fixe.point:SetTexture(T.MEDIA .. "RondPlein")
    fixe.point:SetSize(8, 8)
    fixe.point:SetPoint("TOPLEFT", 0, -3)
    fixe.point:SetVertexColor(T.rgb("accent"))
    local libelle = intitule(fixe, L["APERÇU EN DIRECT"])
    libelle:SetPoint("TOPLEFT", 14, 0)
    fixe.carte = C.carte(fixe)
    fixe.carte:SetPoint("TOPLEFT", 0, -18)
    fixe.carte:SetSize(W, VITRINE)
    -- Rien ne déborde de la bannière sur les réglages.
    if fixe.carte.SetClipsChildren then fixe.carte:SetClipsChildren(true) end
    fixe.lueur = {}
    for i, pt in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" },
                          { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local t = fixe.carte:CreateTexture(nil, "OVERLAY", nil, 7)
        t:SetColorTexture(T.rgb("accent"))
        t:SetPoint(pt[1]); t:SetPoint(pt[2])
        if i <= 2 then t:SetHeight(2) else t:SetWidth(2) end
        t:SetAlpha(0)
        fixe.lueur[i] = t
    end
    local trait = fixe:CreateTexture(nil, "ARTWORK")
    trait:SetColorTexture(T.rgb("bord"))
    trait:SetHeight(1)
    trait:SetPoint("BOTTOMLEFT", 0, 4)
    trait:SetPoint("BOTTOMRIGHT", 0, 4)
    fixe:SetScript("OnUpdate", function(self)
        local t = GetTime and GetTime() or 0
        self.point:SetAlpha(0.35 + 0.65 * math.abs(math.sin(t * 2.4)))
        local a = self.flash and math.max(0, 1 - (t - self.flash) / 0.6) or 0
        for _, l in ipairs(self.lueur) do l:SetAlpha(a) end
        if a == 0 then self.flash = nil end
    end)
    fixe:Hide()

    for _, s in ipairs(entrees) do
        if s.page then
            local f = CreateFrame("Frame", nil, defile)
            f:SetSize(W, 10)
            f:Hide()
            pages[s.nom] = { cadre = f, def = s }
        end
    end

    -- Un réglage changé ailleurs (/sg lock, Ctrl + molette) : on relit.
    ns.Reglages.ecouter(function()
        if not cadre:IsShown() then return end
        if fixe:IsShown() then fixe.flash = GetTime and GetTime() or 0 end
        majNav()
        if pages[actuelle] and pages[actuelle].controles then Menu.rafraichir(true) end
    end)
end

-- Redessine la page affichée ; « garder » conserve la position de défilement.
function Menu.rafraichir(garder)
    if not (cadre and cadre:IsShown() and actuelle) then return end
    local p = pages[actuelle]
    p.cadre:SetHeight(math.max(10, p.def.page.maj(p)))
    if defile.UpdateScrollChildRect then defile:UpdateScrollChildRect() end
    if not garder then defile:SetVerticalScroll(0) end
    majAscenseur()
end

local ALIAS = { reglages = { "apropos" } }   -- l'ancienne section Réglages vit dans Options

function Menu.ouvrir(nom, onglet)
    -- Jamais de fenêtre de réglages en combat.
    if InCombatLockdown() or (UnitAffectingCombat and UnitAffectingCombat("player")) then
        ns.Jeu.message(L["Pas pendant un combat : le menu s'ouvre une fois le combat fini."])
        return
    end
    creer()
    if ALIAS[nom] then nom, onglet = ALIAS[nom][1], onglet or ALIAS[nom][2] end
    nom = (nom and pages[nom]) and nom or actuelle or "accueil"
    local p = pages[nom]
    if not p.construit then
        p.def.page.construire(p)
        p.construit = true
    end
    if onglet and p.onglets then p.onglet = onglet end
    for _, q in pairs(pages) do q.cadre:Hide() end
    p.cadre:Show()
    defile:SetScrollChild(p.cadre)
    actuelle = nom
    if p.def.sous then deplie = true end
    sousTitre:SetText(L[p.def.libelle])
    majNav()
    if not cadre:IsShown() or cadre:GetScript("OnUpdate") then
        tournerLogo()
        cadre:SetAlpha(0)
        cadre:Show()
        fondu(true)
    end
    cadre:Raise()
    local avecApercu = p.def.module and p.def.module.vitrine and true or false
    fixe:SetShown(avecApercu)
    defile:ClearAllPoints()
    defile:SetPoint("TOPLEFT", LATERALE + MARGE, -ENTETE - MARGE - (avecApercu and HAUT_FIXE or 0))
    defile:SetPoint("BOTTOMRIGHT", -MARGE - 10, MARGE)
    changerApercu(p.def.module, p)
    Menu.rafraichir()
end

function Menu.fermer()
    if not (cadre and cadre:IsShown()) then return end
    changerApercu(nil)
    fondu(false)
end

function Menu.basculer(nom)
    if cadre and cadre:IsShown() and (not nom or nom == actuelle) then return Menu.fermer() end
    Menu.ouvrir(nom)
end

function Menu.ouvert() return cadre ~= nil and cadre:IsShown() end

-- Page affichée et son onglet (nil sans onglets).
function Menu.actuelle()
    local p = actuelle and pages[actuelle]
    return actuelle, p and p.onglet
end
