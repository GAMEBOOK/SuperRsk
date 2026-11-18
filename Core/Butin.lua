-- Auto Loot (ex-addon SuperAutoLoot) : décisions pures du ramassage rapide.
--
-- UI/Butin.lua lit le jeu (emplacements, sacs, messages) et applique ce que
-- ces fonctions décident ; elles se testent hors jeu.

local ADDON, ns = ...

local Butin = {}
ns.Butin = Butin

-- Seuil « personne ne bloque » : aucune qualité n'atteint 10.
local SANS_SEUIL = 10
local FAMILLE_CLE = 256

-- L'objet tient-il dans les sacs ?
-- o = { famille, pile, possede, quantite } (famille et pile nil si l'objet
-- n'est pas encore en cache) ; sacs = { porteCles = cases libres,
-- { libres, famille }, … } (famille 0 ou nil = sac ordinaire).
function Butin.tientDansSacs(o, sacs)
    local famille, pile, possede = o.famille or 0, o.pile or 1, o.possede or 0
    if famille == FAMILLE_CLE and (sacs.porteCles or 0) > 0 then return true end
    -- Place restante dans la dernière pile entamée.
    if possede > 0 and pile > 1 and (pile - possede) % pile >= (o.quantite or 1) then return true end
    for _, s in ipairs(sacs) do
        if s.libres > 0 and (not s.famille or s.famille == 0 or bit.band(famille, s.famille) > 0) then
            return true
        end
    end
    return false
end

-- Qualité à partir de laquelle on laisse la main au groupe (jet de dés,
-- maître du butin) ; hors groupe ou sans partage, on ramasse tout.
function Butin.seuil(enGroupe, partage, seuilJeu)
    if enGroupe and partage then return seuilJeu end
    return SANS_SEUIL
end

-- Que faire d'un emplacement : « vide », « bloque » (verrouillé ou au-dessus
-- du seuil : la fenêtre du jeu s'ouvre), « ramasser » ou « plein ».
-- slot = { type = "aucun" | "objet" | autre (argent, monnaie), verrouille, qualite }.
function Butin.decision(slot, seuil, tient)
    if slot.type == "aucun" then return "vide" end
    if slot.verrouille or (slot.qualite and slot.qualite >= seuil) then return "bloque" end
    if slot.type ~= "objet" or tient() then return "ramasser" end
    return "plein"
end

-- Message de butin du chat : lien de l'objet et quantité (1 si absente).
function Butin.lireMessage(msg)
    local lien = msg:match("(|c.-|h|r)")
    if not lien then return nil, nil end
    local reste = msg:gsub("|c.-|h|r", "")
    return lien, tonumber(reste:match("(%d+)")) or 1
end
