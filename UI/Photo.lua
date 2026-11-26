-- Mode photo (/sg photo) : chaque module en grand au centre de l'écran,
-- rempli de données d'exemple, avec son titre et une phrase d'accroche en
-- anglais, pour les captures de la page CurseForge.
--   flèches gauche / droite : module précédent / suivant      B  fond (jeu, sombre, noir)
--   Échap  quitter                        Alt+Z  cache l'interface du jeu,
--                                         le mode photo reste (image propre)
-- Rien en combat. L'élément revient à sa place en sortant.

local ADDON, ns = ...

local Photo = {}
ns.Photo = Photo

local L = ns.L or setmetatable({}, { __index = function(_, k) return k end })

-- Ordre des pages, titres et accroches (anglais : la page CurseForge l'est).
local PAGES = {
    { "presentation", "", "" },
    { "peche", "Auto Fishing", "One key casts, hooks, equips your pole and puts the lure on." },
    { "autoEquip", "Auto Equip", "Never miss an upgrade: the best gear for your class and talents, in one click." },
    { "tenues", "Auto Sets", "The right gear at the right moment: mount, gathering, bosses. Then your gear comes back." },
    { "menage", "Quest Item Cleanup", "Quest items you no longer need, gone in one click." },
    { "barreXP", "XP Bar", "Your XP bar, with the XP of your finished and ongoing quests." },
    { "barreRep", "Reputation Bar", "Your faction, your standing, your rep per hour." },
    { "autoLoot", "Auto Loot", "Instant loot, with a clean loot list." },
    { "poubelle", "Junk", "Bags full? The cheapest grey item goes to the trash." },
    { "marchand", "Merchant", "Greys sold and gear repaired at every merchant." },
    { "usure", "Gear Durability", "Know before your gear breaks." },
    { "autoRangs", "Auto Spell Ranks", "New spell rank? Your action bars update themselves." },
    { "autoTir", "Auto Shot / Wand", "Never lose an auto shot again." },
    { "softInteract", "Quick Interact", "Ores, herbs, chests, bobbers: one key takes them." },
    { "vols", "Flight Points", "Every flight point of your faction on your map." },
    { "marqueurs", "Raid Markers", "Your raid markers in one key." },
    { "swapGroupe", "Swap Layer in group", "Multiboxing: leave, swap and invite in one click." },
    { "spyPing", "Spy Ping", "Spot and ping enemies for your group." },
    { "vh", "Honorable Kills", "Your honorable kills and your guild's ranking." },
    { "monnaies", "Currencies", "Your gold and the currencies you tick, anywhere on screen." },
    { "boostFPS", "Boost FPS", "More FPS and a sharper picture, in one click." },
    { "meteo", "Weather and Effects", "No raindrops or snow, less fog." },
    { "tsquid", "Tsquid Area", "A lightsaber sound on critical hits." },
}
local FONDS = { 0, 0.72, 1 }   -- opacité du fond : le jeu, sombre, noir

local ecran, page, fond, actuel = nil, 1, 2, nil

local function T() return ns.Theme end

-- Rend l'élément affiché à sa place et coupe son aperçu.
local function rendre()
    if not actuel then return end
    local a = actuel
    actuel = nil
    if a.special then a.special(false) end
    local f = a.cadre
    if f then
        f:SetParent(UIParent)
        f:SetScale(a.echelle or 1)
        f:SetFrameStrata(a.strate or "MEDIUM")
        f:EnableMouse(true)
        if ns.Deplacement and ns.Deplacement.replacer and a.cle then ns.Deplacement.replacer(a.cle) end
    end
    if a.module and a.module.apercu then pcall(a.module.apercu, false) end
    if ns.BarreRep then ns.BarreRep.photo = false end
end

-- Page de présentation (image principale de la page CurseForge) : le logo
-- en grand avec sa lueur, le nom, l'accroche et les modules phares.
local presentation
local PHARES = { "Auto Fishing", "Auto Sets", "Auto Equip", "Auto Loot", "Auto Sell & Repair",
                 "Quest Item Cleanup", "XP Bar", "Junk" }
local function creerPresentation()
    local Th = T()
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetSize(980, 470)
    f:Hide()
    local logo = f:CreateTexture(nil, "ARTWORK")
    logo:SetTexture(Th.icone("boussole"))
    logo:SetSize(120, 120)
    logo:SetPoint("TOP", 0, -10)
    logo:SetVertexColor(Th.rgb("accent"))
    f.tourner = ns.Controles.animerLogo(logo, nil, 330, nil, 6)
    local nom = f:CreateFontString(nil, "OVERLAY")
    nom:SetFont(Th.MEDIA .. "Polices\\Archivo-BoldCondensed.ttf", 84, "")
    nom:SetTextColor(Th.rgb("texte"))
    nom:SetPoint("TOP", logo, "BOTTOM", 0, -26)
    nom:SetText("SuperRsk")
    local qol = f:CreateFontString(nil, "OVERLAY")
    qol:SetFont(Th.MEDIA .. "Polices\\Archivo-Medium.ttf", 26, "")
    qol:SetTextColor(Th.rgb("accent"))
    qol:SetPoint("TOP", nom, "BOTTOM", 0, -6)
    qol:SetText("All in One QoL for WoW Forever")
    local phrase = f:CreateFontString(nil, "OVERLAY")
    phrase:SetFont(Th.MEDIA .. "Polices\\Archivo-Regular.ttf", 19, "")
    phrase:SetTextColor(Th.rgb("texteDoux"))
    phrase:SetPoint("TOP", qol, "BOTTOM", 0, -16)
    phrase:SetText("One addon, one key, set up in 30 seconds.")
    -- Les modules phares en pastilles, sur une ligne centrée.
    local pastilles, largeur = {}, 0
    for i, nomModule in ipairs(PHARES) do
        local p = CreateFrame("Frame", nil, f)
        Th.fond(p, "flot", 0.95, i == 1 and "accent" or "bordFort")
        local t = p:CreateFontString(nil, "OVERLAY")
        t:SetFont(Th.MEDIA .. "Polices\\Archivo-Medium.ttf", 16, "")
        t:SetTextColor(Th.rgb(i == 1 and "accent" or "texte"))
        t:SetPoint("CENTER")
        t:SetText(nomModule)
        p:SetSize((t:GetStringWidth() or 100) + 28, 34)
        pastilles[i] = p
        largeur = largeur + p:GetWidth() + (i > 1 and 10 or 0)
    end
    local x = -largeur / 2
    for _, p in ipairs(pastilles) do
        p:SetPoint("TOPLEFT", phrase, "BOTTOM", x, -30)
        x = x + p:GetWidth() + 10
    end
    local plus = f:CreateFontString(nil, "OVERLAY")
    plus:SetFont(Th.MEDIA .. "Polices\\Archivo-Regular.ttf", 16, "")
    plus:SetTextColor(Th.rgb("textePale"))
    plus:SetPoint("TOP", phrase, "BOTTOM", 0, -80)
    plus:SetText(("+ %d more modules  ·  English and French  ·  /sg"):format(#ns.Reglages.MODULES - #PHARES))
    return f
end

-- Le ménage se montre avec sa vraie fenêtre, remplie d'exemples.
local SPECIAUX = {
    presentation = function(oui)
        if not oui then
            if presentation then presentation:Hide() end
            return presentation
        end
        presentation = presentation or creerPresentation()
        presentation:Show()
        presentation.tourner()
        return presentation
    end,
    menage = function(oui)
        if ns.Menage and ns.Menage.exemple then return ns.Menage.exemple(oui) end
    end,
    tenues = function(oui)
        if ns.TenuesUI and ns.TenuesUI.exemple then return ns.TenuesUI.exemple(oui) end
    end,

}

local function montrer(i)
    rendre()
    page = (i - 1) % #PAGES + 1
    local nom, titre, accroche = PAGES[page][1], PAGES[page][2], PAGES[page][3]
    ecran.titre:SetText(titre)
    ecran.accroche:SetText(accroche)
    ecran.numero:SetText(("%d / %d"):format(page, #PAGES))
    local m = ns.Reglages.module(nom)
    local f, cle
    local special = SPECIAUX[nom]
    -- Barre de réputation sans faction suivie : une faction d'exemple.
    if ns.BarreRep then ns.BarreRep.photo = (nom == "barreRep") end
    if special then
        f = special(true)
    elseif m and m.vitrine then
        if m.apercu then pcall(m.apercu, true) end
        f, cle = m.vitrine()
    end
    if not f then return end
    actuel = { cadre = f, cle = cle, module = m, special = special,
               strate = f:GetFrameStrata(), echelle = f:GetScale() }
    f:SetParent(ecran)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:EnableMouse(false)
    f:ClearAllPoints()
    f:SetPoint("CENTER", ecran, "CENTER", 0, -20)
    -- En grand, sans dépasser 70 % de la largeur ni 55 % de la hauteur.
    local l, h = f:GetWidth() or 1, f:GetHeight() or 1
    local L_, H_ = ecran:GetWidth() or 1920, ecran:GetHeight() or 1080
    f:SetScale(math.max(0.5, math.min(2.2, L_ * 0.7 / math.max(1, l), H_ * 0.55 / math.max(1, h))))
    -- Pas d'étiquette « APERÇU » sur une photo.
    local e = rawget(f, "etiquette")
    if type(e) == "table" and e.Hide then e:Hide() end
    f:Show()
end

local function changerFond()
    fond = fond % #FONDS + 1
    ecran.fond:SetAlpha(FONDS[fond])
end

function Photo.fermer()
    if not (ecran and ecran:IsShown()) then return end
    rendre()
    ecran:Hide()
end

local TOUCHES = {
    LEFT = function() montrer(page - 1) end,
    RIGHT = function() montrer(page + 1) end,
    B = changerFond,
    ESCAPE = Photo.fermer,
}

local function creer()
    -- Sans parent : reste visible quand Alt+Z cache l'interface du jeu.
    ecran = CreateFrame("Frame", "SuperGuidePhoto", nil)
    ecran:SetAllPoints(WorldFrame)
    ecran:SetFrameStrata("FULLSCREEN")
    ecran:SetScale(UIParent:GetEffectiveScale())
    ecran.fond = ecran:CreateTexture(nil, "BACKGROUND")
    ecran.fond:SetAllPoints()
    ecran.fond:SetColorTexture(T().rgb("sombre"))
    ecran.fond:SetAlpha(FONDS[fond])

    ecran.titre = ecran:CreateFontString(nil, "OVERLAY")
    ecran.titre:SetFont(T().MEDIA .. "Polices\\Archivo-BoldCondensed.ttf", 44, "")
    ecran.titre:SetTextColor(T().rgb("texte"))
    ecran.titre:SetPoint("TOP", 0, -90)
    ecran.accroche = ecran:CreateFontString(nil, "OVERLAY")
    ecran.accroche:SetFont(T().MEDIA .. "Polices\\Archivo-Medium.ttf", 20, "")
    ecran.accroche:SetTextColor(T().rgb("accent"))
    ecran.accroche:SetPoint("TOP", ecran.titre, "BOTTOM", 0, -12)

    -- Signature discrète en bas.
    local marque = ecran:CreateFontString(nil, "OVERLAY")
    marque:SetFont(T().MEDIA .. "Polices\\Archivo-BoldCondensed.ttf", 18, "")
    marque:SetTextColor(T().rgb("textePale"))
    marque:SetPoint("BOTTOM", 0, 40)
    marque:SetText("|cff33ccffSuperRsk|r  ·  All in One QoL  ·  /sg")

    -- Aide des touches, qui s'efface pour ne pas gêner la capture.
    ecran.aide = ecran:CreateFontString(nil, "OVERLAY")
    ecran.aide:SetFont(T().MEDIA .. "Polices\\Archivo-Regular.ttf", 14, "")
    ecran.aide:SetTextColor(T().rgb("texteDoux"))
    ecran.aide:SetPoint("BOTTOMLEFT", 20, 16)
    ecran.aide:SetText(L["Mode photo : flèches gauche et droite pour changer de module · B fond · Alt+Z cache l'interface du jeu · Échap quitter"])
    ecran.numero = ecran:CreateFontString(nil, "OVERLAY")
    ecran.numero:SetFont(T().MEDIA .. "Polices\\Archivo-Regular.ttf", 14, "")
    ecran.numero:SetTextColor(T().rgb("texteDoux"))
    ecran.numero:SetPoint("BOTTOMRIGHT", -20, 16)

    ecran:EnableKeyboard(true)
    ecran:SetScript("OnKeyDown", function(self, touche)
        local f = TOUCHES[touche]
        -- Les autres touches (Impr. écran, Alt+Z…) passent au jeu.
        if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(f == nil) end
        if f then
            f()
            self.vu = GetTime()
        end
    end)
    ecran:SetScript("OnUpdate", function(self)
        local depuis = GetTime() - (self.vu or 0)
        local a = depuis < 4 and 1 or math.max(0, 1 - (depuis - 4))
        self.aide:SetAlpha(a)
        self.numero:SetAlpha(a)
    end)
    ecran:Hide()
end

function Photo.ouvrir()
    if InCombatLockdown() or (UnitAffectingCombat and UnitAffectingCombat("player")) then
        ns.Jeu.message(L["Pas pendant un combat : le mode photo attend la fin du combat."])
        return
    end
    if not ecran then creer() end
    if ns.Menu and ns.Menu.ouvert() then ns.Menu.fermer() end
    ecran.vu = GetTime()
    ecran:Show()
    montrer(page)
end

function Photo.basculer()
    if ecran and ecran:IsShown() then Photo.fermer() else Photo.ouvrir() end
end

-- Un combat commence : on sort du mode photo.
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_REGEN_DISABLED")
f:SetScript("OnEvent", function() Photo.fermer() end)
