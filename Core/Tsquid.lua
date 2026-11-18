-- Tsquid Area : petits plus à la demande de Tsquid.
--
-- Son sur coup critique : un son quand ta cible encaisse un coup critique.
-- Sur Forever, le journal de combat est fermé aux addons ; UNIT_COMBAT
-- (unité, action, « CRITICAL », montant, école) reste ouvert et dit qu'un
-- coup sur la cible était critique, mais pas de qui il vient : en groupe,
-- les critiques des autres sur ta cible sonnent aussi.

local ADDON, ns = ...

local Tsquid = {}
ns.Tsquid = Tsquid

local L = ns.L or setmetatable({}, { __index = function(_, k) return k end })
local function R(cle) return ns.Reglages.get(cle) end

Tsquid.SON = "Interface\\AddOns\\" .. ADDON .. "\\Media\\Sons\\sabre_laser_critical_hit.mp3"
Tsquid.ECART = 0.12   -- deux critiques collés (double frappe) : un seul son
-- Canaux de son du jeu (Options > Son) ; le volume de chacun s'y règle.
Tsquid.CANAUX = { Master = true, SFX = true, Music = true, Ambience = true, Dialog = true }

function Tsquid.canal()
    local c = R("tsquidCanal")
    return Tsquid.CANAUX[c] and c or "Master"
end

local function lisible(v) return not (issecretvalue and issecretvalue(v)) end

-- Un coup critique sur la cible, à faire sonner ?
function Tsquid.estCritique(unite, action, drapeau)
    if R("tsquidActif") == false or R("tsquidCritSon") == false then return false end
    if not (lisible(unite) and lisible(action) and lisible(drapeau)) then return false end
    if unite ~= "target" or action ~= "WOUND" or drapeau ~= "CRITICAL" then return false end
    -- Un ennemi (pas un allié soigné ou un mannequin d'un autre).
    local ok, ennemi = pcall(UnitCanAttack, "player", "target")
    return ok and lisible(ennemi) and ennemi == true
end

local dernier = -1000
function Tsquid.jouer(force)
    local t = GetTime and GetTime() or 0
    if not force and t - dernier < Tsquid.ECART then return false end
    dernier = t
    local joue = PlaySoundFile and PlaySoundFile(Tsquid.SON, Tsquid.canal())
    return joue ~= false
end

function Tsquid.surCombat(unite, action, drapeau)
    if Tsquid.estCritique(unite, action, drapeau) then return Tsquid.jouer() end
    return false
end

function Tsquid.creer()
    local f = CreateFrame("Frame")
    if f.RegisterUnitEvent then
        pcall(f.RegisterUnitEvent, f, "UNIT_COMBAT", "target")
    else
        pcall(f.RegisterEvent, f, "UNIT_COMBAT")
    end
    f:SetScript("OnEvent", function(_, _, unite, action, drapeau)
        pcall(Tsquid.surCombat, unite, action, drapeau)
    end)
end

-- Bouton du module : écouter le son.
function Tsquid.tester()
    if not Tsquid.jouer(true) and ns.Jeu and ns.Jeu.message then
        ns.Jeu.message(L["Son introuvable : le jeu ne voit les nouveaux fichiers d'un addon qu'au lancement. Quitte et relance complètement le jeu (un /reload ne suffit pas)."])
    end
end
