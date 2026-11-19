-- Thème « interface v2 » : couleurs, police Archivo, icônes Lucide, fonds arrondis.

local ADDON, ns = ...

local Theme = {}
ns.Theme = Theme

local MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\Media\\"
Theme.MEDIA = MEDIA

-- Jetons v2 (r, g, b de 0 à 1).
local function hex(h)
    return tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255
end
Theme.couleurs = {
    texte = { hex("e8ecf2") }, texteDoux = { hex("9aa3b2") }, textePale = { hex("6f7889") },
    panneau = { hex("0d1118") }, flot = { hex("10141c") }, bord = { hex("1c2330") }, bordFort = { hex("273042") },
    accent = { hex("4fd8ff") }, vert = { hex("3fe07a") }, orange = { hex("ffb84a") }, rouge = { hex("ff5a5f") },
    clair = { hex("eef1f5") }, sombre = { hex("0b0d12") }, vertFonce = { hex("15803d") },
    violet = { hex("a78bfa") }, repos = { hex("5aa9ff") },
}
Theme.hex = { accent = "4fd8ff", texteDoux = "9aa3b2", sombre = "0b0d12", texte = "e8ecf2", textePale = "6f7889",
              vert = "3fe07a", orange = "ffb84a", rouge = "ff5a5f", violet = "a78bfa", repos = "5aa9ff" }

function Theme.rgb(nom) return unpack(Theme.couleurs[nom]) end

---------------------------------------------------------------------------
-- Polices (Archivo, OFL, Media/Polices)
---------------------------------------------------------------------------

local POLICES = {
    grand = { "Archivo-BoldCondensed.ttf", 18 },
    titre = { "Archivo-BoldCondensed.ttf", 14 },
    texte = { "Archivo-Medium.ttf", 12 },
    petit = { "Archivo-Regular.ttf", 11 },
    compteur = { "Archivo-Medium.ttf", 11 },
    libelle = { "Archivo-Medium.ttf", 9 },
}
local objets, fixes = {}, {}
local taille = 1 -- multiplicateur du réglage « Taille du texte »

local function regler(f, nom, mult)
    local p = POLICES[nom]
    f:SetFont(MEDIA .. "Polices\\" .. p[1], math.floor(p[2] * mult + 0.5), "")
end

local function creer(prefixe, nom, mult)
    local f = CreateFont(prefixe .. nom)
    regler(f, nom, mult)
    f:SetShadowOffset(0, 0)
    return f
end

-- Objet police réutilisable (CreateFont), créé à la première demande ;
-- suit le réglage « Taille du texte » (fenêtre du guide, flèche).
function Theme.police(nom)
    objets[nom] = objets[nom] or creer("SuperGuidePolice_", nom, taille)
    return objets[nom]
end

-- Même police, taille fixe (menu principal : sa mise en page n'en dépend pas).
function Theme.policeFixe(nom)
    fixes[nom] = fixes[nom] or creer("SuperGuidePoliceFixe_", nom, 1)
    return fixes[nom]
end

-- Change la taille de toutes les polices « Theme.police » déjà créées.
function Theme.tailleTexte(mult)
    taille = mult or 1
    for nom, f in pairs(objets) do regler(f, nom, taille) end
end

---------------------------------------------------------------------------
-- Fonds arrondis (texture 32x32 découpée en 9, marges 8 px)
---------------------------------------------------------------------------

local function neuf(tex)
    if tex.SetTextureSliceMargins then
        tex:SetTextureSliceMargins(8, 8, 8, 8)
        if tex.SetTextureSliceMode and Enum and Enum.UITextureSliceMode then
            tex:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
        end
    end
end

-- Pose sur « cadre » un fond plein arrondi de la couleur donnée, avec un
-- liseré facultatif. Renvoie les deux textures (fond, liseré).
function Theme.fond(cadre, couleur, alpha, bord)
    local f = cadre:CreateTexture(nil, "BACKGROUND")
    f:SetTexture(MEDIA .. "RondPlein")
    neuf(f)
    f:SetAllPoints()
    f:SetVertexColor(Theme.rgb(couleur))
    f:SetAlpha(alpha or 1)
    local b
    if bord then
        b = cadre:CreateTexture(nil, "BORDER")
        b:SetTexture(MEDIA .. "RondBord")
        neuf(b)
        b:SetAllPoints()
        b:SetVertexColor(Theme.rgb(bord))
    end
    return f, b
end

-- Trait de séparation horizontal d'un pixel.
function Theme.separateur(cadre)
    local t = cadre:CreateTexture(nil, "ARTWORK")
    t:SetColorTexture(Theme.rgb("bord"))
    t:SetHeight(1)
    return t
end

---------------------------------------------------------------------------
-- Icônes (Lucide, ISC, Media/Icones)
---------------------------------------------------------------------------

-- Icônes du jeu, gardées dans leurs couleurs (gris = désaturée) :
-- [nom] = { chemin, "couleur" | "gris" }. Aucune pour l'instant.
local NATIVES = {}

function Theme.icone(nom)
    local n = NATIVES[nom]
    if n then return n[1] end
    return MEDIA .. "Icones\\" .. nom
end

-- nil (icône à teinter), "couleur" ou "gris".
function Theme.natif(nom)
    return NATIVES[nom] and NATIVES[nom][2]
end

-- Intitulé de section « PRÉRÉGLAGE » : petites capitales grises suivies d'un trait.
function Theme.intitule(cadre)
    local f = cadre:CreateFontString(nil, "OVERLAY")
    f:SetFontObject(Theme.police("libelle"))
    f:SetTextColor(Theme.rgb("textePale"))
    local t = Theme.separateur(cadre)
    t:SetPoint("LEFT", f, "RIGHT", 8, 0)
    f.trait = t
    return f
end
