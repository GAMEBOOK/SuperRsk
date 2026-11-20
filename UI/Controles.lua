-- Briques d'interface du menu principal, au thème v2 : texte, bouton,
-- case à cocher, curseur, choix à boutons, carte, champ de recherche.
-- Chaque contrôle lié à un réglage a une méthode maj() qui relit sa valeur.

local ADDON, ns = ...

local Controles = {}
ns.Controles = Controles
local L = ns.L or setmetatable({}, { __index = function(_, k) return k end })

local function T() return ns.Theme end

function Controles.texte(parent, police, couleur)
    local f = parent:CreateFontString(nil, "OVERLAY")
    f:SetFontObject(T().policeFixe(police or "texte"))
    f:SetTextColor(T().rgb(couleur or "texte"))
    f:SetJustifyH("LEFT")
    return f
end

-- Infobulle au survol (titre blanc, texte gris qui passe à la ligne).
function Controles.infobulle(f, titre, texte)
    f:HookScript("OnEnter", function(self)
        if not (titre or texte) then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if titre then GameTooltip:AddLine(titre, 1, 1, 1) end
        if texte then GameTooltip:AddLine(texte, 0.7, 0.75, 0.8, true) end
        GameTooltip:Show()
    end)
    f:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Bouton texte à liseré ; « couleur » teinte le texte et le liseré au survol.
function Controles.bouton(parent, texte, couleur, rappel, largeur)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(24)
    local _, bord = T().fond(b, "flot", 1, "bordFort")
    b.texte = Controles.texte(b, "petit", couleur or "texte")
    b.texte:SetPoint("CENTER")
    b.texte:SetJustifyH("CENTER")
    b.texte:SetText(texte)
    b:SetWidth(largeur or math.max(80, (b.texte:GetStringWidth() or 60) + 24))
    b:SetScript("OnEnter", function() bord:SetVertexColor(T().rgb(couleur or "accent")) end)
    b:SetScript("OnLeave", function() bord:SetVertexColor(T().rgb("bordFort")) end)
    b:SetScript("OnClick", function(self, ...) if rappel then rappel(self, ...) end end)
    return b
end

-- Carte : fond légèrement plus clair, liseré.
function Controles.carte(parent)
    local c = CreateFrame("Frame", nil, parent)
    T().fond(c, "flot", 1, "bordFort")
    return c
end

-- Case à cocher liée à un réglage (« inverse » : cochée quand la valeur est fausse).
-- Pastille de couleur liée au réglage « cle » ({ r, g, b } ou false =
-- couleur du thème « defaut ») : clic = palette du jeu, clic droit = origine.
local function ouvrirPalette(r, g, b, regler, annuler)
    local P = ColorPickerFrame
    if not P then return end
    local function lire() regler(P:GetColorRGB()) end
    if P.SetupColorPickerAndShow then
        P:SetupColorPickerAndShow({ r = r, g = g, b = b, hasOpacity = false,
            swatchFunc = lire, cancelFunc = annuler })
    else
        P.hasOpacity, P.func, P.cancelFunc, P.previousValues = false, lire, annuler, { r, g, b }
        P:SetColorRGB(r, g, b)
        ShowUIPanel(P)
    end
end

function Controles.pastille(parent, cle, defaut)
    local R = ns.Reglages
    local p = CreateFrame("Button", nil, parent)
    p:SetSize(16, 16)
    p:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    T().fond(p, "sombre", 1, "bordFort")
    local t = p:CreateTexture(nil, "ARTWORK")
    t:SetPoint("TOPLEFT", 2, -2)
    t:SetPoint("BOTTOMRIGHT", -2, 2)
    local function rgb()
        local c = R.get(cle)
        if c then return c[1], c[2], c[3] end
        return T().rgb(defaut)
    end
    function p.maj() t:SetColorTexture(rgb()) end
    p:SetScript("OnClick", function(self, bouton)
        if bouton == "RightButton" then
            R.set(cle, false)
        else
            local avant = R.get(cle)
            local r, g, b = rgb()
            ouvrirPalette(r, g, b, function(nr, ng, nb) R.set(cle, { nr, ng, nb }); p.maj() end,
                function() R.set(cle, avant); p.maj() end)
        end
        p.maj()
    end)
    Controles.infobulle(p, L["Couleur"], L["Clic : choisir la couleur. Clic droit : couleur d'origine."])
    p.maj()
    return p
end

-- Ligne « pastille + libellé » pour une couleur seule.
function Controles.couleur(parent, o, largeur)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(largeur, 22)
    f.pastille = Controles.pastille(f, o.cle, o.couleurDefaut or "accent")
    f.pastille:SetPoint("LEFT")
    f.libelle = Controles.texte(f, "texte", "texte")
    f.libelle:SetPoint("LEFT", f.pastille, "RIGHT", 8, 0)
    f.libelle:SetText(o.libelle)
    f.maj = f.pastille.maj
    return f
end

function Controles.case(parent, o, largeur)
    local R = ns.Reglages
    local f = CreateFrame("Button", nil, parent)
    f:SetSize(largeur, 22)
    f.boite = f:CreateTexture(nil, "ARTWORK")
    f.boite:SetSize(16, 16)
    f.boite:SetPoint("LEFT")
    f.libelle = Controles.texte(f, "texte", "texte")
    f.libelle:SetPoint("LEFT", f.boite, "RIGHT", 8, 0)
    f.libelle:SetText(o.libelle)
    local function coche()
        local v = R.get(o.cle)
        if o.inverse then return not v end
        return v and true or false
    end
    function f.maj()
        local c = coche()
        f.boite:SetTexture(T().icone(c and "case-cochee" or "case"))
        f.boite:SetVertexColor(T().rgb(c and "accent" or "texteDoux"))
    end
    f:SetScript("OnClick", function()
        local c = not coche()
        if o.inverse then R.set(o.cle, not c) else R.set(o.cle, c) end
        f.maj()
    end)
    Controles.infobulle(f, o.libelle, o.info)
    if o.couleur then
        f.pastille = Controles.pastille(f, o.couleur, o.couleurDefaut or "accent")
        f.pastille:SetPoint("RIGHT")
    end
    f.maj()
    return f
end

local function formater(o, v)
    if o.pourcent then return string.format("%d %%", math.floor(v * 100 + 0.5)) end
    return tostring(v)
end

-- Curseur lié à un réglage : libellé et valeur au-dessus, glissière dessous.
function Controles.curseur(parent, o, largeur)
    local R = ns.Reglages
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(largeur, 38)
    f.libelle = Controles.texte(f, "texte", "texte")
    f.libelle:SetPoint("TOPLEFT")
    f.libelle:SetText(o.libelle)
    f.valeur = Controles.texte(f, "petit", "accent")
    f.valeur:SetPoint("TOPRIGHT")
    f.valeur:SetJustifyH("RIGHT")

    local s = CreateFrame("Slider", nil, f)
    s:SetOrientation("HORIZONTAL")
    s:SetPoint("BOTTOMLEFT", 0, 4)
    s:SetPoint("BOTTOMRIGHT", 0, 4)
    s:SetHeight(14)
    s:EnableMouse(true)
    s:SetMinMaxValues(o.min, o.max)
    s:SetValueStep(o.pas)
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
    local rail = s:CreateTexture(nil, "BACKGROUND")
    rail:SetColorTexture(T().rgb("bordFort"))
    rail:SetHeight(4)
    rail:SetPoint("LEFT"); rail:SetPoint("RIGHT")
    local plein = s:CreateTexture(nil, "BORDER")
    plein:SetColorTexture(T().rgb("accent"))
    plein:SetHeight(4)
    plein:SetPoint("LEFT")
    local pouce = s:CreateTexture(nil, "OVERLAY")
    pouce:SetTexture(ns.Theme.MEDIA .. "RondPlein")
    pouce:SetVertexColor(T().rgb("texte"))
    pouce:SetSize(12, 12)
    s:SetThumbTexture(pouce)
    f.glissiere = s

    local enMaj = false
    local function dessiner(v)
        f.valeur:SetText(formater(o, v))
        local l = (s:GetWidth() or 0) * (v - o.min) / (o.max - o.min)
        plein:SetWidth(math.max(1, l))
    end
    function f.maj()
        enMaj = true
        local v = R.get(o.cle)
        s:SetValue(v)
        dessiner(v)
        enMaj = false
    end
    s:SetScript("OnValueChanged", function(_, v)
        if enMaj then return end
        R.set(o.cle, v)
        dessiner(R.get(o.cle))
    end)
    s:SetScript("OnSizeChanged", function() dessiner(R.get(o.cle)) end)
    -- Pas de molette : elle fait défiler la page au lieu de changer la valeur.
    f.curseur = s
    Controles.infobulle(s, o.libelle, o.info)
    f.maj()
    return f
end

-- Choix à boutons côte à côte (le choisi en accent).
function Controles.choix(parent, o, largeur)
    local R = ns.Reglages
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(largeur, 48)
    f.libelle = Controles.texte(f, "texte", "texte")
    f.libelle:SetPoint("TOPLEFT")
    f.libelle:SetText(o.libelle)
    local n = #o.valeurs
    local l = (largeur - (n - 1) * 4) / n
    f.boutons = {}
    for i, v in ipairs(o.valeurs) do
        local b = CreateFrame("Button", nil, f)
        b:SetSize(l, 22)
        b:SetPoint("BOTTOMLEFT", (i - 1) * (l + 4), 0)
        b.fond, b.bord = T().fond(b, "flot", 1, "bordFort")
        b.texte = Controles.texte(b, "petit", "texteDoux")
        b.texte:SetPoint("CENTER")
        b.texte:SetJustifyH("CENTER")
        b.texte:SetText(o.noms[i])
        b:SetScript("OnClick", function() R.set(o.cle, v); f.maj() end)
        Controles.infobulle(b, o.libelle, o.info)
        f.boutons[i] = b
    end
    function f.maj()
        local actuel = R.get(o.cle)
        for i, b in ipairs(f.boutons) do
            local oui = o.valeurs[i] == actuel
            b.bord:SetVertexColor(T().rgb(oui and "accent" or "bordFort"))
            b.texte:SetTextColor(T().rgb(oui and "accent" or "texteDoux"))
        end
    end
    f.maj()
    return f
end

-- Liste déroulante de textures avec aperçu ; o.liste() renvoie
-- { { valeur, nom, chemin } }, la première sert de repli.
local LIGNES_TEXTURE = 8

-- Sens d'ouverture d'une liste : vers le bas s'il y a la place sous le bouton.
function Controles.sensListe(basBouton, hauteur)
    return basBouton - hauteur - 8 >= 0 and "bas" or "haut"
end
function Controles.texture(parent, o, largeur)
    local R = ns.Reglages
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(largeur, 48)
    f.libelle = Controles.texte(f, "texte", "texte")
    f.libelle:SetPoint("TOPLEFT")
    f.libelle:SetText(o.libelle)

    local b = CreateFrame("Button", nil, f)
    b:SetSize(largeur, 22)
    b:SetPoint("BOTTOMLEFT")
    local _, bord = T().fond(b, "flot", 1, "bordFort")
    local apercu = b:CreateTexture(nil, "ARTWORK")
    apercu:SetPoint("TOPLEFT", 3, -3)
    apercu:SetPoint("BOTTOMRIGHT", -3, 3)
    apercu:SetVertexColor(T().rgb("accent"))
    apercu:SetAlpha(0.55)
    b.texte = Controles.texte(b, "petit", "texte")
    b.texte:SetPoint("LEFT", 8, 0)
    b:SetScript("OnEnter", function() bord:SetVertexColor(T().rgb("accent")) end)
    b:SetScript("OnLeave", function() bord:SetVertexColor(T().rgb("bordFort")) end)
    Controles.infobulle(b, o.libelle, o.info)

    -- Sur UIParent : la zone défilante du menu couperait la liste.
    local liste = CreateFrame("Frame", nil, UIParent)
    f.liste = liste
    liste:SetSize(largeur, LIGNES_TEXTURE * 22 + 8)
    liste:SetFrameStrata("FULLSCREEN_DIALOG")
    T().fond(liste, "panneau", 1, "accent")
    liste:EnableMouse(true)
    liste:EnableMouseWheel(true)
    liste:Hide()

    local entrees, debut = {}, 0
    local function remplir()
        local actuel = R.get(o.cle)
        for i, l in ipairs(f.lignes) do
            local e = entrees[debut + i]
            if e then
                l.valeur = e.valeur
                l.tex:SetTexture(e.chemin)
                l.texte:SetText(e.nom)
                l.texte:SetTextColor(T().rgb(e.valeur == actuel and "accent" or "texte"))
                l:Show()
            else
                l:Hide()
            end
        end
    end
    f.lignes = {}
    for i = 1, LIGNES_TEXTURE do
        local l = CreateFrame("Button", nil, liste)
        l:SetSize(largeur - 8, 20)
        l:SetPoint("TOPLEFT", 4, -4 - (i - 1) * 22)
        l.tex = l:CreateTexture(nil, "ARTWORK")
        l.tex:SetAllPoints()
        l.tex:SetVertexColor(T().rgb("accent"))
        l.tex:SetAlpha(0.45)
        l.texte = Controles.texte(l, "petit", "texte")
        l.texte:SetPoint("LEFT", 6, 0)
        l:SetScript("OnClick", function(self)
            R.set(o.cle, self.valeur)
            liste:Hide()
            f.maj()
        end)
        f.lignes[i] = l
    end
    liste:SetScript("OnMouseWheel", function(_, d)
        debut = math.max(0, math.min(#entrees - LIGNES_TEXTURE, debut - d))
        remplir()
    end)

    function f.ouvrir()
        entrees = o.liste()
        debut = 0
        local actuel = R.get(o.cle)
        for i, e in ipairs(entrees) do
            if e.valeur == actuel then debut = math.max(0, math.min(#entrees - LIGNES_TEXTURE, i - 1)) end
        end
        remplir()
        local echelle = (b:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
        liste:SetScale(echelle)
        liste:ClearAllPoints()
        if Controles.sensListe((b:GetBottom() or 0) * echelle, liste:GetHeight() * echelle) == "bas" then
            liste:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 0, -2)
        else
            liste:SetPoint("BOTTOMLEFT", b, "TOPLEFT", 0, 2)
        end
        liste:Show()
    end
    b:SetScript("OnClick", function() if liste:IsShown() then liste:Hide() else f.ouvrir() end end)
    -- Menu fermé ou page changée : la liste part avec le bouton.
    b:SetScript("OnHide", function() liste:Hide() end)

    function f.maj()
        local tout = o.liste()
        local choisie = tout[1]
        for _, e in ipairs(tout) do if e.valeur == R.get(o.cle) then choisie = e end end
        apercu:SetTexture(choisie.chemin)
        b.texte:SetText(choisie.nom)
    end
    f.maj()
    return f
end

-- Touche liée à un réglage : libellé au-dessus, bouton dessous. Clic, puis
-- appui sur la touche voulue (avec Maj, Ctrl, Alt si besoin), un bouton de
-- souris (milieu, côtés) ou la molette. Échap annule ; clic droit : la
-- touche par défaut.
local MODIFICATEURS = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true,
                        LMETA = true, RMETA = true }
local SOURIS = { MiddleButton = "BUTTON3", Button4 = "BUTTON4", Button5 = "BUTTON5" }

local function avecModificateurs(touche)
    local p = ""
    if IsAltKeyDown and IsAltKeyDown() then p = p .. "ALT-" end
    if IsControlKeyDown and IsControlKeyDown() then p = p .. "CTRL-" end
    if IsShiftKeyDown and IsShiftKeyDown() then p = p .. "SHIFT-" end
    return p .. touche
end

function Controles.nomTouche(t)
    if not t or t == "" then return L["aucune"] end
    if GetBindingText then return GetBindingText(t) end
    return t
end

function Controles.touche(parent, o, largeur)
    local R = ns.Reglages
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(largeur, 48)
    f.libelle = Controles.texte(f, "texte", "texte")
    f.libelle:SetPoint("TOPLEFT")
    f.libelle:SetText(o.libelle)
    local b = CreateFrame("Button", nil, f)
    b:SetSize(math.min(largeur, 180), 24)
    b:SetPoint("BOTTOMLEFT")
    b.fond, b.bord = T().fond(b, "flot", 1, "bordFort")
    b.texte = Controles.texte(b, "texte", "accent")
    b.texte:SetPoint("CENTER")
    b.texte:SetJustifyH("CENTER")
    f.remplace = Controles.texte(f, "petit", "texteDoux")
    f.remplace:SetPoint("LEFT", b, "RIGHT", 10, 0)
    f.remplace:SetWidth(math.max(40, largeur - 190))
    f.remplace:SetWordWrap(false)
    b:RegisterForClicks("AnyUp")
    local attente = false

    local function finir(touche)
        attente = false
        b:EnableKeyboard(false)
        b:SetScript("OnKeyDown", nil)
        b:SetScript("OnMouseWheel", nil)
        b:EnableMouseWheel(false)
        if touche then R.set(o.cle, touche) end
        f.maj()
    end

    function f.maj()
        local t = R.get(o.cle)
        b.bord:SetVertexColor(T().rgb(attente and "accent" or "bordFort"))
        if attente then
            b.texte:SetText(L["Appuie sur une touche…"])
            f.remplace:SetText(L["Échap : annuler"])
            return
        end
        b.texte:SetText(Controles.nomTouche(t))
        -- Ce que cette touche fait d'habitude (elle le refait sans canne).
        -- Même touche qu'une autre option (o.doublon) : on le dit.
        if o.doublon and t and t ~= "" and R.get(o.doublon) == t then
            f.remplace:SetText(L["même touche que la pêche : elle fait déjà tout"])
            return
        end
        local action = t and t ~= "" and GetBindingAction and GetBindingAction(t)
        if action and action ~= "" then
            -- Nom de l'action dans la langue du jeu (« Attaquer la cible »).
            local nom = _G["BINDING_NAME_" .. action] or (GetBindingName and GetBindingName(action)) or action
            f.remplace:SetText(L["remplace « %s » le temps de pêcher"]:format(nom))
        else
            f.remplace:SetText("")
        end
    end

    b:SetScript("OnClick", function(_, bouton)
        if InCombatLockdown and InCombatLockdown() then return end
        if attente then
            if SOURIS[bouton] then finir(avecModificateurs(SOURIS[bouton])) end
            return
        end
        if bouton == "RightButton" then
            R.set(o.cle, R.DEFAUTS[o.cle])
            f.maj()
            return
        end
        if bouton ~= "LeftButton" then return end
        attente = true
        b:EnableKeyboard(true)
        if b.SetPropagateKeyboardInput then b:SetPropagateKeyboardInput(false) end
        b:SetScript("OnKeyDown", function(_, touche)
            if MODIFICATEURS[touche] then return end
            if touche == "ESCAPE" then finir(nil) return end
            finir(avecModificateurs(touche))
        end)
        b:EnableMouseWheel(true)
        b:SetScript("OnMouseWheel", function(_, delta)
            finir(avecModificateurs(delta > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN"))
        end)
        f.maj()
    end)
    b:HookScript("OnHide", function() if attente then finir(nil) end end)
    Controles.infobulle(b, o.libelle, o.info)
    f.maj()
    return f
end

-- Contrôle adapté au type de l'option.
function Controles.pour(parent, o, largeur)
    if o.type == "case" then return Controles.case(parent, o, largeur) end
    if o.type == "curseur" then return Controles.curseur(parent, o, largeur) end
    if o.type == "choix" then return Controles.choix(parent, o, largeur) end
    if o.type == "texture" then return Controles.texture(parent, o, largeur) end
    if o.type == "couleur" then return Controles.couleur(parent, o, largeur) end
    if o.type == "texte" then return Controles.texteLibre(parent, o, largeur) end
    if o.type == "touche" then return Controles.touche(parent, o, largeur) end
end

-- Champ de saisie : texte pâle tant qu'il est vide, icône à gauche si
-- donnée ; « rappel(texte) » à chaque frappe, « entree(champ) » sur Entrée.
-- Texte libre lié à un réglage : libellé au-dessus, champ dessous.
function Controles.texteLibre(parent, o, largeur)
    local R = ns.Reglages
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(largeur, 48)
    local t = Controles.texte(f, "texte", "texte")
    t:SetPoint("TOPLEFT")
    t:SetText(o.libelle)
    local enCours = false
    local champ = Controles.champ(f, math.min(largeur, 260), o.indice or "", function(texte)
        if not enCours then R.set(o.cle, texte) end
    end)
    champ:SetPoint("TOPLEFT", 0, -20)
    champ:SetMaxLetters(o.max or 24)
    function f.maj()
        local v = R.get(o.cle) or ""
        if champ:GetText() ~= v and not champ:HasFocus() then
            enCours = true
            champ:SetText(v)
            enCours = false
        end
    end
    Controles.infobulle(f, o.libelle, o.info)
    f.maj()
    return f
end

function Controles.champ(parent, largeur, indiceTexte, rappel, icone, entree)
    local f = CreateFrame("EditBox", nil, parent)
    f:SetSize(largeur, 26)
    f:SetAutoFocus(false)
    f:SetFontObject(T().policeFixe("texte"))
    f:SetTextColor(T().rgb("texte"))
    local gauche = icone and 26 or 8
    f:SetTextInsets(gauche, 8, 0, 0)
    local _, bord = T().fond(f, "flot", 1, "bordFort")
    if icone then
        local i = f:CreateTexture(nil, "ARTWORK")
        i:SetTexture(T().icone(icone))
        i:SetSize(13, 13)
        i:SetPoint("LEFT", 8, 0)
        i:SetVertexColor(T().rgb("texteDoux"))
    end
    local indice = Controles.texte(f, "texte", "textePale")
    indice:SetPoint("LEFT", gauche, 0)
    indice:SetText(indiceTexte)
    f:SetScript("OnTextChanged", function(self)
        local t = self:GetText() or ""
        if t == "" then indice:Show() else indice:Hide() end
        if rappel then rappel(t) end
    end)
    f:SetScript("OnEditFocusGained", function() bord:SetVertexColor(T().rgb("accent")) end)
    f:SetScript("OnEditFocusLost", function() bord:SetVertexColor(T().rgb("bordFort")) end)
    f:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    f:SetScript("OnEnterPressed", function(self) if entree then entree(self) else self:ClearFocus() end end)
    return f
end
