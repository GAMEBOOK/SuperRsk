-- Boost FPS et Météo / brouillard : des réglages du jeu (CVars) changés pour
-- gagner des images par seconde ou une vue dégagée. Les valeurs d'avant sont
-- gardées dans SuperGuideDB.graphismesAvant et rendues quand on coupe.
--
-- Boost FPS n'est écrit qu'une fois (tes retouches ensuite restent) ; chaque
-- réglage porte son libellé et sa valeur lisibles (carte « Ce que ça change »). Météo et
-- brouillard sont réécrits à chaque passage : le jeu les remet quand on
-- change de qualité graphique. Rien n'est écrit en combat.

local ADDON, ns = ...

local Graphismes = {}
ns.Graphismes = Graphismes

local L = ns.L or setmetatable({}, { __index = function(_, k) return k end })
local function R(cle) return ns.Reglages.get(cle) end

Graphismes.GROUPES = {
    { nom = "boost", titre = "Boost FPS",
      actif = function() return R("boostFPS") == true end,
      cvars = {
          { "graphicsShadowQuality", "1", L["Ombres"], L["Faibles"] },     -- ombres : correctes
          { "graphicsLiquidDetail", "0", L["Détail de l'eau"], L["Faible"] },
          { "graphicsParticleDensity", "5", L["Densité des particules"], L["Élevée (effets de sorts gardés)"] },   -- effets de sorts importants gardés
          { "graphicsSSAO", "0", L["Occlusion ambiante (SSAO)"], L["Coupée"] },
          { "graphicsDepthEffects", "0", L["Effets de profondeur"], L["Coupés"] },
          { "graphicsComputeEffects", "0", L["Effets calculés"], L["Coupés"] },
          { "graphicsOutlineMode", "0", L["Contours en surbrillance"], L["Coupés"] },
          { "graphicsTextureResolution", "2", L["Résolution des textures"], L["Haute"] }, -- textures : hautes
          { "graphicsSpellDensity", "0", L["Densité des sorts des autres"], L["Essentiels"] },
          { "graphicsProjectedTextures", "1", L["Textures projetées (effets au sol)"], L["Gardées"] }, -- effets au sol visibles
          { "graphicsViewDistance", "0", L["Distance de vue"], L["Courte"] },
          { "graphicsEnvironmentDetail", "0", L["Détails du décor"], L["Faibles"] },
          { "graphicsGroundClutter", "0", L["Herbes et petits objets au sol"], L["Faibles"] },
          { "RAIDsettingsEnabled", "0", L["Réglages à part en raid et donjon"], L["Non, les mêmes partout"] },       -- mêmes réglages en raid et donjon
          { "ResampleAlwaysSharpen", "1", L["Netteté de l'image"], L["Activée"] },     -- image plus nette
          { "Sound_EnableReverb", "0", L["Réverbération du son"], L["Coupée"] },
      } },
    { nom = "meteo", titre = L["Météo"], tenir = true,
      actif = function() return R("meteoActif") == true and R("sansMeteo") ~= false end,
      cvars = { { "weatherDensity", "0", surveiller = true }, { "RAIDweatherDensity", "0", surveiller = true },
                -- Sur Forever, pluie et neige sont dessinées par les « particulates »
                -- (constaté le 24/11/2026 : à 0, plus de gouttes).
                { "particulatesEnabled", "0", surveiller = true }, { "RAIDparticulatesEnabled", "0", surveiller = true } } },
    -- Bruit de la pluie : le son d'ambiance, coupé seulement tant qu'il pleut,
    -- neige ou souffle du sable ; rendu dès que le temps se dégage.
    { nom = "sonMeteo", titre = L["Bruit de la météo"], tenir = true, muet = true,
      actif = function() return R("meteoActif") == true and R("sansSonMeteo") == true
          and ns.Jeu.cvar("Sound_EnableSFX") ~= "0" and ns.Jeu.ilPleut() end,
      -- Ctrl+S (son du jeu) bascule bruitages et ambiance ensemble. Son coupé
      -- par le joueur : on ne touche à rien, et l'ambiance n'est pas rallumée.
      rendre = function(v) return ns.Jeu.cvar("Sound_EnableSFX") == "0" and "0" or v end,
      cvars = { { "Sound_EnableAmbience", "0", surveiller = true } } },
    -- Spy (Forever) ne voit les ennemis que par les plaques de nom, la cible et
    -- le survol (journal de combat fermé aux addons) : plaques ennemies
    -- toujours affichées, et de plus loin.
    { nom = "spyPlaques", titre = L["Détection Spy"], tenir = true,
      actif = function() return R("spyDetection") == true and _G.Spy ~= nil end,
      cvars = { { "nameplateShowAll", "1" }, { "nameplateShowEnemies", "1" }, { "nameplateMaxDistance", "41" } } },
    -- Interaction rapide : réglages validés en jeu sur
    -- Forever. Le ciblage souple vise aussi les objets (filons, plantes,
    -- coffres, objets de quête, bouchon de pêche) tout autour, sur 20 m, avec
    -- une icône au-dessus ; la touche « Interagir avec la cible » les prend.
    -- SoftTargetIconGameObject à 1 est indispensable : à 0, le jeu ne vise pas
    -- les objets. SoftTargetNameplateInteract à 0 : à 1, l'icône part sur la
    -- plaque de nom de l'objet, et les objets n'en ont pas sur Forever, donc
    -- plus d'icône du tout (constaté le 18/11/2026).
    -- Contours coupés mais scintillement gardé : les objets avec lesquels on
    -- peut interagir brillent (graphicsOutlineMode 0 et
    -- outlineModeShowLootEffectWhenDisabled 1), remis si le jeu les change.
    { nom = "softInteract", titre = L["Interaction rapide"], tenir = true,
      actif = function() return R("softInteract") == true end,
      cvars = { { "SoftTargetInteract", "3" }, { "SoftTargetInteractArc", "2" },
                { "SoftTargetIconGameObject", "1" }, { "SoftTargetLowPriorityIcons", "1" },
                { "SoftTargetInteractRange", "20" }, { "SoftTargetNameplateInteract", "0" },
                { "graphicsOutlineMode", "0", surveiller = true },
                { "outlineModeShowLootEffectWhenDisabled", "1", surveiller = true } } },
    { nom = "brouillard", titre = L["Brouillard"], tenir = true,
      actif = function() return R("meteoActif") == true and R("sansBrouillard") ~= false end,
      -- Changer « Effets calculés » ou la qualité graphique les remet tous à 1
      -- (constaté le 24/11/2026) : surveillés, et le jeu les relit aussitôt.
      cvars = { { "volumeFog", "0", surveiller = true }, { "volumeFogLevel", "0", surveiller = true },
                { "volumeFogInterior", "0", surveiller = true }, { "RAIDvolumeFog", "0", surveiller = true },
                { "RAIDvolumeFogLevel", "0", surveiller = true } } },
}

-- Effets à couper un par un (page « Météo et effets ») : { réglage, titre, cvars }.
for _, x in ipairs({
    { "fxRayons", L["Rayons du soleil"], { { "sunShafts", "0" }, { "RAIDsunShafts", "0" } } },
    { "fxHalo", L["Halo lumineux"], { { "ffxGlow", "0" } } },
    { "fxMort", L["Écran gris de la mort"], { { "ffxDeath", "0" } } },
    { "fxNether", L["Voile d'invisibilité"], { { "ffxNether", "0" } } },
    { "fxSecousses", L["Secousses de l'écran"], { { "ShakeStrengthCamera", "0" }, { "ShakeStrengthUI", "0" } } },
    { "fxFlash", L["Flashs rouges au bord de l'écran"], { { "screenEdgeFlash", "0" }, { "doNotFlashLowHealthWarning", "1" } } },
    { "fxEmpreintes", L["Traces de pas"], { { "showfootprintparticles", "0" } } },
    { "fxPas", L["Bruit des pas"], { { "FootstepSounds", "0" } } },
    { "fxErreurs", L["Phrases d'erreur"], { { "Sound_EnableErrorSpeech", "0" } } },
    { "fxMusique", L["Musique du jeu"], { { "Sound_EnableMusic", "0" } } },
    { "fxEmotes", L["Son des emotes"], { { "Sound_EnableEmoteSounds", "0" } } },
}) do
    local cle = x[1]
    table.insert(Graphismes.GROUPES, { nom = cle, titre = x[2], tenir = true, muet = true, cvars = x[3],
        actif = function() return R("meteoActif") == true and R(cle) == true end })
end

-- Lignes { libellé, valeur } d'un groupe, pour la page du module.
function Graphismes.details(nom)
    local l = {}
    for _, g in ipairs(Graphismes.GROUPES) do
        if g.nom == nom then
            for _, c in ipairs(g.cvars) do
                if c[3] then l[#l + 1] = { c[3], c[4] } end
            end
        end
    end
    return l
end

local CLES = { boostFPS = true, meteoActif = true, sansMeteo = true, sansBrouillard = true, sansSonMeteo = true, spyDetection = true, softInteract = true }
for _, g in ipairs(Graphismes.GROUPES) do if g.nom:find("^fx") then CLES[g.nom] = true end end
local enAttente = false

local function avant()
    SuperGuideDB = SuperGuideDB or {}
    SuperGuideDB.graphismesAvant = SuperGuideDB.graphismesAvant or {}
    return SuperGuideDB.graphismesAvant
end

-- Écrit les valeurs du groupe ; garde d'abord celles d'avant (une seule fois).
-- Un réglage que ce client n'a pas est sauté. Rend true si quelque chose a changé.
local function poser(g, sauvegarde)
    local jeu, change = ns.Jeu, false
    local garde = sauvegarde[g.nom] or {}
    sauvegarde[g.nom] = garde
    -- Un réglage ajouté dans une version plus récente est gardé lui aussi.
    for _, c in ipairs(g.cvars) do
        if garde[c[1]] == nil then garde[c[1]] = jeu.cvar(c[1]) end
    end
    for _, c in ipairs(g.cvars) do
        local actuel = jeu.cvar(c[1])
        -- « min » : seulement si la valeur du joueur est plus petite.
        local deja = c.min and tonumber(actuel) and tonumber(actuel) >= tonumber(c[2])
        if actuel ~= nil and actuel ~= c[2] and not deja then
            jeu.ecrireCvar(c[1], c[2])
            change = true
        end
    end
    return change
end

local function rendre(g, sauvegarde)
    for nom, v in pairs(sauvegarde[g.nom]) do
        if ns.Jeu.cvar(nom) ~= nil then ns.Jeu.ecrireCvar(nom, g.rendre and g.rendre(v) or v) end
    end
    sauvegarde[g.nom] = nil
end

-- Met le jeu d'accord avec les réglages ; en combat, attend la sortie.
function Graphismes.synchroniser(muet)
    if ns.Jeu.enCombat() then
        if not enAttente then
            enAttente = true
            if not muet then ns.Jeu.message(L["graphismes : changés à la sortie du combat"]) end
        end
        return
    end
    enAttente = false
    local sauvegarde = avant()
    for _, g in ipairs(Graphismes.GROUPES) do
        local deja = sauvegarde[g.nom] ~= nil
        if g.actif() then
            if not deja then
                poser(g, sauvegarde)
                if not g.muet then ns.Jeu.message(L["%s : activé (coupe-le pour retrouver tes réglages)"]:format(g.titre)) end
            elseif g.tenir then
                poser(g, sauvegarde)
            end
        elseif deja then
            rendre(g, sauvegarde)
            if not g.muet then ns.Jeu.message(L["%s : tes réglages d'avant sont revenus"]:format(g.titre)) end
        end
    end
end

-- Réglages « surveiller » : si le jeu en change un (qualité graphique, menu
-- Options), on le remet un instant après. Pas les autres : la pêche change
-- la portée d'interaction le temps d'une session.
-- graphicsComputeEffects et graphicsQuality : eux-mêmes libres, mais ils
-- entraînent le brouillard (le jeu ne prévient pas toujours pour lui).
-- Au plus REMISES remises par minute : si le jeu insiste, on le laisse.
local SURVEILLES, prevu = { graphicscomputeeffects = true, graphicsquality = true, sound_enablesfx = true }, false
local REMISES, faites, depuis = 10, 0, nil
for _, g in ipairs(Graphismes.GROUPES) do
    for _, c in ipairs(g.cvars) do
        if c.surveiller then SURVEILLES[c[1]:lower()] = true end
    end
end

function Graphismes.surCvar(nom)
    if Graphismes.antiBrume then return end   -- c'est la bascule qui écrit
    if type(nom) ~= "string" or not SURVEILLES[nom:lower()] or prevu then return end
    local t = GetTime and GetTime() or 0
    if not depuis or t - depuis > 60 then depuis, faites = t, 0 end
    if faites >= REMISES then return end
    faites = faites + 1
    prevu = true
    C_Timer.After(0.5, function()
        prevu = false
        Graphismes.synchroniser(true)
    end)
end

-- La météo change : bruit de la pluie coupé ou rendu.
function Graphismes.surMeteo()
    if R("meteoActif") == true and R("sansSonMeteo") == true then Graphismes.synchroniser(true) end
end

function Graphismes.sortieCombat()
    if enAttente then Graphismes.synchroniser() end
end

-- Écouteur des réglages.
function Graphismes.appliquer(cle)
    if CLES[cle] then Graphismes.synchroniser() end
end

---------------------------------------------------------------------------
-- Anti-brume (/sg fog, macro) : le jeu dessine le brouillard volumétrique
-- même réglé à 0, mais repart de zéro à chaque changement de
-- volumeFogLevel. Changé à chaque image, il n'a pas le temps d'apparaître.
-- Très gourmand (environ la moitié des FPS) : jamais allumé tout seul,
-- éteint au rechargement.
---------------------------------------------------------------------------

local cadreBrume, CVAR_BRUME = nil, "volumeFogLevel"
local NOM_MACRO = "SG Brume"

-- Niveau d'avant rendu (après un rechargement ou un plantage aussi).
function Graphismes.rendreBrume()
    local v = SuperGuideDB and SuperGuideDB.brumeAvant
    if v == nil then return end
    if pcall(ns.Jeu.ecrireCvar, CVAR_BRUME, v) then SuperGuideDB.brumeAvant = nil end
end

local function eteindre(texte)
    Graphismes.antiBrume = nil
    if cadreBrume then cadreBrume:SetScript("OnUpdate", nil) end
    Graphismes.rendreBrume()
    ns.Jeu.message(texte)
end

function Graphismes.basculerBrume()
    if Graphismes.antiBrume then return eteindre(L["Anti-brume éteint."]) end
    local avantBrume = ns.Jeu.cvar(CVAR_BRUME)
    if avantBrume == nil then return ns.Jeu.message(L["Anti-brume : le jeu a refusé, il est éteint."]) end
    SuperGuideDB = SuperGuideDB or {}
    SuperGuideDB.brumeAvant = avantBrume
    Graphismes.antiBrume = true
    cadreBrume = cadreBrume or CreateFrame("Frame")
    local v = 0
    cadreBrume:SetScript("OnUpdate", function()
        v = 1 - v
        if not pcall(ns.Jeu.ecrireCvar, CVAR_BRUME, tostring(v)) then
            eteindre(L["Anti-brume : le jeu a refusé, il est éteint."])
        end
    end)
    ns.Jeu.message(L["Anti-brume allumé : tes FPS baissent beaucoup. Même macro (ou /sg fog) pour l'éteindre."])
end

function Graphismes.creerMacroBrouillard()
    if ns.Jeu.enCombat() then
        return ns.Jeu.message(L["Impossible en combat : réessaie après le combat."])
    end
    local function creer()
        if ns.Jeu.enCombat() then return end
        local i = GetMacroIndexByName(NOM_MACRO)
        if not i or i == 0 then
            local ok, n = pcall(CreateMacro, NOM_MACRO, "Spell_Holy_SearingLight", "/sg fog", true)
            if not ok or not n then
                return ns.Jeu.message(L["Plus de place pour une macro de personnage : libères-en une et réessaie."])
            end
            i = n
        end
        if PickupMacro then PickupMacro(i) end
        ns.Jeu.message(L["Macro « SG Brume » prête : elle est sur ton curseur, pose-la sur ta barre."])
    end
    ns.Menu.confirmer(L["ATTENTION : cette macro enlève toute la brume, mais elle fait chuter tes images par seconde (environ la moitié). À allumer seulement quand la brume te gêne. Elle s'éteint au rechargement. Blizzard a retiré le réglage officiel : un patch peut la casser. Créer la macro ?"], creer)
end
