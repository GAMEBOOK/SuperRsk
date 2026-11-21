-- Mode Déplacement : une grille plein écran et une poignée par cadre
-- inscrit, qu'on glisse avec aimantation (grille, centre de l'écran, bords
-- des autres cadres). Les positions sont gardées par rapport au centre de
-- l'écran dans SuperGuideDB.positions.

local ADDON, ns = ...

local Deplacement = {}
ns.Deplacement = Deplacement
local L = ns.L or setmetatable({}, { __index = function(_, k) return k end })

local PAS, SEUIL = 32, 8

---------------------------------------------------------------------------
-- Calculs purs
---------------------------------------------------------------------------

-- Plus petit décalage qui pose un des repères (bords, centre) sur une ligne.
local function caler(c, demi, lignes, seuil)
    local mieux
    for _, v in ipairs(lignes) do
        for _, repere in ipairs({ c - demi, c, c + demi }) do
            local d = v - repere
            if math.abs(d) <= seuil and (not mieux or math.abs(d) < math.abs(mieux)) then mieux = d end
        end
    end
    return c + (mieux or 0)
end

-- r = { x, y, l, h } (centre et taille) ; lignes = { x = {…}, y = {…} }.
function Deplacement.aimanter(r, lignes, seuil)
    return caler(r.x, r.l / 2, lignes.x or {}, seuil), caler(r.y, r.h / 2, lignes.y or {}, seuil)
end

-- Lignes d'aimantation : centre de l'écran, grille facultative, bords et
-- centre de chaque autre cadre.
function Deplacement.lignes(pas, demiL, demiH, autres, grille)
    local l = { x = { 0 }, y = { 0 } }
    if grille then
        for i = 1, math.floor(demiL / pas) do l.x[#l.x + 1] = i * pas; l.x[#l.x + 1] = -i * pas end
        for i = 1, math.floor(demiH / pas) do l.y[#l.y + 1] = i * pas; l.y[#l.y + 1] = -i * pas end
    end
    for _, a in ipairs(autres or {}) do
        for _, v in ipairs({ a.x - a.l / 2, a.x, a.x + a.l / 2 }) do l.x[#l.x + 1] = v end
        for _, v in ipairs({ a.y - a.h / 2, a.y, a.y + a.h / 2 }) do l.y[#l.y + 1] = v end
    end
    return l
end

---------------------------------------------------------------------------
-- Cadres inscrits
---------------------------------------------------------------------------

local inscrits, parCle = {}, {}

local function poser(cadre, x, y)
    cadre:ClearAllPoints()
    cadre:SetPoint("CENTER", UIParent, "CENTER", x, y)
end

local function poserDefaut(i)
    local d = i.defaut
    i.cadre:ClearAllPoints()
    i.cadre:SetPoint(d[1], UIParent, d[1], d[2], d[3])
end

-- Centre et taille d'un cadre inscrit, relatifs au centre de l'écran.
-- Un cadre jamais affiché n'a pas encore de centre : on reprend sa position
-- enregistrée, sinon on la déduit de son ancrage par défaut.
local function rect(i)
    local cadre = i.cadre
    local l, h = cadre:GetWidth() or 0, cadre:GetHeight() or 0
    local cx, cy = cadre:GetCenter()
    if cx and cy then
        local ux, uy = UIParent:GetCenter()
        return { x = cx - ux, y = cy - uy, l = l, h = h }
    end
    local p = SuperGuideDB and SuperGuideDB.positions and SuperGuideDB.positions[i.cle]
    if p then return { x = p[1], y = p[2], l = l, h = h } end
    local d = i.defaut
    local demiL, demiH = (UIParent:GetWidth() or 0) / 2, (UIParent:GetHeight() or 0) / 2
    local x, y = d[2], d[3]
    if d[1]:find("LEFT") then x = x - demiL + l / 2 elseif d[1]:find("RIGHT") then x = x + demiL - l / 2 end
    if d[1]:find("BOTTOM") then y = y - demiH + h / 2 elseif d[1]:find("TOP") then y = y + demiH - h / 2 end
    return { x = x, y = y, l = l, h = h }
end

-- Verrou global (cadenas en haut du menu) : plus rien ne se glisse par
-- erreur ; Maj enfoncée, on bouge quand même. Le mode Déplacer reste ouvert.
function Deplacement.bloque()
    return ns.Reglages.get("elementsVerrouilles") == true
        and not (IsShiftKeyDown and IsShiftKeyDown())
end

function Deplacement.basculerVerrou()
    local oui = not ns.Reglages.get("elementsVerrouilles")
    ns.Reglages.set("elementsVerrouilles", oui)
    ns.Jeu.message(oui and L["Éléments verrouillés : Maj + glisser pour en bouger un quand même."]
        or L["Éléments déverrouillés : glisse-les où tu veux."])
end

function Deplacement.inscrire(cadre, nom, cle, defaut)
    local i = parCle[cle]
    if not i then
        i = { cle = cle }
        parCle[cle] = i
        inscrits[#inscrits + 1] = i
    end
    i.cadre, i.nom, i.defaut = cadre, nom, defaut
    local p = SuperGuideDB and SuperGuideDB.positions and SuperGuideDB.positions[cle]
    if p then poser(cadre, p[1], p[2]) else poserDefaut(i) end

    -- Glisser direct, sauf éléments verrouillés (Maj pour forcer).
    cadre:SetMovable(true)
    cadre:EnableMouse(true)
    cadre:RegisterForDrag("LeftButton")
    cadre:SetScript("OnDragStart", function(self)
        if Deplacement.bloque() then return end
        self.sgGlisse = true
        self:StartMoving()
    end)
    cadre:SetScript("OnDragStop", function(self)
        if not self.sgGlisse then return end
        self.sgGlisse = nil
        self:StopMovingOrSizing()
        local r = rect(i)
        poser(self, r.x, r.y)
        SuperGuideDB.positions = SuperGuideDB.positions or {}
        SuperGuideDB.positions[cle] = { r.x, r.y }
    end)
end

function Deplacement.reinitialiser()
    for _, i in ipairs(inscrits) do poserDefaut(i) end
end

-- Un élément sorti de sa place (aperçu du menu) y retourne : position
-- enregistrée, sinon celle par défaut.
function Deplacement.replacer(cle)
    local i = parCle[cle]
    if not i then return end
    local p = SuperGuideDB and SuperGuideDB.positions and SuperGuideDB.positions[cle]
    if p then poser(i.cadre, p[1], p[2]) else poserDefaut(i) end
end

-- Un seul élément revient à sa place par défaut.
function Deplacement.remettre(cle)
    local i = parCle[cle]
    if not i then return end
    if SuperGuideDB and SuperGuideDB.positions then SuperGuideDB.positions[cle] = nil end
    poserDefaut(i)
end

-- Ancienne position propre au module ({ point, x, y }) : reprise une fois
-- dans les positions communes, puis oubliée.
function Deplacement.reprendre(cle, ancienne)
    local i = parCle[cle]
    if not (i and type(ancienne) == "table" and ancienne.point) then return false end
    SuperGuideDB.positions = SuperGuideDB.positions or {}
    if SuperGuideDB.positions[cle] then return false end
    i.cadre:ClearAllPoints()
    i.cadre:SetPoint(ancienne.point, UIParent, ancienne.point, ancienne.x or 0, ancienne.y or 0)
    local r = rect(i)
    SuperGuideDB.positions[cle] = { r.x, r.y }
    poser(i.cadre, r.x, r.y)
    return true
end

---------------------------------------------------------------------------
-- Écran de déplacement
---------------------------------------------------------------------------

local fond, grille, poignees
local actif, depart = false, {}

local function T() return ns.Theme end
local function C() return ns.Controles end

local function construireGrille()
    for _, t in ipairs(grille) do t:Hide() end
    local demiL, demiH = (UIParent:GetWidth() or 0) / 2, (UIParent:GetHeight() or 0) / 2
    local n = 0
    local function trait(vertical, v)
        n = n + 1
        local t = grille[n] or fond:CreateTexture(nil, "BACKGROUND", nil, 1)
        grille[n] = t
        t:SetTexture("Interface\\Buttons\\WHITE8x8")
        t:ClearAllPoints()
        if vertical then
            t:SetSize(1, demiH * 2)
            t:SetPoint("CENTER", UIParent, "CENTER", v, 0)
        else
            t:SetSize(demiL * 2, 1)
            t:SetPoint("CENTER", UIParent, "CENTER", 0, v)
        end
        if v == 0 then t:SetVertexColor(T().rgb("accent")); t:SetAlpha(0.5)
        else t:SetVertexColor(1, 1, 1); t:SetAlpha(0.08) end
        t:Show()
    end
    local l = Deplacement.lignes(PAS, demiL, demiH, {}, true)
    for _, v in ipairs(l.x) do trait(true, v) end
    for _, v in ipairs(l.y) do trait(false, v) end
end

local function majGrille()
    if not fond then return end
    if ns.Reglages.get("deplGrille") then construireGrille()
    else for _, t in ipairs(grille) do t:Hide() end end
end

-- La poignée suit son cadre (même centre, même taille).
local function suivre(h)
    local r = rect(h.inscrit)
    h:ClearAllPoints()
    h:SetPoint("CENTER", UIParent, "CENTER", r.x, r.y)
    h:SetSize(math.max(r.l, 40), math.max(r.h, 16))
end

local function glisser(h)
    -- Bouton relâché, même hors de la poignée (l'aimant l'a décalée sous le
    -- curseur) : l'élément est lâché.
    if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
        h:SetScript("OnUpdate", nil)
        return
    end
    local s = UIParent:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    local ux, uy = UIParent:GetCenter()
    local r = rect(h.inscrit)
    r.x, r.y = cx / s - ux - h.ecart[1], cy / s - uy - h.ecart[2]
    if ns.Reglages.get("deplAimant") then
        local autres = {}
        for _, i in ipairs(inscrits) do
            if i ~= h.inscrit then autres[#autres + 1] = rect(i) end
        end
        local lignes = Deplacement.lignes(PAS, (UIParent:GetWidth() or 0) / 2, (UIParent:GetHeight() or 0) / 2,
            autres, ns.Reglages.get("deplGrille"))
        r.x, r.y = Deplacement.aimanter(r, lignes, SEUIL)
    end
    poser(h.inscrit.cadre, r.x, r.y)
    suivre(h)
end

local function poignee(i)
    local h = CreateFrame("Button", nil, fond)
    h:SetFrameLevel((fond:GetFrameLevel() or 0) + 5)
    T().fond(h, "sombre", 0.75, "accent")
    h.texte = C().texte(h, "petit", "texte")
    h.texte:SetPoint("CENTER")
    h.texte:SetJustifyH("CENTER")
    h.inscrit = i
    h:RegisterForDrag("LeftButton")
    h:SetScript("OnMouseDown", function(self)
        local s = UIParent:GetEffectiveScale()
        local cx, cy = GetCursorPosition()
        local ux, uy = UIParent:GetCenter()
        local r = rect(self.inscrit)
        self.ecart = { cx / s - ux - r.x, cy / s - uy - r.y }
        self:SetScript("OnUpdate", glisser)
    end)
    h:SetScript("OnMouseUp", function(self) self:SetScript("OnUpdate", nil) end)
    return h
end

local function construire()
    fond = CreateFrame("Frame", "SuperGuideDeplacement", UIParent)
    fond:SetAllPoints(UIParent)
    fond:SetFrameStrata("FULLSCREEN_DIALOG")
    fond:EnableMouse(true)
    local voile = fond:CreateTexture(nil, "BACKGROUND")
    voile:SetAllPoints()
    voile:SetColorTexture(0, 0, 0, 0.35)
    grille, poignees = {}, {}

    local outils = C().carte(fond)
    outils:SetPoint("TOP", UIParent, "TOP", 0, -40)
    outils:SetSize(560, 44)
    outils:SetFrameLevel((fond:GetFrameLevel() or 0) + 10)
    local cases = {
        C().pour(outils, { cle = "deplGrille", type = "case", libelle = L["Grille"] }, 110),
        C().pour(outils, { cle = "deplAimant", type = "case", libelle = L["Aimantation"] }, 130),
    }
    cases[1]:SetPoint("LEFT", 14, 0)
    cases[2]:SetPoint("LEFT", cases[1], "RIGHT", 8, 0)
    outils.cases = cases
    local ok = C().bouton(outils, L["Enregistrer et quitter"], "vert", Deplacement.enregistrer, 160)
    ok:SetPoint("RIGHT", -12, 0)
    local non = C().bouton(outils, L["Annuler"], "texteDoux", Deplacement.annuler, 90)
    non:SetPoint("RIGHT", ok, "LEFT", -8, 0)
    fond.outils = outils

    -- Échap ferme : sans « Enregistrer », fermer revient à annuler.
    if UISpecialFrames then table.insert(UISpecialFrames, "SuperGuideDeplacement") end
    fond:SetScript("OnHide", function() if actif then Deplacement.annuler() end end)
    ns.Reglages.ecouter(function(cle) if cle == "deplGrille" then majGrille() end end)
    fond:Hide()
end

function Deplacement.ouvert() return actif end

-- Élément -> réglage qui l'allume : un module coupé n'a pas de poignée (un
-- cadre vide à placer pour une option coupée ne fait que dérouter).
Deplacement.ALLUME = {
    barreXP = "barreXP", barreRep = "barreRep", butin = "butinListe", swap = "swapGroupeActif", poubelle = "butinPoubelle",
    proposition = "proposerEquipement", barreTir = "tirActif", usure = "usureActif", vh = "vhActif",
}

function Deplacement.visible(cle)
    local r = Deplacement.ALLUME[cle]
    return not r or ns.Reglages.get(r) ~= false
end

function Deplacement.ouvrir()
    if actif then return end
    if InCombatLockdown and InCombatLockdown() then
        ns.Jeu.message(L["Impossible en combat"])
        return
    end
    if not fond then construire() end
    depart = {}
    for n, i in ipairs(inscrits) do
        local r = rect(i)
        depart[i.cle] = { r.x, r.y }
        local h = poignees[n] or poignee(i)
        poignees[n] = h
        h.inscrit = i
        h.texte:SetText(i.nom)
        suivre(h)
        h:SetShown(Deplacement.visible(i.cle))
    end
    for _, c in ipairs(fond.outils.cases) do c.maj() end
    majGrille()
    actif = true
    fond:Show()
end

local function fermer()
    actif = false
    for _, h in ipairs(poignees or {}) do h:SetScript("OnUpdate", nil) end
    fond:Hide()
end

-- Remet chaque cadre où il était à l'ouverture.
function Deplacement.annuler()
    if not actif then return end
    for _, i in ipairs(inscrits) do
        local p = depart[i.cle]
        if p then poser(i.cadre, p[1], p[2]) end
    end
    fermer()
end

function Deplacement.enregistrer()
    if not actif then return end
    SuperGuideDB = SuperGuideDB or {}
    SuperGuideDB.positions = SuperGuideDB.positions or {}
    for _, i in ipairs(inscrits) do
        local r = rect(i)
        SuperGuideDB.positions[i.cle] = { r.x, r.y }
    end
    fermer()
end
