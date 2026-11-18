-- Auto Shot / Wand : barre de tir avec sa zone d'arrêt. Notre barre par
-- défaut (déplaçable, visible quand on tire) ; ou celle du jeu
-- (Blizzard_SwingTimer, SwingTimerRangedFrame.StatusBar), cachée tant qu'on
-- ne l'active pas dans les options. Mécanique inspirée de l'addon Shot Window
-- (jonlipin, MIT), écrite pour SuperRsk.
--
-- PLAYER_SWING (tir parti) relance notre horloge ; la fin du cycle, moins
-- l'armement, la latence et l'avance, est la zone rouge. Le jeu vide sa
-- barre à la fin du cycle même si le tir est en retard (on bougeait) : on
-- garde alors la zone allumée, et pulsante, jusqu'au départ du tir.
-- L'armement réel est mesuré (Core/Tir.lua) : arrêt -> tir, moins
-- l'aller-retour serveur.

local ADDON, ns = ...

local Tir = ns.Tir
local L = ns.L or setmetatable({}, { __index = function(_, k) return k end })
local function R(cle) return ns.Reglages.get(cle) end

local DISTANCE = Enum and Enum.PlayerSwingType and Enum.PlayerSwingType.Ranged or 2
local SORTS = { HUNTER = 75, MAGE = 5019, PRIEST = 5019, WARLOCK = 5019 } -- Tir automatique, Tir
local BAGUETTE = 5019
local NOM_MACRO = "SG Tir"
local GRACE, ATTENTE_MAX = 0.15, 5 -- le tir arrive ~0,1 s après la fin de la barre ; abandon au bout de 5 s

local sort, barre, zone, ligne, moteur
local propre                    -- notre barre (créée à la demande)
local textures = {}             -- barre -> { zone, ligne } déjà posées
local fraction = 0              -- remplissage de notre barre
local enCombat = false
local prete = false             -- baguette coupée en bougeant, cycle fini : prête à relancer
local duree, debut, seuilZone   -- cycle en cours (debut nil = aucun)
local attente, attenteFin       -- tir en retard attendu depuis…
local dedans, auto              -- dans la zone ; tir auto actif (nil = inconnu)
local arret                     -- début de la mesure en cours
-- ShotWindow dessine sur la barre du jeu : en veille seulement si on l'utilise aussi.
local shotWindow = false
local function enVeille() return shotWindow and R("tirBarre") == "jeu" end

local function secret(v) return issecretvalue and issecretvalue(v) end
local function nombre(v) if not secret(v) and type(v) == "number" then return v end end

local function mesures()
    SuperGuideDB.tirMesures = SuperGuideDB.tirMesures or {}
    return SuperGuideDB.tirMesures
end

local function allerRetour()
    if not GetNetStats then return 0 end
    local _, _, maison, monde = GetNetStats()
    local ms = nombre(monde) or nombre(maison)
    return ms and ms > 0 and ms / 1000 or 0
end

local function armement() return Tir.armement(mesures(), R("tirArmement")) end

local function calculerSeuil(d)
    return Tir.debutZone(d, armement(), R("tirLatence") and allerRetour() or 0, R("tirAvance") / 1000)
end

local function vitesseArme()
    local ok, _, _, distance = pcall(UnitAttackSpeed, "player")
    distance = ok and nombre(distance)
    return distance and distance > 0 and distance or nil
end

local function bouge()
    local v = GetUnitSpeed and nombre(GetUnitSpeed("player"))
    return v ~= nil and v > 0
end

local function demander(f, ...)
    if not f then return nil end
    local ok, v = pcall(f, ...)
    if ok and not secret(v) and type(v) == "boolean" then return v end
end

-- Tir auto actif ? nil = on ne sait pas.
local function lireAuto()
    return C_Spell and demander(C_Spell.IsAutoRepeatSpell, sort)
end

local function aPortee()
    return C_Spell and demander(C_Spell.IsSpellInRange, sort, "target")
end

---------------------------------------------------------------------------
-- Dessin
---------------------------------------------------------------------------

local function actif() return sort and not enVeille() and R("tirActif") end

-- Notre barre : visible quand on tire (ou qu'un tir est en cours / attendu).
local function visible()
    if not (propre ~= nil and barre == propre and actif()) then return false end
    local mode = R("tirAffichage")
    return mode == "toujours" or (mode == "combat" and enCombat)
        or auto == true or debut ~= nil or attente ~= nil
end

-- Secondes avant le prochain tir (« 1,5 »), si l'option est cochée.
local function texteTemps()
    if not (R("tirTemps") and debut) then return nil end
    local reste = math.max(0, duree - (GetTime() - debut))
    return (("%.1f"):format(reste):gsub("%.", ","))
end

local function majPropre()
    if not propre then return end
    propre:SetShown(visible() and true or false)
    local l = nombre(propre:GetWidth()) or R("tirLargeur")
    propre.remplissage:SetWidth(math.max(1, fraction * l))
    propre.remplissage:SetShown(fraction > 0)
    propre.temps:SetText(texteTemps() or "")
end

local function remplir(f)
    fraction = math.max(0, math.min(1, f))
    majPropre()
end

local function creerPropre()
    local T = ns.Theme
    local f = CreateFrame("Frame", "SuperGuideBarreTir", UIParent)
    f:SetSize(R("tirLargeur"), 14)
    f:SetClampedToScreen(true)
    ns.Deplacement.inscrire(f, L["Barre de tir"], "barreTir", { "CENTER", 0, -180 })
    f:EnableMouse(false) -- seules les poignées du mode Déplacement la bougent
    local fond = f:CreateTexture(nil, "BACKGROUND")
    fond:SetAllPoints()
    fond:SetColorTexture(0, 0, 0, 0.75)
    f.remplissage = f:CreateTexture(nil, "BORDER")
    f.remplissage:SetPoint("TOPLEFT")
    f.remplissage:SetPoint("BOTTOMLEFT")
    -- Contour d'un pixel, comme la barre d'XP.
    f.contour = CreateFrame("Frame", nil, f)
    f.contour:SetPoint("TOPLEFT", -1, 1)
    f.contour:SetPoint("BOTTOMRIGHT", 1, -1)
    f.contour.bords = {}
    for i, p in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" },
                         { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local t = f.contour:CreateTexture(nil, "OVERLAY")
        t:SetPoint(p[1]); t:SetPoint(p[2])
        if i <= 2 then t:SetHeight(1) else t:SetWidth(1) end
        f.contour.bords[i] = t
    end
    f.temps = ns.Controles.texte(f, "petit", "texte")
    f.temps:SetPoint("CENTER")
    f.temps:SetShadowColor(0, 0, 0, 1)
    f.temps:SetShadowOffset(1, -1)
    f:Hide()
    return f
end

-- Signal : dans la zone, tir actif -> il faut s'arrêter maintenant.
-- Signal « arrête-toi » : dans la zone avec le tir actif. Sur Forever, bouger
-- coupe la baguette : là, il dit « arrête-toi et relance » dès qu'elle est
-- (presque) prête, et reste allumé tant qu'on n'a pas relancé.
local function signal()
    if not (R("tirSignal") and actif()) then return false end
    if auto ~= false then return dedans == true end
    return sort == BAGUETTE and (dedans == true or prete)
end

local function teinte(cle, theme)
    local c = R(cle)
    if c then return c[1], c[2], c[3] end
    return ns.Theme.rgb(theme)
end

local function colorierRemplissage()
    if not propre then return end
    if signal() then propre.remplissage:SetVertexColor(teinte("tirCouleurSignal", "vert"))
    else propre.remplissage:SetVertexColor(teinte("tirCouleurBarre", "accent")) end
end

-- Taille, texture, couleur et contour de notre barre (réglages « Barre » et « Apparence »).
local function habillerPropre()
    if not propre then return end
    propre:SetSize(R("tirLargeur"), R("tirHauteur"))
    propre.remplissage:SetTexture(ns.BarreXP.chemin(R("tirTexture")))
    colorierRemplissage()
    local nom = R("tirContour")
    if nom == "aucun" then propre.contour:Hide(); return end
    local r, g, b = ns.BarreXP.couleurContour(nom)
    for _, t in ipairs(propre.contour.bords) do t:SetColorTexture(r, g, b, 1) end
    propre.contour:Show()
end

local function habiller()
    if not zone then return end
    local c = R("tirCouleur")
    local r, g, b
    if c then r, g, b = c[1], c[2], c[3] else r, g, b = ns.Theme.rgb("rouge") end
    local a = R("tirOpacite")
    if dedans and auto ~= false then a = math.min(1, a + 0.3) end
    zone:SetColorTexture(r, g, b, a)
    ligne:SetColorTexture(r, g, b, 0.95)
    colorierRemplissage()
end

local function changerDedans(oui)
    if dedans == oui then return end
    dedans = oui
    habiller()
end

local function poserZone()
    if not zone then return end
    local d = duree or vitesseArme()
    local l = nombre(barre:GetWidth())
    if not actif() or not d or not l or l <= 0 then
        zone:Hide(); ligne:Hide()
        return
    end
    local x = calculerSeuil(d) / d * l
    if x >= l then zone:Hide(); ligne:Hide(); return end
    zone:ClearAllPoints()
    zone:SetPoint("TOPLEFT", barre, "TOPLEFT", x, 0)
    zone:SetPoint("BOTTOMLEFT", barre, "BOTTOMLEFT", x, 0)
    zone:SetWidth(math.max(1, l - x))
    zone:Show()
    ligne:ClearAllPoints()
    ligne:SetPoint("TOP", barre, "TOPLEFT", x, 0)
    ligne:SetPoint("BOTTOM", barre, "BOTTOMLEFT", x, 0)
    ligne:SetWidth(2)
    ligne:SetShown(x > 0)
end

local function inscrire(e, unite)
    if C_EventUtils and C_EventUtils.IsEventValid and not C_EventUtils.IsEventValid(e) then return end
    if unite and moteur.RegisterUnitEvent then
        pcall(moteur.RegisterUnitEvent, moteur, e, unite)
    else
        pcall(moteur.RegisterEvent, moteur, e)
    end
end

-- Pose la zone sur la barre choisie ; false si celle du jeu n'est pas là.
local function accrocher()
    if barre then return true end
    if R("tirBarre") == "jeu" then
        local f = _G.SwingTimerRangedFrame
        if not (f and f.StatusBar) then return false end
        barre = f.StatusBar
    else
        if not propre then propre = creerPropre(); habillerPropre() end
        barre = propre
    end
    -- Au-dessus du remplissage (ARTWORK 0 chez le jeu, BORDER chez nous).
    local t = textures[barre]
    if not t then
        t = { barre:CreateTexture(nil, "ARTWORK", nil, 6), barre:CreateTexture(nil, "ARTWORK", nil, 7) }
        textures[barre] = t
        if barre.HookScript then barre:HookScript("OnSizeChanged", poserZone) end
    end
    zone, ligne = t[1], t[2]
    zone:Hide(); ligne:Hide()
    dedans = false
    habiller()
    poserZone()
    majPropre()
    return true
end

-- Changement de barre : on quitte l'ancienne.
local function changerBarre()
    if zone then zone:Hide(); ligne:Hide() end
    barre, zone, ligne = nil, nil, nil
    if not accrocher() then inscrire("ADDON_LOADED") end
    majPropre()
end

---------------------------------------------------------------------------
-- Horloge
---------------------------------------------------------------------------

local function arreterHorloge()
    if not debut and not attente then moteur:SetScript("OnUpdate", nil) end
end

local function commencerAttente()
    attente = GetTime()
    attenteFin = attente + ATTENTE_MAX
    poserZone()
    dedans = nil
    changerDedans(true)
    moteur:SetScript("OnUpdate", Tir.tic)
end

local function finAttente()
    if not attente then return end
    attente = nil
    if zone then zone:SetAlpha(1) end
    if not debut then remplir(0) end
    changerDedans(false)
    arreterHorloge()
end

function Tir.tic()
    local now = GetTime()
    if debut then
        local ecoule = now - debut
        if ecoule < duree then
            remplir(ecoule / duree)
            changerDedans(ecoule >= seuilZone)
            return
        end
        debut = nil
        if auto == true then remplir(1); commencerAttente(); return end
        prete = sort == BAGUETTE and auto == false
        remplir(prete and 1 or 0)
        changerDedans(false)
        habiller()
        arreterHorloge()
    elseif attente then
        local t = now - attente
        if now >= attenteFin then
            finAttente()
        elseif R("tirPulsation") and t >= GRACE and zone then
            zone:SetAlpha(0.6 + 0.4 * math.cos((t - GRACE) * math.pi * 2.5))
        end
    else
        arreterHorloge()
    end
end

local function nouveauCycle(d)
    local now = GetTime()
    if arret then Tir.ajouterMesure(mesures(), Tir.mesure(arret, now, allerRetour())) end
    arret, prete = nil, false
    finAttente()
    duree, debut = d, now
    seuilZone = calculerSeuil(d)
    remplir(0)
    poserZone()
    changerDedans(false)
    moteur:SetScript("OnUpdate", Tir.tic)
end

-- Un tir est dû alors qu'aucun cycle ne tourne : on l'attend (ou plus longtemps).
local function tirDu()
    if auto ~= true or debut or aPortee() == false then return end
    if attente then attenteFin = GetTime() + ATTENTE_MAX else commencerAttente() end
end

---------------------------------------------------------------------------
-- Événements
---------------------------------------------------------------------------

local REACTIONS = {}

function REACTIONS.PLAYER_SWING(d, genre)
    d = nombre(d)
    if secret(genre) or genre ~= DISTANCE or not d or d <= 0 then return end
    nouveauCycle(d)
end

function REACTIONS.START_AUTOREPEAT_SPELL()
    auto = true
    -- Immobile et rien en cours : le premier tir ne dépend que de l'armement.
    if not debut and not attente then
        if not bouge() then arret = GetTime() end
        remplir(1) -- arme prête : seul l'armement reste
        commencerAttente()
    end
    habiller()
    majPropre()
end

function REACTIONS.STOP_AUTOREPEAT_SPELL()
    auto, arret = false, nil
    finAttente()
    habiller()
    majPropre()
end

-- Arrêt avec un tir en retard : c'est là que l'armement commence.
function REACTIONS.PLAYER_STOPPED_MOVING()
    if attente and auto == true then arret = arret or GetTime() end
    tirDu()
end

function REACTIONS.PLAYER_STARTED_MOVING() arret = nil end

function REACTIONS.UNIT_SPELLCAST_FAILED_QUIET(_, _, id)
    if not secret(id) and id == sort then tirDu() end
end

function REACTIONS.PLAYER_ENTERING_WORLD()
    -- Un écran de chargement peut avaler STOP_AUTOREPEAT_SPELL.
    auto = lireAuto()
    enCombat = InCombatLockdown() and true or false
    if auto ~= true then finAttente() end
    habiller()
end

function REACTIONS.ADDON_LOADED()
    if accrocher() then moteur:UnregisterEvent("ADDON_LOADED") end
end

local function changementArme()
    if not debut and not attente then duree = nil end
    poserZone()
end
REACTIONS.UNIT_ATTACK_SPEED = changementArme
REACTIONS.PLAYER_EQUIPMENT_CHANGED = changementArme
function REACTIONS.PLAYER_REGEN_DISABLED() enCombat = true; majPropre() end
function REACTIONS.PLAYER_REGEN_ENABLED()
    enCombat = false
    if prete then prete = false; remplir(0); habiller() end
    majPropre()
end
REACTIONS.UI_SCALE_CHANGED = poserZone
REACTIONS.DISPLAY_SIZE_CHANGED = poserZone

function Tir.surEvenement(e, ...)
    if actif() and REACTIONS[e] then REACTIONS[e](...) end
end

function Tir.etat()
    return { debutZone = seuilZone, attente = attente ~= nil, dedans = dedans, remplissage = fraction,
             visible = visible() and true or false, temps = texteTemps(), signal = signal(),
             barre = barre and (barre == propre and "superguide" or "jeu") or nil }
end

function Tir.appliquer(cle)
    if not cle:find("^tir") or not sort then return end
    if cle == "tirBarre" then
        changerBarre()
        if enVeille() then
            ns.Jeu.message(L["Auto Shot / Wand en veille : l'addon ShotWindow est encore activé (désactive-le pour utiliser le module)."])
        end
    end
    habillerPropre()
    if debut then seuilZone = calculerSeuil(duree) end
    if not actif() then finAttente() end
    habiller()
    poserZone()
    majPropre() -- affichage (en tirant / en combat / toujours), activation
end

-- Macro « /cast !Tir » : le « ! » ne coupe pas un tir déjà en cours, on peut
-- donc appuyer à chaque arrêt. Créée pour ce personnage, mise sur le curseur.
function Tir.creerMacro()
    if not sort then
        ns.Jeu.message(L["Auto Shot / Wand : réservé aux chasseurs, mages, prêtres et démonistes."])
        return
    end
    if InCombatLockdown() then
        ns.Jeu.message(L["Impossible en combat : réessaie après le combat."])
        return
    end
    local nom = (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(sort))
        or (GetSpellInfo and GetSpellInfo(sort))
    if not nom then return end
    local corps = "#showtooltip\n/cast !" .. nom
    local i = GetMacroIndexByName(NOM_MACRO)
    if i and i > 0 then
        EditMacro(i, NOM_MACRO, nil, corps)
    else
        local ok, n = pcall(CreateMacro, NOM_MACRO, "INV_MISC_QUESTIONMARK", corps, true)
        if not ok or not n then
            ns.Jeu.message(L["Plus de place pour une macro de personnage : libères-en une et réessaie."])
            return
        end
        i = n
    end
    if PickupMacro then PickupMacro(i) end
    ns.Jeu.message(L["Macro « SG Tir » prête : elle est sur ton curseur, pose-la sur ta barre et appuie dessus à chaque arrêt."])
end

-- /sg tir : la mesure en cours, pour voir quand Blizzard corrige l'armement.
function Tir.rapport()
    if not sort then
        ns.Jeu.message(L["Auto Shot / Wand : réservé aux chasseurs, mages, prêtres et démonistes."])
        return
    end
    if enVeille() then
        ns.Jeu.message(L["Auto Shot / Wand en veille : l'addon ShotWindow est encore activé (désactive-le pour utiliser le module)."])
        return
    end
    local zoneTexte = (("%.2f"):format(armement()):gsub("%.", ","))
    ns.Jeu.message(L["armement du tir : %s, zone utilisée : %s s"]:format(
        Tir.texteArmement(mesures()) or L["pas encore mesuré"], zoneTexte))
end

local function autreAddon()
    local charge = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    return charge and charge("ShotWindow") and true or false
end

function Tir.creer()
    local _, classe = UnitClass("player")
    sort = SORTS[classe]
    shotWindow = false
    if not sort then return end -- chasseurs et porteurs de baguette seulement
    barre, zone, ligne = nil, nil, nil
    debut, attente, arret, duree, seuilZone = nil, nil, nil, nil, nil
    shotWindow = autreAddon()
    if enVeille() then
        ns.Jeu.message(L["Auto Shot / Wand en veille : l'addon ShotWindow est encore activé (désactive-le pour utiliser le module)."])
    end
    moteur = CreateFrame("Frame")
    moteur:SetScript("OnEvent", function(_, e, ...) Tir.surEvenement(e, ...) end)
    -- Barre du jeu : Blizzard_SwingTimer se charge au démarrage, on l'attend.
    if not accrocher() then inscrire("ADDON_LOADED") end
    auto = lireAuto()
    for _, e in ipairs({ "PLAYER_SWING", "START_AUTOREPEAT_SPELL", "STOP_AUTOREPEAT_SPELL",
                         "PLAYER_ENTERING_WORLD", "PLAYER_STARTED_MOVING", "PLAYER_STOPPED_MOVING",
                         "PLAYER_EQUIPMENT_CHANGED", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED",
                         "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
        inscrire(e)
    end
    inscrire("UNIT_SPELLCAST_FAILED_QUIET", "player")
    inscrire("UNIT_ATTACK_SPEED", "player")
end
