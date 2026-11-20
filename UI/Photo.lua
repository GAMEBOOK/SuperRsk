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
    { "peche", "Auto Fishing", "One key casts, hooks, equips your pole and puts the lure on." },
    { "autoEquip", "Auto Equip", "Never miss an upgrade: the best gear for your class and talents, in one click." },
    { "menage", "Quest Item Cleanup", "Quest items you no longer need, gone in one click." },
    { "barreXP", "XP Bar", "Your XP bar, with the XP of your finished and ongoing quests." },
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
    { "boostFPS", "Boost FPS", "More FPS and a sharper picture, in one click." },
    { "meteo", "Weather and Fog", "No rain, no fog, a clear view." },
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
end

-- Le ménage se montre avec sa vraie fenêtre, remplie d'exemples.
local SPECIAUX = {
    menage = function(oui)
        if ns.Menage and ns.Menage.exemple then return ns.Menage.exemple(oui) end
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
