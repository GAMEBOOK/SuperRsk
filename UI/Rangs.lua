-- Auto Spell Ranks : lit le grimoire et les barres d'action, puis remplace
-- hors combat chaque bouton d'un ancien rang par le plus haut, au même
-- endroit. Tous les emplacements d'action sont parcourus (barres du mode
-- manette comprises). Décisions dans Core/Rangs.lua.

local ADDON, ns = ...

local Rangs = ns.Rangs
local function R(cle) return ns.Reglages.get(cle) end

local MAX_EMPLACEMENT = 300
local enAttente, prevu = false, false
local evenements

local function nomSort(id)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    return GetSpellInfo and (GetSpellInfo(id))
end

local function sousTexte(id)
    if C_Spell and C_Spell.GetSpellSubtext then return C_Spell.GetSpellSubtext(id) end
    return GetSpellSubtext and GetSpellSubtext(id)
end

local function sort(id)
    local texte = sousTexte(id)
    return { id = id, nom = nomSort(id), rang = Rangs.numero(texte), texte = texte }
end

-- Sorts appris du grimoire du joueur (pas les « à venir »).
local function grimoire()
    local sorts = {}
    local SB = C_SpellBook
    if SB and SB.GetNumSpellBookSkillLines and SB.GetSpellBookItemInfo then
        local banque = Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
        local typeSort = Enum.SpellBookItemType and Enum.SpellBookItemType.Spell
        for l = 1, SB.GetNumSpellBookSkillLines() or 0 do
            local ligne = SB.GetSpellBookSkillLineInfo(l)
            for i = ligne.itemIndexOffset + 1, ligne.itemIndexOffset + ligne.numSpellBookItems do
                local info = SB.GetSpellBookItemInfo(i, banque)
                if info and info.spellID and info.itemType == typeSort then sorts[#sorts + 1] = sort(info.spellID) end
            end
        end
    elseif GetNumSpellTabs then
        for t = 1, GetNumSpellTabs() do
            local _, _, debut, n = GetSpellTabInfo(t)
            for i = debut + 1, debut + n do
                local genre, id = GetSpellBookItemInfo(i, BOOKTYPE_SPELL or "spell")
                if genre == "SPELL" and id then sorts[#sorts + 1] = sort(id) end
            end
        end
    end
    return sorts
end

-- Boutons de sort simples ; macros, objets et cases vides sont ignorés.
local function boutons()
    local l = {}
    for slot = 1, MAX_EMPLACEMENT do
        if HasAction(slot) then
            local genre, id = GetActionInfo(slot)
            if genre == "spell" and id then
                local s = sort(id)
                s.slot = slot
                l[#l + 1] = s
            end
        end
    end
    return l
end

local function poser(slot, id)
    local prendre = (C_Spell and C_Spell.PickupSpell) or PickupSpell
    prendre(id)
    PlaceAction(slot)
    ClearCursor() -- l'ancien rang, rendu par PlaceAction
end

function Rangs.verifier()
    if not R("rangsAuto") then return end
    if InCombatLockdown() then enAttente = true; return end
    -- Un objet tenu à la souris serait perdu : on réessaie plus tard.
    if GetCursorInfo and GetCursorInfo() then C_Timer.After(2, Rangs.verifier); return end
    enAttente = false
    local echanges, bilan = Rangs.plan(boutons(), Rangs.meilleurs(grimoire()))
    for _, e in ipairs(echanges) do poser(e.slot, e.id) end
    if R("rangsMessage") then
        for _, l in ipairs(bilan) do ns.Jeu.message(Rangs.message(l)) end
    end
end

-- Plusieurs sorts appris d'un coup chez le maître : une seule vérification,
-- une seconde après (le grimoire se met à jour).
local function bientot()
    if prevu then return end
    prevu = true
    C_Timer.After(1, function() prevu = false; Rangs.verifier() end)
end

function Rangs.surEvenement(e)
    if e == "PLAYER_REGEN_ENABLED" then
        if enAttente then Rangs.verifier() end
    else
        bientot()
    end
end

function Rangs.appliquer(cle)
    if cle == "rangsAuto" and R("rangsAuto") then Rangs.verifier() end
end

local function inscrire(e)
    if C_EventUtils and C_EventUtils.IsEventValid and not C_EventUtils.IsEventValid(e) then return end
    pcall(evenements.RegisterEvent, evenements, e)
end

function Rangs.creer()
    evenements = CreateFrame("Frame")
    evenements:SetScript("OnEvent", function(_, e) Rangs.surEvenement(e) end)
    -- Selon le client, un seul des deux existe.
    inscrire("LEARNED_SPELL_IN_SKILL_LINE")
    inscrire("LEARNED_SPELL_IN_TAB")
    inscrire("PLAYER_REGEN_ENABLED")
    C_Timer.After(5, Rangs.verifier)
end

---------------------------------------------------------------------------
-- Aperçu (page du module) : une fausse barre d'actions où « Boule de feu »
-- passe du rang 2 au rang 3, en boucle, pour montrer ce que fait le module.
---------------------------------------------------------------------------

local L = ns.L or setmetatable({}, { __index = function(_, k) return k end })
local ICONES = { "Spell_Fire_FlameBolt", "Spell_Frost_FrostBolt02", "Spell_Holy_FlashHeal",
                 "Ability_Marksmanship", "Spell_Nature_Lightning", "Spell_Shadow_ShadowBolt" }
local CIBLE = 1               -- le bouton qui change de rang
local CYCLE = 5.2             -- durée d'une boucle (s)
local demo

-- Badge court « R3 » (comme le jeu, sans traduction).
local function rangTexte(n) return ("R%d"):format(n) end

local function creerDemo()
    local T, C = ns.Theme, ns.Controles
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetSize(330, 92)
    f.boutons = {}
    for i, nom in ipairs(ICONES) do
        local b = CreateFrame("Frame", nil, f)
        b:SetSize(38, 38)
        b:SetPoint("TOPLEFT", 16 + (i - 1) * 50, -30)
        T.fond(b, "sombre", 1, "bordFort")
        b.icone = b:CreateTexture(nil, "ARTWORK")
        b.icone:SetPoint("TOPLEFT", 2, -2)
        b.icone:SetPoint("BOTTOMRIGHT", -2, 2)
        b.icone:SetTexture("Interface\\Icons\\" .. nom)
        b.icone:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        b.touche = C.texte(b, "petit", "texteDoux")
        b.touche:SetPoint("TOPRIGHT", -2, -2)
        b.touche:SetText(tostring(i))
        f.boutons[i] = b
    end
    local cible = f.boutons[CIBLE]
    -- Badge de rang, éclat blanc, halo et « +1 ».
    cible.rang = C.texte(cible, "petit", "texte")
    cible.rang:SetPoint("BOTTOMRIGHT", -2, 3)
    cible.eclat = cible:CreateTexture(nil, "OVERLAY")
    cible.eclat:SetAllPoints(cible.icone)
    cible.eclat:SetColorTexture(1, 1, 1)
    cible.halo = cible:CreateTexture(nil, "BACKGROUND", nil, -1)
    cible.halo:SetPoint("TOPLEFT", -5, 5)
    cible.halo:SetPoint("BOTTOMRIGHT", 5, -5)
    cible.halo:SetColorTexture(T.rgb("accent"))
    cible.plus = C.texte(cible, "texte", "vert")
    cible.plus:SetPoint("BOTTOM", cible, "TOP", 0, 2)
    cible.plus:SetText("+1")
    -- Bandeau « nouveau sort appris » et explication.
    f.bandeau = C.texte(f, "petit", "orange")
    f.bandeau:SetPoint("TOPLEFT", 16, -8)
    f.bandeau:SetText(L["Nouveau sort appris : %s (%s)"]:format(L["Boule de feu"], L["Rang %d"]:format(3)))
    f.explication = C.texte(f, "petit", "texteDoux")
    f.explication:SetPoint("TOPLEFT", 16, -74)
    f.explication:SetText(L["%s → %s sur ta barre · tes macros ne bougent pas"]:format(L["Rang %d"]:format(2), L["Rang %d"]:format(3)))
    f:Hide()
    return f
end

-- Une image de la scène, t = temps dans la boucle.
local function scene(t)
    local c = demo.boutons[CIBLE]
    local function fondu(a, b) return math.max(0, math.min(1, (t - a) / (b - a))) end
    local appris = t >= 1.8 and t < 4.6
    demo.bandeau:SetAlpha(t < 0.4 and 0 or (t < 3.6 and fondu(0.4, 0.9) or 1 - fondu(3.6, 4.2)))
    c.rang:SetText(rangTexte(appris and 3 or 2))
    c.rang:SetTextColor(ns.Theme.rgb(appris and "vert" or "texte"))
    c.halo:SetAlpha(t >= 1.0 and t < 2.6 and (0.35 + 0.35 * math.sin((t - 1.0) * math.pi * 3)) or 0)
    c.eclat:SetAlpha(t >= 1.8 and math.max(0, 0.8 - (t - 1.8) * 2) or 0)
    c.plus:SetAlpha(t >= 1.8 and t < 3.0 and (1 - fondu(2.2, 3.0)) or 0)
    c.plus:SetPoint("BOTTOM", c, "TOP", 0, 2 + (t >= 1.8 and math.min(14, (t - 1.8) * 16) or 0))
    demo.explication:SetAlpha(appris and fondu(2.0, 2.5) or 0)
end

function Rangs.vitrine()
    if not demo then demo = creerDemo() end
    return demo, "rangsApercu"
end

function Rangs.apercu(oui)
    Rangs.vitrine()
    if oui then
        demo.debut = GetTime()
        scene(0)
        demo:Show()
        demo:SetScript("OnUpdate", function(self)
            scene(((GetTime() - self.debut) % CYCLE))
        end)
    else
        demo:SetScript("OnUpdate", nil)
        demo:Hide()
    end
end
