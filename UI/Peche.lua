-- Pêche en un bouton : la touche (bouton sécurisé qui lance Pêche, liaison
-- prioritaire qui ferre), les événements de la ligne et le widget de pêche
-- (déplaçable) : prises et valeur de la session, tout le détail au survol.
-- Décisions et session dans Core/Peche.lua.
-- Aperçu : une copie (même construction) dans la bannière du menu, avec un
-- exemple animé ; le vrai widget reste à sa place avec la vraie session.

local ADDON, ns = ...

local Peche = ns.Peche
local L = ns.L or setmetatable({}, { __index = function(_, k) return k end })
local function R(cle) return ns.Reglages.get(cle) end

local proprio, lanceur, widget, copie
local proprioTenue, boutonTenue   -- touche « Tenue de pêche » (plus bas)
local apercu = false
local ligneFin, ligneDuree   -- canal en cours (secondes, horloge GetTime)

local function nomSort(id)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    return GetSpellInfo and (GetSpellInfo(id))
end
local function nomPeche() return nomSort(Peche.SORT) or "Fishing" end
Peche.nomPeche = nomPeche

-- Valeur que le jeu cache aux addons : ni comparable, ni lisible.
local function lisible(v)
    return v ~= nil and not (type(issecretvalue) == "function" and issecretvalue(v))
end

---------------------------------------------------------------------------
-- La touche
---------------------------------------------------------------------------

-- « lancer » : clic du bouton sécurisé ; « ferrer » : interaction du jeu
-- avec la cible souple, c'est-à-dire le bouchon.
local lieTouche, lieMode
function Peche.lier(touche, mode)
    if not proprio or InCombatLockdown() then return end
    if not (touche and mode) then touche, mode = nil, nil end
    if touche == lieTouche and mode == lieMode then return end
    ClearOverrideBindings(proprio)
    lieTouche, lieMode = touche, mode
    if not touche then return end
    if mode == "lancer" then
        SetOverrideBindingClick(proprio, true, touche, lanceur:GetName(), "LeftButton")
    elseif mode == "sortir" then
        if not boutonTenue then lieTouche, lieMode = nil, nil; return end
        SetOverrideBindingClick(proprio, true, touche, boutonTenue:GetName(), "RightButton")
    else
        SetOverrideBinding(proprio, true, touche, "INTERACTTARGET")
    end
end

-- À monture, on descend d'abord : on ne pêche pas à cheval.
local function macroPeche() return "/dismount [mounted]\n/cast " .. nomPeche() end

-- Plus d'appât sur la canne et un dans les sacs : la touche le pose d'abord
-- (l'appui suivant lance la ligne). Relu chaque seconde, hors combat.
local appatMacro = nil
local function majMacro()
    if not lanceur or InCombatLockdown() then return end
    local a = Peche.arme() and Peche.etat() ~= "ligne"
        and Peche.appatAPoser(ns.Jeu.appatsSacs(Peche.APPATS), ns.Jeu.appatActif())
    local id = a and a.id or false
    if id == appatMacro then return end
    appatMacro = id
    lanceur:SetAttribute("macrotext", id and ("/dismount [mounted]\n/use item:" .. id .. "\n/use 16") or macroPeche())
end

-- Touche « Tenue de pêche » : choisie dans le module (liaison prioritaire
-- tant que la session dure) ou dans Raccourcis > SuperRsk. Moins prioritaire
-- que la touche de pêche si c'est la même.
local function lierTenue()
    if not proprioTenue or InCombatLockdown() then return end
    ClearOverrideBindings(proprioTenue)
    local t = R("pecheTenueTouche")
    if type(t) == "string" and t ~= "" then
        SetOverrideBindingClick(proprioTenue, false, t, boutonTenue:GetName(), "LeftButton")
    end
end

local function creerTenue()
    boutonTenue = CreateFrame("Button", "SuperGuidePecheTenue", UIParent)
    boutonTenue:Hide()
    boutonTenue:RegisterForClicks("AnyUp")
    boutonTenue:SetScript("OnClick", function(_, bouton)
        if bouton == "RightButton" then Peche.mettreTenue() else Peche.basculerTenue() end
    end)
    _G["BINDING_NAME_CLICK SuperGuidePecheTenue:LeftButton"] = L["Tenue de pêche (mettre / remettre mon équipement)"]
    if ClearOverrideBindings and SetOverrideBindingClick then
        proprioTenue = CreateFrame("Frame", "SuperGuidePecheTenueTouche")
        lierTenue()
    end
end

local function creerTouche()
    if not (ClearOverrideBindings and SetOverrideBinding and SetOverrideBindingClick) then return end
    proprio = CreateFrame("Frame", "SuperGuidePecheTouche")
    lanceur = CreateFrame("Button", "SuperGuidePecheLancer", UIParent, "SecureActionButtonTemplate")
    lanceur:SetAttribute("type", "macro")
    lanceur:SetAttribute("macrotext", macroPeche())
    -- Un appui = un lancer, au relâché (un second lancer remettrait le
    -- bouchon à l'eau).
    if ns.Jeu.cvar("ActionButtonUseKeyDown") ~= nil then
        lanceur:RegisterForClicks("AnyUp", "AnyDown")
        lanceur:SetAttribute("useOnKeyDown", false)
    else
        lanceur:RegisterForClicks("AnyUp")
    end
    lanceur:Hide()
end

-- La ligne à l'eau se reconnaît au nom ou à l'icône du canal (le sort de
-- l'événement peut être caché par le jeu).
local function canalPeche(sort)
    local ok, nom, _, icone, debut, fin = pcall(UnitChannelInfo, "player")
    if not ok then return false end
    local oui = (lisible(nom) and nom == nomPeche())
        or (lisible(icone) and (icone == Peche.ICONE
            or (type(icone) == "string" and icone:lower():find("trade_fishing", 1, true) ~= nil)))
        or (lisible(sort) and (sort == Peche.SORT or nomSort(sort) == nomPeche()))
    if oui and lisible(debut) and lisible(fin) and fin > debut then
        ligneFin, ligneDuree = fin / 1000, (fin - debut) / 1000
    end
    return oui == true
end

---------------------------------------------------------------------------
-- Le widget et son info-bulle
---------------------------------------------------------------------------

local function duree(s)
    s = math.max(0, math.floor(s or 0))
    if s < 60 then return s .. " s" end
    if s < 3600 then return math.floor(s / 60) .. " min" end
    return ("%d h %02d"):format(math.floor(s / 3600), math.floor(s % 3600 / 60))
end

local function argent(c) return ns.Jeu.texteArgent(math.floor(c or 0)) end
-- Version courte pour la carte : sans le cuivre dès qu'il y a de l'argent,
-- sans l'argent dès 100 po (la colonne est étroite).
local function argentCourt(c)
    c = math.floor(c or 0)
    if c >= 1000000 then c = c - c % 10000 elseif c >= 100 then c = c - c % 100 end
    return ns.Jeu.texteArgent(c)
end

local POISSON = "Interface\\Icons\\INV_Misc_Fish_"
local EXEMPLE = {
    temps = 2840, prises = 41,
    liste = {
        { nom = "Saumon des eaux vives", icone = POISSON .. "05", nombre = 18, valeur = 21600, source = "hv" },
        { nom = "Vivaneau à nageoires d'or", icone = POISSON .. "14", nombre = 9, valeur = 13500, source = "hv" },
        { nom = "Huître épaisse", icone = "Interface\\Icons\\INV_Misc_Shell_03", nombre = 6, valeur = 1800, source = "marchand" },
        { nom = "Poisson-chat moustachu", icone = POISSON .. "02", nombre = 8, valeur = 960, source = "marchand" },
    },
    total = 37860,
    competence = { 182, 25, 225 },
    equipement = { { nom = "Canne à pêche solide", icone = "Interface\\Icons\\INV_Fishingpole_01", bonus = 20 },
                   { nom = "Chapeau de pêcheur", icone = "Interface\\Icons\\INV_Helmet_31", bonus = 5 } },
    appat = 412, appats = { { nom = "Appât brillant", nombre = 7, icone = "Interface\\Icons\\INV_Misc_Orb_03" } },
}

-- Tout ce que montre l'info-bulle du vrai widget.
local function donnees()
    local s = Peche.session()
    local liste, total = Peche.bilan(ns.Jeu.prixObjet)
    local rang, bonus, max = ns.Jeu.competencePeche(nomPeche())
    return {
        temps = s.temps, prises = s.prises, liste = liste, total = total,
        competence = rang and { rang, bonus, max },
        equipement = ns.Jeu.equipementPeche(nomPeche()),
        appat = ns.Jeu.appatActif(),
        appats = ns.Jeu.appatsSacs(Peche.APPATS),
    }
end

local function icone(chemin) return chemin and ("|T" .. chemin .. ":14:14:0:0:64:64:5:59:5:59|t ") or "" end

local function infobulle(self)
    local d = donnees()
    local touche = Peche.nomTouche(R("pecheTouche") or "SPACE")
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddDoubleLine(L["Pêche"], d.competence
        and (d.competence[1] .. (d.competence[2] > 0 and (" |cff3fe07a(+" .. d.competence[2] .. ")|r") or "") .. " / " .. d.competence[3]) or "",
        1, 0.82, 0, 1, 1, 1)
    GameTooltip:AddLine(L["%s : lancer la ligne, puis ferrer quand le bouchon plonge."]:format(touche), 0.6, 0.65, 0.7, true)

    GameTooltip:AddLine(" ")
    local parH = Peche.parHeure(d.total, d.temps)
    GameTooltip:AddDoubleLine(L["Session en cours"], L["%d prises · %s"]:format(d.prises, duree(d.temps)), 1, 0.82, 0, 1, 1, 1)
    if #d.liste == 0 then
        GameTooltip:AddLine(L["Rien de pêché pour l'instant."], 0.6, 0.6, 0.6)
    end
    for i, o in ipairs(d.liste) do
        if i > 12 then
            GameTooltip:AddLine(L["… et %d autres"]:format(#d.liste - 12), 0.6, 0.6, 0.6)
            break
        end
        local nom = o.nom or o.lien or "?"
        local prix = o.valeur > 0 and (argent(o.valeur) .. (o.source == "marchand" and " |cff6f7889" .. L["(marchand)"] .. "|r" or "")) or ""
        GameTooltip:AddDoubleLine(icone(o.icone) .. nom .. " |cffffffffx" .. o.nombre .. "|r", prix, 1, 1, 1, 1, 1, 1)
    end
    if d.total > 0 then
        GameTooltip:AddDoubleLine(L["Valeur totale"], argent(d.total), 0.31, 0.85, 1, 1, 1, 1)
        if parH then GameTooltip:AddDoubleLine(L["Par heure de pêche"], argent(parH), 0.31, 0.85, 1, 1, 1, 1) end
        if not (Auctionator and Auctionator.API) then
            GameTooltip:AddLine(L["Prix de l'hôtel des ventes avec Auctionator (sinon prix du marchand)."], 0.45, 0.48, 0.54, true)
        end
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L["Équipement de pêche"], 1, 0.82, 0)
    if #d.equipement == 0 then GameTooltip:AddLine(L["Aucune canne en main."], 1, 0.35, 0.37) end
    for _, e in ipairs(d.equipement) do
        GameTooltip:AddDoubleLine(icone(e.icone) .. (e.nom or e.lien), e.bonus and ("+" .. e.bonus) or "", 1, 1, 1, 0.25, 0.88, 0.48)
    end
    if d.appat then
        GameTooltip:AddDoubleLine(L["Appât sur la canne"], duree(d.appat), 1, 1, 1, 0.25, 0.88, 0.48)
    else
        GameTooltip:AddDoubleLine(L["Appât sur la canne"], L["aucun"], 1, 1, 1, 1, 0.72, 0.29)
    end
    for _, a in ipairs(d.appats) do
        GameTooltip:AddDoubleLine("   " .. icone(a.icone) .. a.nom, "x" .. a.nombre, 0.8, 0.8, 0.8, 1, 1, 1)
    end

    GameTooltip:AddLine(" ")
    if Peche.aRemettre() then
        GameTooltip:AddLine(L["Clic : remettre mon équipement."], 0.45, 0.48, 0.54)
    end
    GameTooltip:AddLine(L["Maj + clic droit : nouvelle session."], 0.45, 0.48, 0.54)
    GameTooltip:Show()
end

-- La carte : en-tête (icône, « Pêche », compétence), état de la ligne,
-- trois chiffres de la session (prises, valeur, temps), barre de la ligne,
-- appât, et le bouton « Remettre mon équipement » quand il y a lieu.
local LARGEUR, HAUTEUR, BOUTON = 236, 146, 34

local function competenceTexte(exemple)
    local rang, bonus, max
    if exemple then rang, bonus, max = 182, 25, 225 else rang, bonus, max = ns.Jeu.competencePeche(nomPeche()) end
    if not rang then return "" end
    return rang .. ((bonus or 0) > 0 and (" |cff3fe07a+" .. bonus .. "|r") or "") .. " / " .. max
end

-- Compétence et appât relus une fois par seconde (vrai widget).
local lents, lentsQuand = {}, -1
local function lireLents(exemple)
    if exemple then return { competence = competenceTexte(true), appat = 412 } end
    local maintenant = GetTime()
    if maintenant - lentsQuand < 1 then return lents end
    lentsQuand = maintenant
    lents = { competence = competenceTexte(false), appat = ns.Jeu.appatActif() }
    return lents
end

-- Met le cadre w en forme : exemple animé (copie de l'aperçu) ou vraie session.
local function rendre(w, exemple)
    local T = ns.Theme
    local s = exemple and EXEMPLE or Peche.session()
    local _, total
    if exemple then total = EXEMPLE.total else _, total = Peche.bilan(ns.Jeu.prixObjet) end
    local lent = lireLents(exemple)
    local touche = Peche.nomTouche(R("pecheTouche") or "SPACE")
    local maintenant = GetTime()

    w.competence:SetText(lent.competence)
    w.prises:SetText(tostring(s.prises))
    w.valeur:SetText(total > 0 and argentCourt(total) or "-")
    w.temps:SetText(duree(s.temps))

    -- Ligne à l'eau : l'état passe en couleur, la barre se vide, l'icône pulse.
    local ligne = exemple and (maintenant % 6 < 4) or Peche.etat() == "ligne"
    if ligne then
        local reste, tot = 1, 1
        if exemple then reste, tot = 4 - maintenant % 6, 4
        elseif ligneFin then reste, tot = ligneFin - maintenant, ligneDuree end
        w.etat:SetText(L["Le bouchon plonge : %s pour ferrer"]:format(touche))
        w.etat:SetTextColor(T.rgb("accent"))
        w.barre:SetWidth(math.max(1, (LARGEUR - 24) * math.max(0, math.min(1, reste / tot))))
        w.barre:Show()
        w.icone:SetAlpha(0.75 + 0.25 * math.sin(maintenant * 6))
    else
        if appatMacro and not exemple then
            w.etat:SetText(L["Appât à poser · %s"]:format(touche))
            w.etat:SetTextColor(T.rgb("orange"))
        else
            w.etat:SetText((exemple or Peche.arme()) and L["Prêt à pêcher · %s pour lancer"]:format(touche)
                or L["Canne rangée"])
            w.etat:SetTextColor(T.rgb("texteDoux"))
        end
        w.barre:Hide()
        w.icone:SetAlpha(1)
    end

    if lent.appat then
        w.appat:SetText(L["Appât : encore %s"]:format(duree(lent.appat)))
        w.appat:SetTextColor(T.rgb("vert"))
    else
        w.appat:SetText(L["Pas d'appât sur la canne"])
        w.appat:SetTextColor(T.rgb("orange"))
    end

    -- Mode pêche : badge vert et liseré vert ; bleu quand la ligne est à l'eau.
    local actif = exemple or Peche.arme()
    if actif then
        -- Pastille du jeu (le rond n'existe pas dans la police Archivo).
        w.mode:SetText("|TInterface\\COMMON\\Indicator-Green:10:10:0:0|t |cff3fe07a" .. L["MODE PÊCHE"] .. "|r")
        w.bordTex:SetVertexColor(T.rgb(ligne and "accent" or "vert"))
    else
        w.mode:SetText("|cff6f7889" .. L["CANNE RANGÉE"] .. "|r")
        w.bordTex:SetVertexColor(T.rgb("bordFort"))
    end

    local bouton = exemple or Peche.aRemettre()
    w.remettre:SetShown(bouton)
    w:SetHeight(HAUTEUR + (bouton and BOUTON or 0))
    w:Show()
end

-- Le vrai widget (visible canne en main, et tant que l'équipement d'avant
-- n'est pas remis ; l'aperçu n'y touche pas) et la copie de l'aperçu.
local function rafraichir()
    if copie then
        if apercu then rendre(copie, true) else copie:Hide() end
    end
    if not widget then return end
    local visible = (Peche.arme() or Peche.tenueMise()) and R("pecheWidget") ~= false
    if visible then rendre(widget, false) else widget:Hide() end
end

-- La carte et ses éléments ; quandRemettre : clic sur « Remettre mon équipement ».
local function construire(nom, quandRemettre)
    local T, C = ns.Theme, ns.Controles
    local w = CreateFrame("Button", nom, UIParent)
    w:SetSize(LARGEUR, HAUTEUR)
    w:SetFrameStrata("MEDIUM")
    w:SetClampedToScreen(true)
    w.fondTex, w.bordTex = T.fond(w, "panneau", 0.94, "bordFort")

    -- En-tête
    w.icone = w:CreateTexture(nil, "ARTWORK")
    w.icone:SetSize(30, 30)
    w.icone:SetPoint("TOPLEFT", 12, -12)
    w.icone:SetTexture("Interface\\Icons\\Trade_Fishing")
    w.icone:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local titre = C.texte(w, "titre", "texte")
    titre:SetPoint("TOPLEFT", w.icone, "TOPRIGHT", 10, -1)
    titre:SetText(L["Pêche"])
    w.competence = C.texte(w, "compteur", "texteDoux")
    w.competence:SetPoint("TOPRIGHT", -12, -14)
    w.competence:SetJustifyH("RIGHT")
    -- Badge du mode pêche, sous le titre.
    w.mode = w:CreateFontString(nil, "OVERLAY")
    w.mode:SetFontObject(T.policeFixe("libelle"))
    w.mode:SetPoint("BOTTOMLEFT", w.icone, "BOTTOMRIGHT", 10, 2)
    -- État de la ligne : sa propre ligne, toute la largeur.
    w.etat = C.texte(w, "petit", "texteDoux")
    w.etat:SetPoint("TOPLEFT", 12, -52)
    w.etat:SetWidth(LARGEUR - 24)
    w.etat:SetWordWrap(false)

    local trait = T.separateur(w)
    trait:SetPoint("TOPLEFT", 12, -70)
    trait:SetPoint("TOPRIGHT", -12, -70)

    -- Trois chiffres de la session
    local col = (LARGEUR - 24) / 3
    local function chiffre(i, libelle)
        local v = w:CreateFontString(nil, "OVERLAY")
        v:SetFont(T.MEDIA .. "Polices\\Archivo-BoldCondensed.ttf", 16, "")
        v:SetTextColor(T.rgb("texte"))
        v:SetPoint("TOP", w, "TOPLEFT", 12 + col * (i - 0.5), -80)
        local l = w:CreateFontString(nil, "OVERLAY")
        l:SetFontObject(T.policeFixe("libelle"))
        l:SetTextColor(T.rgb("textePale"))
        l:SetPoint("TOP", v, "BOTTOM", 0, -3)
        l:SetText(libelle)
        return v
    end
    w.prises = chiffre(1, L["PRISES"])
    w.valeur = chiffre(2, L["VALEUR"])
    w.temps = chiffre(3, L["TEMPS"])

    -- Barre de la ligne (fond toujours là, remplissage pendant la ligne)
    local fond = w:CreateTexture(nil, "ARTWORK")
    fond:SetColorTexture(T.rgb("sombre"))
    fond:SetHeight(3)
    fond:SetPoint("TOPLEFT", 12, -118)
    fond:SetPoint("TOPRIGHT", -12, -118)
    w.barre = w:CreateTexture(nil, "OVERLAY")
    w.barre:SetColorTexture(T.rgb("accent"))
    w.barre:SetHeight(3)
    w.barre:SetPoint("LEFT", fond, "LEFT")

    w.appat = C.texte(w, "petit", "vert")
    w.appat:SetPoint("TOPLEFT", 12, -128)

    -- Dans la carte, en bas : l'équipement d'avant en un clic.
    w.remettre = C.bouton(w, L["Remettre mon équipement"], "accent", quandRemettre, LARGEUR - 24)
    w.remettre:SetPoint("BOTTOM", 0, 12)
    w.remettre.texte:SetTextColor(T.rgb("accent"))
    w.remettre:Hide()

    w:Hide()
    return w
end

local function creerWidget()
    widget = construire("SuperGuidePeche", function() Peche.rangerTenue() end)
    widget:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    widget:SetScript("OnClick", function(self, bouton)
        if bouton == "LeftButton" then
            if Peche.aRemettre() then Peche.rangerTenue() end
            return
        end
        if not IsShiftKeyDown() then return end
        Peche.remettreAZero()
        ns.Jeu.message(L["Pêche : nouvelle session."])
        rafraichir()
    end)
    widget:SetScript("OnEnter", infobulle)
    widget:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Widget redessiné 10 fois par seconde, info-bulle ouverte une fois par
    -- seconde (elle relit l'équipement).
    local cumul, bulle = 0, 0
    widget:SetScript("OnUpdate", function(self, dt)
        dt = dt or 0.1
        cumul, bulle = cumul + dt, bulle + dt
        if cumul >= 0.1 then cumul = 0; rafraichir() end
        if bulle >= 1 then
            bulle = 0
            if GameTooltip:IsOwned(self) then infobulle(self) end
        end
    end)
    if ns.Deplacement then
        ns.Deplacement.inscrire(widget, L["Pêche"], "peche", { "RIGHT", -60, 120 })
    end
end

-- Copie montrée dans la bannière d'aperçu du menu (le vrai reste en place),
-- animée 10 fois par seconde tant que l'aperçu dure.
function Peche.vitrine()
    if not copie then
        copie = construire(nil, function() end)
        copie:EnableMouse(false)
        local cumul = 0
        copie:SetScript("OnUpdate", function(self, dt)
            cumul = cumul + (dt or 0.1)
            if cumul < 0.1 then return end
            cumul = 0
            if apercu then rendre(self, true) else self:Hide() end
        end)
        if apercu then rendre(copie, true) end
    end
    return copie, "peche", true
end

function Peche.apercu(oui)
    apercu = oui and true or false
    rafraichir()
end

-- Butin de pêche : sur Forever le jeu ne dit pas toujours qu'un butin vient
-- de la pêche, et Auto Loot le vide aussitôt. On compte donc les messages
-- « Vous recevez le butin » qui suivent la sortie de ta ligne (quelques
-- secondes) : la première ligne de butin fait une prise, les suivantes y
-- ajoutent leurs objets.
local FENETRE = 6
local fenetreFin, priseComptee = 0, false

local function surMessageButin(msg, ...)
    if GetTime() > fenetreFin and Peche.etat() ~= "ligne" then return end
    if not lisible(msg) then return end
    local auteur = select(4, ...)
    if ns.ListeButin and ns.ListeButin.estMoi and not ns.ListeButin.estMoi(auteur) then return end
    local lien, nombre = ns.Butin.lireMessage(msg)
    if not (lien and lien:find("|Hitem:", 1, true)) then return end
    local id, _, _, _, ic = C_Item.GetItemInfoInstant(lien)
    Peche.noterPrise({ { id = id, lien = lien, icone = ic, nombre = nombre } }, priseComptee)
    priseComptee = true
    rafraichir()
end

---------------------------------------------------------------------------
-- Branchement
---------------------------------------------------------------------------

local etaitMonte = false
local function surMonte()
    local m = IsMounted and IsMounted() or false
    if m and not etaitMonte then Peche.surMonture() end
    etaitMonte = m
end

local EVENEMENTS = {
    PLAYER_EQUIPMENT_CHANGED = function() Peche.surEquipement(); Peche.maj(); rafraichir() end,
    UNIT_INVENTORY_CHANGED = function(unite) if unite == "player" then Peche.maj() end end,
    PLAYER_REGEN_DISABLED = function() Peche.surCombat(); rafraichir() end,
    PLAYER_REGEN_ENABLED = function()
        -- Attaqué en tenue de pêche : les armes sont revenues, le reste aussi maintenant.
        if Peche.tenueMise() then Peche.rangerTenue() end
        lierTenue()
        Peche.maj()
        rafraichir()
    end,
    PLAYER_LOGOUT = function() Peche.surDeconnexion() end,
    -- Monté à cheval : l'équipement revient.
    PLAYER_MOUNT_DISPLAY_CHANGED = function() surMonte() end,
    UNIT_AURA = function(unite) if unite == "player" then surMonte() end end,
    SPELLS_CHANGED = function()
        appatMacro = nil
        majMacro()
    end,
    UNIT_SPELLCAST_CHANNEL_START = function(unite, _, sort)
        if unite == "player" and canalPeche(sort) then
            fenetreFin, priseComptee = 0, false
            Peche.surLigne()
        end
    end,
    UNIT_SPELLCAST_CHANNEL_STOP = function(unite)
        if unite ~= "player" then return end
        -- La ligne sort : le butin qui suit vient de la pêche.
        if Peche.etat() == "ligne" then fenetreFin = GetTime() + FENETRE end
        ligneFin = nil
        Peche.surFinLigne()
    end,
    CHAT_MSG_LOOT = surMessageButin,
}

function Peche.creer()
    creerTouche()
    creerTenue()
    creerWidget()
    local f = CreateFrame("Frame")
    for e in pairs(EVENEMENTS) do
        if not (C_EventUtils and C_EventUtils.IsEventValid) or C_EventUtils.IsEventValid(e) then
            pcall(f.RegisterEvent, f, e)
        end
    end
    f:SetScript("OnEvent", function(_, e, ...) EVENEMENTS[e](...) end)
    -- Temps de pêche : compté chaque seconde, canne en main.
    C_Timer.NewTicker(1, function()
        Peche.compterTemps(1, time())
        majMacro()
    end)
    Peche.surEquipement()
    Peche.demarrer()
    rafraichir()
end

-- /sg peche : où en est la touche (diagnostic).
function Peche.diagnostic()
    local function oui(v) return v and L["oui"] or L["non"] end
    local t = R("pecheTouche") or "SPACE"
    local cannes = 0
    for _, o in ipairs(ns.Jeu.sacsPeche(nomPeche())) do if o.canne then cannes = cannes + 1 end end
    return {
        ("pêche : module %s · touche %s · sans canne %s"):format(oui(R("pecheActif")), t, oui(Peche.sortirPossible())),
        ("canne en main %s · armé %s · état %s · combat %s"):format(oui(ns.Jeu.cannePortee()), oui(Peche.arme()),
            Peche.etat(), oui(InCombatLockdown())),
        ("touche %s -> %s"):format(t, tostring(GetBindingAction and GetBindingAction(t, true))),
        ("prise par SuperRsk : %s %s · cannes portables dans les sacs : %d"):format(tostring(lieTouche), tostring(lieMode), cannes),
        ("sort : %s"):format(tostring(nomPeche())),
    }
end

-- Écouteur des réglages.
function Peche.appliquerInterface(cle, v)
    Peche.appliquer(cle, v)
    if cle == "pecheTenueTouche" then lierTenue() end
    if cle == "pecheWidget" or cle == "pecheActif" then rafraichir() end
end
