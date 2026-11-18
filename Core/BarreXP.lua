-- Barre d'XP : calculs purs (aucun appel au jeu), testés hors jeu.
local ADDON, ns = ...

local BarreXP = {}
ns.BarreXP = BarreXP

local floor, max, min = math.floor, math.max, math.min

-- Fractions (0 à 1) de la barre, coupées dans l'ordre pour que la somme ≤ 1.
function BarreXP.segments(xp, total, termine, enCours, repos)
    local s = { xp = 0, termine = 0, enCours = 0, repos = 0 }
    if not total or total <= 0 then return s end
    local reste = 1
    for _, k in ipairs({ "xp", "termine", "enCours", "repos" }) do
        local v = ({ xp = xp, termine = termine, enCours = enCours, repos = repos })[k] or 0
        local f = min(max(v / total, 0), reste)
        s[k] = f
        reste = reste - f
    end
    return s
end

-- Pourcentage à une décimale, arrondi.
function BarreXP.pourcent(n, total)
    if not total or total <= 0 then return 0 end
    return floor(n / total * 1000 + 0.5) / 10
end

function BarreXP.pct(v, fr)
    local t = string.format("%.1f", v)
    if fr then return (t:gsub("%.", ",")) .. " %" end
    return t .. "%"
end

-- 204931 -> "204 931" (séparateur de milliers au choix).
function BarreXP.nombre(n, sep)
    local t = tostring(floor((n or 0) + 0.5))
    local signe, chiffres = t:match("^(-?)(%d+)$")
    if not chiffres then return t end
    local groupe = chiffres:reverse():gsub("(%d%d%d)", "%1" .. sep):reverse()
    if groupe:sub(1, #sep) == sep then groupe = groupe:sub(#sep + 1) end
    return signe .. groupe
end

function BarreXP.duree(s)
    s = floor(max(s or 0, 0))
    local j, h, m = floor(s / 86400), floor(s % 86400 / 3600), floor(s % 3600 / 60)
    if j >= 1 then return j .. "j " .. h .. "h" end
    if h >= 1 then return h .. "h " .. m .. "m" end
    if m >= 1 then return m .. "m" end
    return s .. "s"
end

function BarreXP.nouvelleSession(maintenant)
    return { debut = maintenant, gagne = 0 }
end

-- XP gagnée entre deux relevés { niveau, xp, max }. Une baisse au même
-- niveau (événement reçu avant le changement de niveau) donne nil : l'appelant
-- garde alors l'ancien relevé.
function BarreXP.gain(avant, apres)
    if not (avant and apres) then return nil end
    if apres.niveau == avant.niveau then
        local g = apres.xp - avant.xp
        if g < 0 then return nil end
        return g
    end
    if apres.niveau > avant.niveau then
        return max(avant.max - avant.xp, 0) + apres.xp
    end
    return nil
end

-- XP par heure et secondes avant le niveau suivant.
function BarreXP.rythme(session, maintenant, restant)
    local d = maintenant - (session.debut or maintenant)
    if (session.gagne or 0) <= 0 or d < 1 then return 0, nil end
    local parHeure = session.gagne / d * 3600
    return floor(parHeure + 0.5), floor(restant / parHeure * 3600 + 0.5)
end

function BarreXP.quetes(liste)
    if not liste then return nil end
    local r = { termine = 0, enCours = 0 }
    for _, q in ipairs(liste) do
        if q.complete then r.termine = r.termine + (q.xp or 0)
        else r.enCours = r.enCours + (q.xp or 0) end
    end
    return r
end

function BarreXP.tempsNiveau(t, maintenant)
    if not t then return nil end
    return t.secondes + (maintenant - t.recu)
end

-- Position verticale (y depuis le haut) de chaque ligne visible ; une ligne
-- masquée ne prend pas de place.
local H_BARRE, H_LIGNE, ECART = 22, 16, 2

function BarreXP.disposition(visibles)
    local l, y = {}, 0
    local function poser(nom, h)
        if y ~= 0 then y = y - ECART end
        l[nom] = y
        y = y - h
    end
    if visibles.haut then poser("haut", H_LIGNE) end
    poser("barre", H_BARRE)
    -- Quêtes et repos à gauche, rythme à droite : une seule ligne.
    if visibles.bas1 or visibles.bas2 then poser("bas", H_LIGNE) end
    return l, -y
end

-- Lignes de texte montrées selon le réglage « Textes » (0 aucun, 1 essentiel,
-- 2 tout). Au niveau max, ni quêtes ni rythme.
function BarreXP.lignesVisibles(textes, auMax)
    return { haut = textes >= 2, bas1 = textes >= 2 and not auMax, bas2 = textes >= 1 and not auMax }
end

-- Réglage « Contour du texte » : aucun, ombre portée seule (le juste milieu),
-- ou contour fin + ombre.
function BarreXP.drapeauPolice(nom)
    return nom == "fin" and "OUTLINE" or ""
end

-- Décalage de l'ombre portée (0, 0 = pas d'ombre).
function BarreXP.ombrePolice(nom)
    if nom == "aucun" then return 0, 0 end
    return 1, -1
end

-- Dégradé du remplissage pour une couleur choisie : d'une teinte plus sombre
-- à gauche vers la couleur au bout, là où la progression avance (un bout
-- sombre se lisait comme de l'XP manquante).
function BarreXP.degradeDe(r, g, b)
    return r * 0.65, g * 0.65, b * 0.65, r, g, b
end
