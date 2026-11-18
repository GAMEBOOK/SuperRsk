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
