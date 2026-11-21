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
      cvars = { { "weatherDensity", "0" }, { "RAIDweatherDensity", "0" } } },
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
      cvars = { { "volumeFog", "0" }, { "volumeFogLevel", "0" } } },
}

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

local CLES = { boostFPS = true, meteoActif = true, sansMeteo = true, sansBrouillard = true, spyDetection = true, softInteract = true }
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
        if ns.Jeu.cvar(nom) ~= nil then ns.Jeu.ecrireCvar(nom, v) end
    end
    sauvegarde[g.nom] = nil
end

-- Met le jeu d'accord avec les réglages ; en combat, attend la sortie.
function Graphismes.synchroniser()
    if ns.Jeu.enCombat() then
        if not enAttente then
            enAttente = true
            ns.Jeu.message(L["graphismes : changés à la sortie du combat"])
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
                ns.Jeu.message(L["%s : activé (coupe-le pour retrouver tes réglages)"]:format(g.titre))
            elseif g.tenir then
                poser(g, sauvegarde)
            end
        elseif deja then
            rendre(g, sauvegarde)
            ns.Jeu.message(L["%s : tes réglages d'avant sont revenus"]:format(g.titre))
        end
    end
end

-- Réglages « surveiller » : si le jeu en change un (qualité graphique, menu
-- Options), on le remet un instant après. Pas les autres : la pêche change
-- la portée d'interaction le temps d'une session.
local SURVEILLES, prevu = {}, false
for _, g in ipairs(Graphismes.GROUPES) do
    for _, c in ipairs(g.cvars) do
        if c.surveiller then SURVEILLES[c[1]:lower()] = true end
    end
end

function Graphismes.surCvar(nom)
    if type(nom) ~= "string" or not SURVEILLES[nom:lower()] or prevu then return end
    prevu = true
    C_Timer.After(0.5, function()
        prevu = false
        Graphismes.synchroniser()
    end)
end

function Graphismes.sortieCombat()
    if enAttente then Graphismes.synchroniser() end
end

-- Écouteur des réglages.
function Graphismes.appliquer(cle)
    if CLES[cle] then Graphismes.synchroniser() end
end
