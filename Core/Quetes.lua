-- Récompense de quête (Auto Equip, « Choisir la meilleure récompense ») :
-- quand le jeu demande de choisir parmi plusieurs objets, la meilleure pour
-- le personnage est sélectionnée (sinon la plus chère à revendre). Rien
-- n'est rendu à ta place : tu cliques « Terminer ». Maj enfoncée : rien.

local ADDON, ns = ...

local Quetes = {}
ns.Quetes = Quetes

local L = ns.L or setmetatable({}, { __index = function(_, k) return k end })

-- Réessai : toutes les 0,15 s pendant 2,5 s au plus (objets pas encore en cache).
local DELAI, ESSAIS = 0.15, 16

-- Sélectionne la récompense n dans la fenêtre du jeu (comme un clic dessus).
local function selectionner(n)
    local cadre = QuestInfoRewardsFrame
    local boutons = cadre and cadre.RewardButtons
    local b = boutons and boutons[n]
    if b and QuestInfoItem_OnClick then
        pcall(QuestInfoItem_OnClick, b)
        return true
    end
    if QuestInfoFrame then QuestInfoFrame.itemChoice = n end
    return false
end

local function choisir(essai)
    local jeu, R = ns.Jeu, ns.Reglages
    if not (R and R.get("choisirRecompense") and R.get("proposerEquipement") ~= false) then return end
    if jeu.enCombat() or (jeu.majEnfoncee and jeu.majEnfoncee()) then return end
    local nb = jeu.nbRecompenses()
    if nb <= 1 then return end
    local r = ns.Equipement.choisirRecompense(nb)
    if r == "attendre" then
        if essai < ESSAIS then jeu.plusTard(DELAI, function() choisir(essai + 1) end) end
        return
    end
    if r then
        selectionner(r)
        local lien = GetQuestItemLink and GetQuestItemLink("choice", r)
        if lien then jeu.message(L["Meilleure récompense pour toi : %s"]:format(lien)) end
    end
end

function Quetes.surEvenement(evenement)
    if evenement == "QUEST_COMPLETE" then choisir(1) end
end

Quetes.evenements = { "QUEST_COMPLETE" }
