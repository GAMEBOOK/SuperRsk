-- Auto Sets : la fenêtre (/sg tenues) et ce qui déclenche les tenues.
--
-- Fenêtre : la liste de tes tenues à gauche (case pour l'activer, ordre =
-- priorité), la fiche du personnage à droite. Clic sur un emplacement :
-- choisir la pièce (les objets à bonus en premier) ; clic droit : rien à
-- cet emplacement ; glisser un objet des sacs dessus : le prendre.
--
-- Déclencheurs : monture, nage, repos, instance (événements et minuteur),
-- fenêtre de métier, survol d'une plante, d'un filon ou d'un corps à
-- dépecer. Les noms des plantes et filons s'apprennent à chaque récolte
-- (SuperGuideDB.tenuesNoeuds) ; ceux que l'info-bulle nomme sont reconnus
-- tout de suite. Logique dans Core/Tenues.lua.

local ADDON, ns = ...

local Tenues = ns.Tenues
local L = ns.L or setmetatable({}, { __index = function(_, k) return k end })

local TenuesUI = {}
ns.TenuesUI = TenuesUI

local function T() return ns.Theme end
local function C() return ns.Controles end
local function R(cle) return ns.Reglages.get(cle) end

local LARGEUR, HAUTEUR, ENTETE = 720, 586, 54
local LISTE_L, LIGNE, VISIBLES = 224, 44, 8
local CASE = 40

local cadre, choisie, decalage = nil, nil, 0
local objets = {}          -- Jeu.objetsPortables(), relu à l'ouverture et quand les sacs changent
local rouvrir = false

local NOMS_CASES = {
    [1] = "HeadSlot", [2] = "NeckSlot", [3] = "ShoulderSlot", [4] = "ShirtSlot", [5] = "ChestSlot",
    [6] = "WaistSlot", [7] = "LegsSlot", [8] = "FeetSlot", [9] = "WristSlot", [10] = "HandsSlot",
    [11] = "Finger0Slot", [12] = "Finger1Slot", [13] = "Trinket0Slot", [14] = "Trinket1Slot",
    [15] = "BackSlot", [16] = "MainHandSlot", [17] = "SecondaryHandSlot", [18] = "RangedSlot", [19] = "TabardSlot",
}

local function fondCase(case)
    if GetInventorySlotInfo then
        local ok, _, tex = pcall(GetInventorySlotInfo, NOMS_CASES[case])
        if ok and tex then return tex end
    end
    return "Interface\\PaperDoll\\UI-Backpack-EmptySlot"
end

local function nomCase(case)
    local g = _G[NOMS_CASES[case]:upper()]
    return type(g) == "string" and g or NOMS_CASES[case]
end

local function icone(id)
    if C_Item and C_Item.GetItemIconByID then return C_Item.GetItemIconByID(id) end
    return GetItemIcon and GetItemIcon(id) or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function relire()
    local ok, l = pcall(ns.Jeu.objetsPortables)
    objets = ok and l or {}
end

local function tenue() return choisie and Tenues.parId(choisie) end

---------------------------------------------------------------------------
-- Petite liste de choix (nouvelle tenue, condition, pièce)
---------------------------------------------------------------------------

local menu
local function fermerMenu() if menu then menu:Hide(); menu.capteur:Hide() end end

-- entrees : { { texte, sous, icone, couleur, action } }
local function ouvrirMenu(ancre, entrees, largeur)
    local Th = T()
    if not menu then
        menu = CreateFrame("Frame", nil, UIParent)
        menu:SetFrameStrata("FULLSCREEN_DIALOG")
        menu:SetClampedToScreen(true)
        Th.fond(menu, "panneau", 0.99, "accent")
        menu.lignes = {}
        menu.capteur = CreateFrame("Button", nil, UIParent)
        menu.capteur:SetAllPoints(UIParent)
        menu.capteur:SetFrameStrata("FULLSCREEN")
        menu.capteur:SetScript("OnClick", fermerMenu)
        menu:EnableMouseWheel(true)
        menu:SetScript("OnMouseWheel", function(self, d)
            self.decalage = math.max(0, math.min(#self.entrees - #self.lignes, self.decalage - d))
            self.dessiner()
        end)
        function menu.dessiner()
            for i, l in ipairs(menu.lignes) do
                local e = menu.entrees[i + menu.decalage]
                l.entree = e
                l:SetShown(e ~= nil)
                if e then
                    l.texte:SetText(e.texte)
                    l.texte:SetTextColor(Th.rgb(e.couleur or "texte"))
                    l.sous:SetText(e.sous or "")
                    l.icone:SetTexture(e.icone)
                    l.icone:SetShown(e.icone ~= nil)
                    l.texte:SetPoint("LEFT", e.icone and 32 or 10, 0)
                end
            end
        end
    end
    largeur = largeur or 300
    local n = math.min(#entrees, 12)
    for i = #menu.lignes + 1, n do
        local l = CreateFrame("Button", nil, menu)
        l:SetHeight(26)
        local survol = l:CreateTexture(nil, "BACKGROUND")
        survol:SetAllPoints()
        survol:SetColorTexture(1, 1, 1, 0.06)
        survol:Hide()
        l.icone = l:CreateTexture(nil, "ARTWORK")
        l.icone:SetSize(20, 20)
        l.icone:SetPoint("LEFT", 6, 0)
        l.texte = C().texte(l, "texte", "texte")
        l.texte:SetWordWrap(false)
        l.sous = C().texte(l, "petit", "vert")
        l.sous:SetPoint("RIGHT", -10, 0)
        l.texte:SetPoint("RIGHT", l.sous, "LEFT", -6, 0)
        l:SetScript("OnEnter", function(self)
            survol:Show()
            local e = self.entree
            if e and e.lien then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(e.lien)
                GameTooltip:Show()
            end
        end)
        l:SetScript("OnLeave", function() survol:Hide(); GameTooltip:Hide() end)
        l:SetScript("OnClick", function(self)
            local e = self.entree
            fermerMenu()
            if e and e.action then e.action() end
        end)
        menu.lignes[i] = l
    end
    for i, l in ipairs(menu.lignes) do
        l:ClearAllPoints()
        l:SetPoint("TOPLEFT", 4, -4 - (i - 1) * 26)
        l:SetPoint("TOPRIGHT", -4, -4 - (i - 1) * 26)
        if i > n then l:Hide() end
    end
    menu.entrees, menu.decalage = entrees, 0
    menu:SetSize(largeur, n * 26 + 8)
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", ancre, "BOTTOMLEFT", 0, -4)
    menu.dessiner()
    menu.capteur:Show()
    menu:Show()
end

---------------------------------------------------------------------------
-- Dessin
---------------------------------------------------------------------------

local function sousTitre(t)
    local n = Tenues.nbPieces(t)
    local etat = Tenues.active() == t and ("|cff3fe07a" .. L["mise"] .. "|r · ") or ""
    return etat .. Tenues.texteCondition(t) .. " · " .. (n == 1 and L["1 pièce"] or L["%d pièces"]:format(n))
end

local function bonusDe(t, id)
    for _, o in ipairs(objets) do
        if o.id == id then return Tenues.bonus(o, Tenues.mots(t)) end
    end
end

local dessiner

local function dessinerListe()
    local Th = T()
    local l = Tenues.liste()
    decalage = math.max(0, math.min(decalage, #l - VISIBLES))
    for i, ligne in ipairs(cadre.lignes) do
        local t = l[i + decalage]
        ligne.tenue = t
        ligne:SetShown(t ~= nil)
        if t then
            ligne.nom:SetText(t.nom)
            ligne.sous:SetText(sousTitre(t))
            ligne.boite:SetTexture(Th.icone(t.actif and "case-cochee" or "case"))
            ligne.boite:SetVertexColor(Th.rgb(t.actif and "accent" or "texteDoux"))
            ligne.nom:SetTextColor(Th.rgb(t.actif and "texte" or "texteDoux"))
            local sel = t.id == choisie
            ligne.bord:SetVertexColor(Th.rgb(sel and "accent" or "bord"))
        end
    end
    cadre.vide:SetShown(#l == 0)
end

local function dessinerCase(b, t)
    local Th = T()
    local p = t and t.pieces and t.pieces[b.case]
    b.piece = p
    if p then
        b.icone:SetTexture(icone(p.id))
        b.icone:SetDesaturated(false)
        b.icone:SetAlpha(1)
        local a = Tenues.demo or ns.Jeu.possede(p.id)
        b.bord:SetVertexColor(Th.rgb(not a and "rouge" or p.epingle and "orange" or "accent"))
        local bonus = p.bonus or bonusDe(t, p.id)
        b.bonus:SetText(bonus and bonus > 1 and ("+" .. bonus) or "")
    else
        b.icone:SetTexture(fondCase(b.case))
        b.icone:SetDesaturated(true)
        b.icone:SetAlpha(t and t.vides and t.vides[b.case] and 0.15 or 0.35)
        b.bord:SetVertexColor(Th.rgb("bordFort"))
        b.bonus:SetText("")
    end
end

dessiner = function()
    TenuesUI.nommerTouches()
    if not (cadre and cadre:IsShown()) then return end
    local Th = T()
    local liste = Tenues.liste()
    if choisie and not Tenues.parId(choisie) then choisie = nil end
    if not choisie and liste[1] then choisie = liste[1].id end
    dessinerListe()
    local t = tenue()
    cadre.droite:SetShown(t ~= nil)
    cadre.accueil:SetShown(t == nil)
    if not t then return end
    cadre.nom:SetText(t.nom)
    if cadre.suppr.arme and cadre.suppr.arme ~= t.id then TenuesUI.desarmer() end
    cadre.quand.texte:SetText(L["Quand : %s"]:format(Tenues.texteCondition(t)))
    local ty = Tenues.type(t.type)
    -- Cible ou zone : un bouton pour prendre la tienne.
    local prendreQuoi = (t.quand == "cible" and "cible") or (t.quand == "zone" and "zone") or nil
    cadre.prendre:SetShown(prendreQuoi ~= nil)
    cadre.prendre.quoi = prendreQuoi
    cadre.prendre.texte:SetText(prendreQuoi == "cible" and L["Prendre ma cible"] or L["Prendre ma zone"])
    cadre.aide:ClearAllPoints()
    cadre.aide:SetPoint("LEFT", prendreQuoi and cadre.prendre or cadre.quand, "RIGHT", 10, 0)
    cadre.aide:SetPoint("RIGHT", cadre.droite, "RIGHT", 0, 0)
    cadre.aide:SetText(ty and ty.aide or "")
    for _, b in ipairs(cadre.cases) do dessinerCase(b, t) end
    local mise = Tenues.active() == t
    cadre.mettre.texte:SetText(t.force and L["Retirer"] or L["Mettre maintenant"])
    local n = Tenues.nbPieces(t)
    local lignes = {}
    lignes[#lignes + 1] = mise and ("|cff3fe07a" .. L["Portée en ce moment."] .. "|r") or L["Pas portée en ce moment."]
    if n == 0 then
        lignes[#lignes + 1] = "|cffffb84a" .. (Tenues.type(t.type) and Tenues.type(t.type).mots
            and L["Aucun objet à bonus dans tes sacs pour l'instant : la tenue se remplira toute seule dès que tu en auras un."]
            or L["Choisis les pièces : clic sur un emplacement, ou « Prendre ce que je porte »."]) .. "|r"
    end
    local manque = 0
    for _, p in pairs(t.pieces or {}) do if not (Tenues.demo or ns.Jeu.possede(p.id)) then manque = manque + 1 end end
    if manque > 0 then lignes[#lignes + 1] = "|cffff5a5f" .. L["%d pièce(s) introuvable(s) : ni sur toi ni dans tes sacs."]:format(manque) .. "|r" end
    cadre.resume:SetText(table.concat(lignes, "\n"))
end

TenuesUI.dessiner = function() pcall(dessiner) end

-- Après une modification : la tenue portée se met à jour, la fenêtre aussi.
local function apres(t)
    if t and Tenues.active() == t then Tenues.evaluer(true) else Tenues.evaluer() end
    dessiner()
end

---------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------

local function nouvelle(ancre)
    local entrees = {}
    local metiers = ns.Jeu.metiers()
    local function connu(ty) return Tenues.connu(metiers, ty) end
    for _, ty in ipairs(Tenues.TYPES) do
        local metier = (ty.recolte or ty.metier) and connu(ty) or nil
        if not (ty.recolte or ty.metier) or metier then
            local trouve
            if ty.mots then
                local essai = { type = ty.cle, metier = metier, pieces = {} }
                Tenues.remplir(essai, objets)
                trouve = Tenues.nbPieces(essai)
            end
            entrees[#entrees + 1] = {
                texte = metier or ty.nom,
                sous = trouve and trouve > 0 and L["%d trouvée(s)"]:format(trouve) or nil,
                couleur = trouve and trouve > 0 and "texte" or "texteDoux",
                action = function()
                    local t = Tenues.creer(ty.cle, objets, metier)
                    choisie = t.id
                    decalage = 0
                    apres(t)
                end,
            }
        end
    end
    entrees[#entrees + 1] = { texte = L["Pêche : Auto Fishing s'en charge"], couleur = "textePale" }
    ouvrirMenu(ancre, entrees, LISTE_L + 60)
end

local function choisirQuand(ancre)
    local t = tenue()
    if not t then return end
    local entrees = {}
    for _, c in ipairs(Tenues.CONDITIONS) do
        entrees[#entrees + 1] = { texte = c.nom, couleur = c.cle == t.quand and "accent" or "texte",
            action = function()
                t.quand = c.cle
                -- Proposé, pas imposé : ta cible ou ta zone actuelle, à changer d'un clic.
                if c.cle == "cible" and not t.cible then t.cible = ns.Jeu.cibleNom() end
                if c.cle == "zone" and not t.zone then t.zone = ns.Jeu.zones() end
                apres(t)
            end }
    end
    ouvrirMenu(ancre, entrees, 280)
end

local function prendre(b, o)
    local t = tenue()
    if not t then return end
    Tenues.choisir(t, b.case, o)
    apres(t)
end

local function choisirPiece(b)
    local t = tenue()
    if not t then return end
    local entrees = {
        { texte = L["Automatique (meilleur bonus)"], couleur = "accent",
          action = function() Tenues.liberer(t, b.case); Tenues.remplir(t, objets); apres(t) end },
        { texte = L["Ne rien changer ici"], couleur = "texteDoux", action = function() prendre(b, nil) end },
    }
    local vus = {}
    for _, c in ipairs(Tenues.candidats(t, b.case, objets)) do
        local o = c.objet
        if not vus[o.id] then
            vus[o.id] = true
            entrees[#entrees + 1] = { texte = o.lien, lien = o.lien, icone = o.icone,
                sous = c.bonus and ("+" .. c.bonus) or (o.porte and L["porté"] or nil),
                action = function() prendre(b, o) end }
        end
    end
    if #entrees == 2 then entrees[#entrees + 1] = { texte = L["Rien pour cet emplacement dans tes sacs."], couleur = "textePale" } end
    ouvrirMenu(b, entrees, 320)
end

-- Objet tenu par la souris (glissé depuis les sacs) déposé sur une case.
local function deposer(b)
    if not GetCursorInfo then return false end
    local genre, id, lien = GetCursorInfo()
    if genre ~= "item" or not id then return false end
    local _, _, _, loc = C_Item.GetItemInfoInstant(id)
    local cases = ns.Jeu.CASES_TYPE[loc] or {}
    local va = false
    for _, c in ipairs(cases) do if c == b.case then va = true end end
    ClearCursor()
    if not va then
        ns.Jeu.message(L["Auto Sets : cet objet ne va pas à cet emplacement."])
        return true
    end
    prendre(b, { id = id, lien = lien })
    return true
end

---------------------------------------------------------------------------
-- Construction
---------------------------------------------------------------------------

-- Petit bouton carré avec le chevron, tourné (rotation en radians).
local function chevron(parent, rotation, rappel)
    local Th = T()
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(26, 24)
    local _, bord = Th.fond(b, "flot", 1, "bordFort")
    local ic = b:CreateTexture(nil, "ARTWORK")
    ic:SetTexture(Th.icone("suivant"))
    ic:SetSize(12, 12)
    ic:SetPoint("CENTER")
    ic:SetVertexColor(Th.rgb("texteDoux"))
    if ic.SetRotation then ic:SetRotation(rotation) end
    b:SetScript("OnEnter", function() bord:SetVertexColor(Th.rgb("accent")) end)
    b:SetScript("OnLeave", function() bord:SetVertexColor(Th.rgb("bordFort")) end)
    b:SetScript("OnClick", rappel)
    return b
end

local function creerLigne(i)
    local Th = T()
    local l = CreateFrame("Button", nil, cadre.gauche)
    l:SetSize(LISTE_L, LIGNE - 4)
    l:SetPoint("TOPLEFT", 0, -28 - (i - 1) * LIGNE)
    local _, bord = Th.fond(l, "flot", 1, "bord")
    l.bord = bord
    l.boite = l:CreateTexture(nil, "ARTWORK")
    l.boite:SetSize(16, 16)
    l.boite:SetPoint("LEFT", 10, 0)
    local actif = CreateFrame("Button", nil, l)
    actif:SetSize(30, LIGNE - 4)
    actif:SetPoint("LEFT")
    actif:SetScript("OnClick", function()
        local t = l.tenue
        if not t then return end
        t.actif = not t.actif
        apres(t)
    end)
    C().infobulle(actif, L["Activer cette tenue"], L["Décochée : elle ne se met plus toute seule (le bouton « Mettre maintenant » marche toujours)."])
    l.nom = C().texte(l, "texte", "texte")
    l.nom:SetPoint("TOPLEFT", 34, -6)
    l.nom:SetPoint("RIGHT", -8, 0)
    l.nom:SetWordWrap(false)
    l.sous = C().texte(l, "petit", "textePale")
    l.sous:SetPoint("BOTTOMLEFT", 34, 6)
    l.sous:SetPoint("RIGHT", -8, 0)
    l.sous:SetWordWrap(false)
    l:SetScript("OnClick", function(self)
        if self.tenue then choisie = self.tenue.id; dessiner() end
    end)
    return l
end

local function creerCase(case, x, y)
    local Th = T()
    local b = CreateFrame("Button", nil, cadre.droite)
    b:SetSize(CASE, CASE)
    b:SetPoint("TOPLEFT", x, y)
    b.case = case
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local _, bord = Th.fond(b, "sombre", 1, "bordFort")
    b.bord = bord
    b.icone = b:CreateTexture(nil, "ARTWORK")
    b.icone:SetPoint("TOPLEFT", 3, -3)
    b.icone:SetPoint("BOTTOMRIGHT", -3, 3)
    b.icone:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.bonus = C().texte(b, "petit", "vert")
    b.bonus:SetPoint("BOTTOMRIGHT", -2, 2)
    b:SetScript("OnClick", function(self, bouton)
        if deposer(self) then return end
        if bouton == "RightButton" then prendre(self, nil) else choisirPiece(self) end
    end)
    b:SetScript("OnReceiveDrag", function(self) deposer(self) end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local p = self.piece
        if p and p.lien then
            GameTooltip:SetHyperlink(p.lien)
            GameTooltip:AddLine(" ")
            if not ns.Jeu.possede(p.id) then
                GameTooltip:AddLine(L["Introuvable : ni sur toi ni dans tes sacs."], 1, 0.35, 0.37, true)
            end
            GameTooltip:AddLine(p.epingle and L["Choisie à la main."] or L["Choisie pour toi : le meilleur bonus que tu as."], 0.31, 0.85, 1, true)
        else
            GameTooltip:SetText(nomCase(self.case), 1, 1, 1)
            GameTooltip:AddLine(L["Rien ne change à cet emplacement."], 0.6, 0.64, 0.7, true)
        end
        GameTooltip:AddLine(L["Clic : choisir · Clic droit : rien ici · Glisse un objet de tes sacs dessus."], 0.43, 0.47, 0.54, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

local function creer()
    local Th = T()
    cadre = CreateFrame("Frame", "SuperGuideTenues", UIParent)
    cadre:SetSize(LARGEUR, HAUTEUR)
    cadre:SetFrameStrata("DIALOG")
    cadre:SetClampedToScreen(true)
    cadre:EnableMouse(true)
    Th.fond(cadre, "panneau", 0.98, "bordFort")
    if UISpecialFrames then table.insert(UISpecialFrames, "SuperGuideTenues") end
    cadre:SetScript("OnHide", fermerMenu)

    -- Bandeau de la marque, comme partout.
    local bandeau = CreateFrame("Frame", nil, cadre)
    bandeau:SetPoint("TOPLEFT")
    bandeau:SetPoint("TOPRIGHT")
    bandeau:SetHeight(ENTETE)
    local b = C().marque(bandeau, bandeau, 10)
    b.logo:SetPoint("LEFT", 18, 0)
    local titre = C().texte(bandeau, "texte", "textePale")
    titre:SetPoint("LEFT", b.qol, "RIGHT", 10, 1)
    titre:SetText("·  Auto Sets")
    local fermer = C().bouton(bandeau, "X", "texteDoux", function() cadre:Hide() end, 24)
    fermer:SetPoint("RIGHT", -12, 0)
    fermer:SetFrameLevel(bandeau:GetFrameLevel() + 5)
    local sep = Th.separateur(cadre)
    sep:SetPoint("TOPLEFT", 1, -ENTETE)
    sep:SetPoint("TOPRIGHT", -1, -ENTETE)

    -- Gauche : la liste.
    cadre.gauche = CreateFrame("Frame", nil, cadre)
    cadre.gauche:SetPoint("TOPLEFT", 16, -ENTETE - 14)
    cadre.gauche:SetSize(LISTE_L, HAUTEUR - ENTETE - 30)
    local mes = C().texte(cadre.gauche, "petit", "textePale")
    mes:SetPoint("TOPLEFT", 2, -4)
    mes:SetWidth(LISTE_L - 4)
    mes:SetWordWrap(false)
    mes:SetText(L["MES TENUES · par priorité"])
    cadre.lignes = {}
    for i = 1, VISIBLES do cadre.lignes[i] = creerLigne(i) end
    cadre.vide = C().texte(cadre.gauche, "texte", "texteDoux")
    cadre.vide:SetPoint("TOPLEFT", 4, -40)
    cadre.vide:SetWidth(LISTE_L - 8)
    cadre.vide:SetText(L["Pas encore de tenue. Crée la première ci-dessous : les objets se trouvent tout seuls."])
    cadre.gauche:EnableMouseWheel(true)
    cadre.gauche:SetScript("OnMouseWheel", function(_, d)
        decalage = decalage - d
        dessinerListe()
    end)
    local plus = C().bouton(cadre.gauche, "+ " .. L["Nouvelle tenue"], "accent", function(self) nouvelle(self) end, LISTE_L)
    plus:SetPoint("BOTTOMLEFT", 0, 0)
    plus.texte:SetTextColor(Th.rgb("accent"))

    -- Droite : la tenue choisie.
    local X0 = 16 + LISTE_L + 20
    local W = LARGEUR - X0 - 16
    cadre.droite = CreateFrame("Frame", nil, cadre)
    cadre.droite:SetPoint("TOPLEFT", X0, -ENTETE - 14)
    cadre.droite:SetSize(W, HAUTEUR - ENTETE - 30)
    local d = cadre.droite
    cadre.nom = C().texte(d, "titre", "texte")
    cadre.nom:SetPoint("TOPLEFT", 0, -2)
    cadre.nom:SetWidth(W - 190)
    cadre.nom:SetWordWrap(false)
    -- Deux clics : le premier arme le bouton (rouge, 4 secondes), le second supprime.
    local suppr
    -- Armé : bouton plein rouge, texte blanc, plus large ; on ne peut pas le rater.
    local function desarmer()
        suppr.arme = nil
        suppr.texte:SetText(L["Supprimer"])
        suppr.texte:SetTextColor(T().rgb("rouge"))
        suppr.plein:Hide()
        suppr:SetWidth(90)
    end
    local function armer(id)
        suppr.arme = id
        suppr.texte:SetText(L["Oui, supprimer"])
        suppr.texte:SetTextColor(1, 1, 1)
        suppr.plein:Show()
        suppr:SetWidth(130)
    end
    TenuesUI.desarmer = function() if suppr then desarmer() end end
    suppr = C().bouton(d, L["Supprimer"], "rouge", function(self)
        local t = tenue()
        if not t then return end
        if self.arme ~= t.id then
            armer(t.id)
            ns.Jeu.plusTard(4, function() if suppr.arme == t.id then desarmer() end end)
            return
        end
        desarmer()
        if Tenues.active() == t then t.actif = false; t.force = nil; Tenues.evaluer(true) end
        Tenues.supprimer(t.id)
        choisie = nil
        dessiner()
    end, 90)
    suppr:SetPoint("TOPRIGHT", 0, 0)
    suppr.plein = suppr:CreateTexture(nil, "BORDER")
    suppr.plein:SetPoint("TOPLEFT", 1, -1)
    suppr.plein:SetPoint("BOTTOMRIGHT", -1, 1)
    suppr.plein:SetColorTexture(0.85, 0.16, 0.18, 1)
    suppr.plein:Hide()
    C().infobulle(suppr, L["Supprimer"], L["Deux clics : le premier demande confirmation (le bouton devient rouge), le second supprime."])
    cadre.suppr = suppr
    local bas = chevron(d, -math.pi / 2, function()
        local t = tenue(); if t then Tenues.deplacer(t.id, 1); apres(t) end
    end)
    bas:SetPoint("RIGHT", suppr, "LEFT", -6, 0)
    C().infobulle(bas, L["Priorité"], L["Plus bas dans la liste : passe après les autres tenues."])
    local haut = chevron(d, math.pi / 2, function()
        local t = tenue(); if t then Tenues.deplacer(t.id, -1); apres(t) end
    end)
    haut:SetPoint("RIGHT", bas, "LEFT", -4, 0)
    C().infobulle(haut, L["Priorité"], L["Plus haut dans la liste : passe avant les autres tenues quand deux conviennent (en selle dans l'eau…)."])

    cadre.quand = C().bouton(d, "", "accent", function(self) choisirQuand(self) end, 300)
    cadre.quand:SetPoint("TOPLEFT", 0, -34)
    cadre.quand.texte:SetTextColor(Th.rgb("accent"))
    local fleche = cadre.quand:CreateTexture(nil, "ARTWORK")
    fleche:SetTexture(Th.icone("suivant"))
    fleche:SetSize(10, 10)
    fleche:SetPoint("RIGHT", -10, 0)
    fleche:SetVertexColor(Th.rgb("accent"))
    if fleche.SetRotation then fleche:SetRotation(-math.pi / 2) end
    C().infobulle(cadre.quand, L["Quand la mettre"], L["La tenue se met toute seule dans ce cas, et ton équipement revient ensuite."])
    cadre.prendre = C().bouton(d, L["Prendre ma cible"], "texte", function(self)
        local t = tenue()
        if not t then return end
        if self.quoi == "cible" then
            local nom = ns.Jeu.cibleNom()
            if not nom then ns.Jeu.message(L["Auto Sets : cible d'abord le boss ou la créature."]); return end
            t.cible = nom
        else
            local zone, sous = ns.Jeu.zones()
            t.zone = sous or zone
        end
        apres(t)
    end, 130)
    cadre.prendre:SetPoint("LEFT", cadre.quand, "RIGHT", 8, 0)
    C().infobulle(cadre.prendre, L["Prendre"], L["Cible : le nom de ta cible actuelle (un boss, une créature). Zone : là où tu es (la sous-zone si tu es dans une, sinon la zone)."])
    cadre.aide = C().texte(d, "petit", "textePale")
    cadre.aide:SetPoint("LEFT", cadre.quand, "RIGHT", 10, 0)
    cadre.aide:SetPoint("RIGHT", d, "RIGHT", 0, 0)
    cadre.aide:SetWordWrap(false)

    -- Fiche du personnage : deux colonnes, les armes en bas.
    cadre.cases = {}
    local y0, pas = -74, CASE + 6
    for i, case in ipairs(Tenues.GAUCHE) do
        cadre.cases[#cadre.cases + 1] = creerCase(case, 0, y0 - (i - 1) * pas)
    end
    for i, case in ipairs(Tenues.DROITE) do
        cadre.cases[#cadre.cases + 1] = creerCase(case, W - CASE, y0 - (i - 1) * pas)
    end
    local yb = y0 - 8 * pas - 4
    local xb = (W - 3 * CASE - 2 * 8) / 2
    for i, case in ipairs(Tenues.BAS) do
        cadre.cases[#cadre.cases + 1] = creerCase(case, xb + (i - 1) * (CASE + 8), yb)
    end

    -- Centre : où en est la tenue, et ce qu'on peut faire.
    local mil = CreateFrame("Frame", nil, d)
    mil:SetPoint("TOPLEFT", CASE + 18, y0)
    mil:SetPoint("BOTTOMRIGHT", d, "TOPRIGHT", -CASE - 18, yb + 10)
    Th.fond(mil, "flot", 0.6, "bord")
    cadre.resume = C().texte(mil, "texte", "texteDoux")
    cadre.resume:SetPoint("TOPLEFT", 14, -14)
    cadre.resume:SetPoint("RIGHT", -14, 0)
    cadre.resume:SetSpacing(4)
    local LB = W - 2 * (CASE + 18) - 28
    cadre.mettre = C().bouton(mil, L["Mettre maintenant"], "accent", function()
        local t = tenue()
        if t then Tenues.basculer(t.id); dessiner() end
    end, LB)
    cadre.mettre:SetPoint("BOTTOM", 0, 92)
    cadre.mettre.texte:SetTextColor(Th.rgb("accent"))
    C().infobulle(cadre.mettre, L["Mettre maintenant"], L["La tenue est mise tout de suite et reste jusqu'à ce que tu la retires, quelles que soient les conditions."])
    local proposer = C().bouton(mil, L["Proposer les objets"], "texte", function()
        local t = tenue()
        if not t then return end
        relire()
        t.pieces, t.vides = {}, nil
        Tenues.remplir(t, objets)
        apres(t)
    end, LB)
    proposer:SetPoint("BOTTOM", 0, 56)
    C().infobulle(proposer, L["Proposer les objets"], L["Oublie tes choix et reprend, pour chaque emplacement, l'objet au meilleur bonus de tes sacs et de ton équipement."])
    local porte = C().bouton(mil, L["Prendre ce que je porte"], "texte", function()
        local t = tenue()
        if not t then return end
        Tenues.prendrePorte(t)
        apres(t)
    end, LB)
    porte:SetPoint("BOTTOM", 0, 20)
    C().infobulle(porte, L["Prendre ce que je porte"], L["Toute ta tenue actuelle devient celle-ci (pratique pour une tenue de ville ou de champ de bataille). Vide ensuite les emplacements à ne pas toucher (clic droit)."])

    local astuce = C().texte(cadre, "petit", "textePale")
    astuce:SetPoint("BOTTOMLEFT", X0, 14)
    astuce:SetPoint("RIGHT", -16, 0)
    astuce:SetText(L["Bord bleu : choisie pour toi · orange : choisie à la main · rouge : introuvable."])

    -- Aucune tenue choisie : quelques mots.
    cadre.accueil = C().texte(cadre, "texte", "texteDoux")
    cadre.accueil:SetPoint("TOPLEFT", X0, -ENTETE - 40)
    cadre.accueil:SetPoint("RIGHT", -24, 0)
    cadre.accueil:SetSpacing(5)
    cadre.accueil:SetText(L["Une tenue se met toute seule au bon moment : la Carotte au bout d'un bâton en selle, tes gants d'herboriste au survol d'une plante, ton tablier à la forge… puis ton équipement revient."]
        .. "\n\n" .. L["Crée une tenue à gauche : les objets à bonus de tes sacs sont trouvés pour toi. Tu peux ensuite changer chaque pièce."])

    cadre:Hide()
    if ns.Deplacement then
        ns.Deplacement.inscrire(cadre, "Auto Sets", "tenues", { "CENTER", 0, 30 }, true)
    end
    -- Le bandeau (logo qui tourne au survol) et les panneaux prennent la
    -- souris : glisser dessus déplace la fenêtre.
    for _, zone in ipairs({ bandeau, cadre.gauche, cadre.droite }) do
        zone:EnableMouse(true)
        zone:RegisterForDrag("LeftButton")
        zone:SetScript("OnDragStart", function()
            local f = cadre:GetScript("OnDragStart")
            if f then f(cadre) end
        end)
        zone:SetScript("OnDragStop", function()
            local f = cadre:GetScript("OnDragStop")
            if f then f(cadre) end
        end)
    end
end

function TenuesUI.ouvrir()
    if ns.Jeu.enCombat() then
        ns.Jeu.message(L["Auto Sets : pas pendant un combat."])
        return
    end
    if not cadre then creer() end
    if ns.Menu and ns.Menu.ouvert and ns.Menu.ouvert() then ns.Menu.fermer() end
    relire()
    cadre:Show()
    dessiner()
end

-- Mode photo : la vraie fenêtre, remplie de tenues d'exemple. Tes tenues
-- sont mises de côté le temps de la photo et rien ne s'équipe (Tenues.demo).
local gardees
function TenuesUI.exemple(oui)
    SuperGuideCharDB = SuperGuideCharDB or {}
    if not oui then
        if gardees then
            SuperGuideCharDB.tenues, SuperGuideCharDB.tenuesEtat = gardees.tenues, gardees.etat
            gardees = nil
        end
        Tenues.demo = false
        choisie = nil
        if cadre then
            cadre:Hide()
            if ns.Deplacement then ns.Deplacement.replacer("tenues") end
        end
        return cadre
    end
    if not cadre then creer() end
    gardees = gardees or { tenues = SuperGuideCharDB.tenues, etat = SuperGuideCharDB.tenuesEtat }
    Tenues.demo = true
    -- Pièces de ton personnage (icônes sûres), plus la Cape d'écailles d'Onyxia.
    local feu = {}
    local res = { [1] = 12, [3] = 10, [5] = 15, [7] = 12, [10] = 8, [8] = 10 }
    for case, b in pairs(res) do
        local id = ns.Jeu.idPiece(case)
        if id then feu[case] = { id = id, lien = ns.Jeu.lienPiece(case), bonus = b } end
    end
    feu[15] = { id = 15138, lien = "item:15138", bonus = 15 }
    SuperGuideCharDB.tenues = {
        { id = 1, type = "monture", nom = L["Monture"], quand = "monture", actif = true,
          pieces = { [13] = { id = 11122, lien = "item:11122", bonus = 3 } } },
        { id = 2, type = "boss", nom = "Ragnaros", quand = "cible", cible = "Ragnaros", actif = true, pieces = feu },
        { id = 3, type = "herbes", nom = L["Herboristerie"], quand = "herbes", actif = true,
          pieces = { [10] = { id = 7349, lien = "item:7349", bonus = 5 } } },
        { id = 4, type = "zone", nom = "Stratholme", quand = "zone", zone = "Stratholme", actif = true,
          pieces = { [14] = { id = 12846, lien = "item:12846" } } },
        { id = 5, type = "depecage", nom = L["Dépeçage"], quand = "depecage", actif = true,
          pieces = { [16] = { id = 12709, lien = "item:12709", bonus = 10 } } },
        { id = 6, type = "ville", nom = L["En ville"], quand = "ville", actif = false,
          pieces = { [4] = { id = 6833, lien = "item:6833" }, [19] = { id = 15196, lien = "item:15196" } } },
    }
    SuperGuideCharDB.tenuesEtat = { active = 1 }
    choisie, decalage = 2, 0
    cadre:Show()
    dessiner()
    return cadre
end

function TenuesUI.basculer()
    if cadre and cadre:IsShown() then cadre:Hide() else TenuesUI.ouvrir() end
end

---------------------------------------------------------------------------
-- Déclencheurs
---------------------------------------------------------------------------

-- Sorts de récolte (n'importe quel rang, par leur nom) : la cible apprise.
local RECOLTE = { [2366] = "herbes", [2575] = "minage", [8613] = "depecage" }
local nomsRecolte
local function categorieSort(id)
    if not nomsRecolte then
        nomsRecolte = {}
        local nom = (C_Spell and C_Spell.GetSpellName) or (GetSpellInfo and function(i) return (GetSpellInfo(i)) end)
        for sid, cat in pairs(RECOLTE) do
            local n = nom and nom(sid)
            if n then nomsRecolte[n] = cat end
        end
    end
    if RECOLTE[id] then return RECOLTE[id] end
    local nom = (C_Spell and C_Spell.GetSpellName) and C_Spell.GetSpellName(id) or (GetSpellInfo and GetSpellInfo(id))
    return nom and nomsRecolte[nom]
end

local function noeuds()
    SuperGuideDB = SuperGuideDB or {}
    SuperGuideDB.tenuesNoeuds = SuperGuideDB.tenuesNoeuds or {}
    return SuperGuideDB.tenuesNoeuds
end

local function recolteVue(cat)
    -- Seulement si une tenue de ce genre est active : rien à faire sinon.
    local utile = false
    for _, t in ipairs(Tenues.liste()) do
        if t.actif and t.quand == cat and Tenues.nbPieces(t) > 0 then utile = true end
    end
    if not utile then return end
    Tenues.noterRecolte(cat, GetTime())
    Tenues.evaluer()
end

-- Mots du métier dans les info-bulles (« Herboristerie », « Requiert Minage »),
-- dans la langue du jeu (Tenues.motsType).
local function motsNoeud()
    return { herbes = Tenues.motsType(Tenues.type("herbes")), minage = Tenues.motsType(Tenues.type("minage")) }
end

local function surInfobulle(tip)
    if not R("tenuesActif") then return end
    local ok, _, unite = pcall(tip.GetUnit, tip)
    if ok and unite then
        if not (UnitIsDead and UnitIsDead(unite)) then return end
        for i = 2, tip:NumLines() or 0 do
            local l = _G[tip:GetName() .. "TextLeft" .. i]
            local txt = l and ns.Jeu.lisible(l:GetText())
            if txt then
                if txt == UNIT_SKINNABLE_LEATHER then return recolteVue("depecage") end
                if txt == UNIT_SKINNABLE_HERB then return recolteVue("herbes") end
                if txt == UNIT_SKINNABLE_ROCK then return recolteVue("minage") end
            end
        end
        return
    end
    local l1 = _G[tip:GetName() .. "TextLeft1"]
    local nom = l1 and ns.Jeu.lisible(l1:GetText())
    if not nom then return end
    local connu = noeuds()[nom]
    if connu then return recolteVue(connu) end
    for i = 2, math.min(tip:NumLines() or 0, 4) do
        local l = _G[tip:GetName() .. "TextLeft" .. i]
        local txt = l and ns.Jeu.lisible(l:GetText())
        if txt then
            txt = txt:lower()
            for cat, mots in pairs(motsNoeud()) do
                for _, m in ipairs(mots) do
                    if type(m) == "string" and txt:find(m, 1, true) then
                        noeuds()[nom] = cat
                        return recolteVue(cat)
                    end
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Propositions (jamais rien sans toi) : petite fenêtre « Ajouter / Non
-- merci », dans la file commune avec Auto Equip et la Poubelle.
---------------------------------------------------------------------------

local prop, propCourante

local function fermerProp()
    propCourante = nil
    if prop then prop:Hide() end
end

local function afficherProp(p)
    propCourante = p
    local Th = T()
    if p.creer then
        prop.titre:SetText(L["Auto Sets : créer une tenue « %s » ?"]:format(p.nom))
        prop.valeur:SetText((p.n > 1 and L["%d pièces trouvées"]:format(p.n) or L["1 pièce trouvée"])
            .. " · " .. Tenues.nomCondition(Tenues.type(p.creer).quand))
        prop.oui.texte:SetText(L["Créer"])
    else
        prop.titre:SetText(L["Auto Sets : mieux pour ta tenue « %s »"]:format(p.tenue.nom))
        local avant = p.avant and p.avant.lien
        prop.valeur:SetText(avant and L["+%d au lieu de +%d (%s)"]:format(p.bonus, p.bonusAvant or 0, avant)
            or L["+%d · emplacement vide jusqu'ici"]:format(p.bonus))
        prop.oui.texte:SetText(L["Ajouter"])
    end
    prop.oui.texte:SetTextColor(Th.rgb("accent"))
    prop.icone:SetTexture(p.objet.icone or "Interface\\Icons\\INV_Misc_QuestionMark")
    prop.nom:SetText(p.objet.lien)
    local texte = math.max(prop.nom:GetStringWidth() or 0, prop.valeur:GetStringWidth() or 0)
    local l = math.max((prop.titre:GetStringWidth() or 0) + 20, 46 + texte + 12 + 200)
    prop:SetWidth(math.min(520, math.ceil(l)))
    prop.nom:SetWidth(prop:GetWidth() - 46 - 206)
    prop.valeur:SetWidth(prop:GetWidth() - 46 - 206)
    prop.jusqua = (GetTime and GetTime() or 0) + 40
    prop:Show()
end

local function creerProp()
    local Th = T()
    prop = CreateFrame("Frame", "SuperGuideTenuesProposition", UIParent)
    prop:SetSize(380, 74)
    prop:SetFrameStrata("DIALOG")
    prop:SetClampedToScreen(true)
    Th.fond(prop, "panneau", 0.96, "bordFort")
    prop.titre = C().texte(prop, "petit", "accent")
    prop.titre:SetPoint("TOPLEFT", 10, -8)
    prop.icone = prop:CreateTexture(nil, "ARTWORK")
    prop.icone:SetSize(28, 28)
    prop.icone:SetPoint("TOPLEFT", 10, -26)
    prop.icone:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    prop.nom = C().texte(prop, "petit", "texte")
    prop.nom:SetPoint("TOPLEFT", prop.icone, "TOPRIGHT", 8, -1)
    prop.nom:SetWordWrap(false)
    prop.valeur = C().texte(prop, "petit", "texteDoux")
    prop.valeur:SetPoint("TOPLEFT", prop.nom, "BOTTOMLEFT", 0, -3)
    prop.valeur:SetWordWrap(false)
    local plusTard = C().bouton(prop, "X", "texteDoux", fermerProp, 24)
    plusTard:SetPoint("BOTTOMRIGHT", -8, 10)
    C().infobulle(plusTard, L["Plus tard"], L["Fermer sans choisir : ce sera reproposé plus tard."])
    local non = C().bouton(prop, L["Non merci"], "texteDoux", function()
        local p = propCourante
        fermerProp()
        if p then Tenues.refuser(p) end
    end, 86)
    non:SetPoint("RIGHT", plusTard, "LEFT", -6, 0)
    C().infobulle(non, L["Non merci"], L["Cette idée ne sera plus proposée."])
    prop.oui = C().bouton(prop, L["Ajouter"], "accent", function()
        local p = propCourante
        fermerProp()
        if not p then return end
        local t = Tenues.accepter(p, objets)
        ns.Jeu.message(L["Auto Sets : c'est noté (%s). /sg tenues pour la régler."]:format(t.nom))
        Tenues.evaluer(Tenues.active() == t)
        dessiner()
    end, 80)
    prop.oui:SetPoint("RIGHT", non, "LEFT", -6, 0)
    prop:SetScript("OnUpdate", function(self)
        if self.jusqua and (GetTime and GetTime() or 0) > self.jusqua then fermerProp() end
    end)
    local enAttente = C().texte(prop, "petit", "accent")
    enAttente:SetPoint("BOTTOMLEFT", 10, 6)
    ns.File.ecouter(function()
        local n = ns.File.enAttente()
        enAttente:SetText(n > 0 and L["+%d en attente"]:format(n) or "")
    end)
    prop:SetScript("OnHide", function() ns.File.fini("tenues") end)
    prop:Hide()
    if ns.Deplacement then
        ns.Deplacement.inscrire(prop, L["Proposition Auto Sets"], "tenuesProposition", { "TOP", 0, -260 })
    end
end

-- Idées montrées une seule fois par session (le X les remet à plus tard).
local montrees = {}

-- Relecture des sacs au plus toutes les deux secondes, hors combat : la
-- tenue portée suit ses pièces, et la première idée nouvelle est proposée.
local relectureEnAttente = false
local function actualiser()
    if relectureEnAttente then return end
    relectureEnAttente = true
    ns.Jeu.plusTard(2, function()
        relectureEnAttente = false
        if ns.Jeu.enCombat() or Tenues.demo then return end
        relire()
        Tenues.evaluer()
        dessiner()
        if not (R("tenuesActif") and prop) or propCourante then return end
        for _, p in ipairs(Tenues.propositions(objets, ns.Jeu.metiers())) do
            if not montrees[p.cle] then
                montrees[p.cle] = true
                ns.File.demander("tenues", function() afficherProp(p) end)
                return
            end
        end
    end)
end
TenuesUI.actualiser = actualiser

local EVALUER = {
    PLAYER_MOUNT_DISPLAY_CHANGED = true, PLAYER_UPDATE_RESTING = true, ZONE_CHANGED_NEW_AREA = true,
    ZONE_CHANGED = true, ZONE_CHANGED_INDOORS = true, PLAYER_TARGET_CHANGED = true,
    PLAYER_REGEN_ENABLED = true, PLAYER_ALIVE = true, PLAYER_UNGHOST = true,
    UNIT_SPELLCAST_STOP = true, UNIT_SPELLCAST_SUCCEEDED = true, UNIT_SPELLCAST_FAILED = true,
    UNIT_SPELLCAST_INTERRUPTED = true, UNIT_SPELLCAST_CHANNEL_STOP = true,
}

local f = CreateFrame("Frame")
local function inscrire(e) pcall(f.RegisterEvent, f, e) end
TenuesUI.EVENEMENTS = { "PLAYER_ENTERING_WORLD", "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED",
    "TRADE_SKILL_SHOW", "TRADE_SKILL_CLOSE", "CRAFT_SHOW", "CRAFT_CLOSE", "UNIT_SPELLCAST_SENT",
    "PLAYER_SOFT_INTERACT_CHANGED", "PLAYER_REGEN_DISABLED" }

-- Raccourcis : une touche par tenue (dans l'ordre de la liste), pour
-- mettre ou retirer d'un appui (Échap > Raccourcis > SuperRsk).
TenuesUI.NB_TOUCHES = 6
function TenuesUI.nommerTouches()
    local l = Tenues.liste()
    for i = 1, TenuesUI.NB_TOUCHES do
        local t = l[i]
        _G["BINDING_NAME_SUPERRSK_TENUE" .. i] = L["Auto Sets : tenue %d"]:format(i) .. (t and (" (" .. t.nom .. ")") or "")
    end
end

function TenuesUI.touche(i)
    local t = Tenues.liste()[i]
    if not t then
        ns.Jeu.message(L["Auto Sets : pas de tenue n° %d dans ta liste."]:format(i))
        return
    end
    local mise = Tenues.basculer(t.id)
    ns.Jeu.message(mise and L["Auto Sets : %s mise d'un appui (rappuie pour la retirer)."]:format(t.nom)
        or L["Auto Sets : %s retirée."]:format(t.nom))
    dessiner()
end

-- /sg tenue <nom> (pour une macro) : la tenue dont le nom commence ainsi.
function TenuesUI.parNom(nom)
    nom = (nom or ""):lower()
    for i, t in ipairs(Tenues.liste()) do
        if t.nom:lower():sub(1, #nom) == nom then return TenuesUI.touche(i) end
    end
    ns.Jeu.message(L["Auto Sets : aucune tenue nommée « %s »."]:format(nom))
end

-- Connexion finie (équipement et sacs remplis) : Auto Sets peut décider.
-- D'abord les pièces de tenue restées sur toi, puis la tenue voulue.
local attentes = 0
local function pret()
    if Tenues.pret then return end
    -- Rien de lu sur toi : chargement encore en cours, on repasse (30 s au plus).
    local lu = false
    for case = 1, 19 do if ns.Jeu.idPiece(case) then lu = true; break end end
    if not lu and attentes < 15 then
        attentes = attentes + 1
        ns.Jeu.plusTard(2, pret)
        return
    end
    Tenues.pret = true
    pcall(Tenues.orphelins)
    pcall(Tenues.evaluer)
end

function TenuesUI.creer()
    Tenues.pret = false
    ns.Jeu.plusTard(10, pret)   -- au cas où l'arrivée en jeu serait passée avant
    creerProp()
    TenuesUI.nommerTouches()
    for _, e in ipairs(TenuesUI.EVENEMENTS) do inscrire(e) end
    for e in pairs(EVALUER) do inscrire(e) end
    if GameTooltip and GameTooltip.HookScript then
        GameTooltip:HookScript("OnShow", function(tip) pcall(surInfobulle, tip) end)
    end
    -- Nage, fin du délai de récolte, conditions sans événement : un coup
    -- d'œil par demi-seconde (rien n'est fait si rien ne change).
    if C_Timer and C_Timer.NewTicker then
        C_Timer.NewTicker(0.5, function() if R("tenuesActif") or Tenues.enCours() then pcall(Tenues.evaluer) end end)
    end
end

f:SetScript("OnEvent", function(_, e, a1, a2, a3, a4)
    if e == "PLAYER_ENTERING_WORLD" then
        ns.Jeu.plusTard(3, pret)
        ns.Jeu.plusTard(5, actualiser)
    elseif e == "BAG_UPDATE_DELAYED" or e == "PLAYER_EQUIPMENT_CHANGED" then
        actualiser()
    elseif e == "TRADE_SKILL_SHOW" or e == "CRAFT_SHOW" then
        ns.Jeu.plusTard(0, function()
            ns.Jeu.noterMetier(ns.Jeu.lireMetierOuvert())
            Tenues.evaluer()
        end)
    elseif e == "TRADE_SKILL_CLOSE" or e == "CRAFT_CLOSE" then
        ns.Jeu.noterMetier(nil)
        Tenues.evaluer()
    elseif e == "UNIT_SPELLCAST_SENT" then
        -- Récolte lancée : le nom de la plante ou du filon est appris.
        local cat = a1 == "player" and categorieSort(a4)
        local cible = ns.Jeu.lisible(a2)
        if cat and cible and cible ~= "" then noeuds()[cible] = cat end
    elseif e == "PLAYER_SOFT_INTERACT_CHANGED" then
        -- Le nom de l'objet visé peut être secret : rien à faire alors.
        local ok, nom = pcall(UnitName, "softinteract")
        nom = ok and ns.Jeu.lisible(nom) or nil
        local cat = nom and noeuds()[nom]
        if cat then recolteVue(cat) end
    elseif e == "PLAYER_REGEN_DISABLED" then
        if cadre and cadre:IsShown() then cadre:Hide(); rouvrir = true end
    elseif EVALUER[e] then
        if e:find("^UNIT_") and a1 ~= "player" then return end
        if e == "PLAYER_REGEN_ENABLED" and rouvrir then rouvrir = false; TenuesUI.ouvrir() end
        Tenues.evaluer()
        if cadre and cadre:IsShown() then dessiner() end
    end
end)
