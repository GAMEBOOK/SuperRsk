-- Réglages de SuperRsk (SuperGuideDB), décrits une fois pour le menu.
--
-- get rend la valeur enregistrée ou la valeur par défaut ; set borne la
-- valeur (curseur, choix), l'enregistre et prévient les écouteurs : chaque
-- module d'affichage s'applique lui-même. Le menu n'écrit que par ici.

local ADDON, ns = ...

local Reglages = {}
ns.Reglages = Reglages
local L = ns.L or setmetatable({}, { __index = function(_, k) return k end })

Reglages.DEFAUTS = {
    equipArbre = 0, proposerEquipement = true, equipFleches = true, equipBoE = 2, choisirRecompense = true,
    minimapCache = false, elementsVerrouilles = false,
    tenuesActif = true, tenuesMessage = true, tenuesDelai = 10,
    barreXP = true, barreXPLargeur = 580, xpTexture = "d1", xpContour = "noir", xpTextes = 2, xpContourTexte = "fin",
    xpBarreQuetes = true, xpBarreEnCours = false, xpBarreRepos = true,
    xpCouleurXP = false, xpCouleurQuetes = false, xpCouleurEnCours = false, xpCouleurRepos = false,
    xpNiveauMax = false, xpResetReload = false, xpMasquerBlizzard = true,
    barreRep = true, barreRepLargeur = 580, repTexture = "d1", repContour = "noir", repTextes = 1,
    repContourTexte = "fin", repMasquerBlizzard = true,
    butinRapide = true, butinAuto = true, butinConfirmerLie = false,
    butinSonPlein = false, butinSonPeche = true, butinListe = false, butinPoubelle = true, butinDuree = 5, butinSens = "bas",
    rangsAuto = true, rangsMessage = true,
    tirActif = true, tirAffichage = "combat", tirBarre = "superguide", tirLargeur = 220, tirArmement = "auto", tirLatence = true, tirAvance = 0,
    tirCouleur = false, tirOpacite = 0.35, tirPulsation = true,
    tirHauteur = 14, tirTexture = "d1", tirContour = "noir", tirCouleurBarre = false, tirTemps = false,
    tirSignal = true, tirCouleurSignal = false,
    volsCarte = true, volsAvecConnus = true,
    deplGrille = true, deplAimant = true,
    marqueursActif = true, marqueurMoi = 1,
    swapGroupeActif = true, swapButinLibre = true, swapCompteur = true,
    spyPing = true, spyPingType = "Warning", spyWay = false, spyDetection = true,
    vhActif = true, vhGuilde = true, vhTop = 10, vhMonde = true,
    monnaiesActif = false, monnaieOr = true, monnaiesSens = "colonne", monnaiesTaille = 1, monnaiesFond = 0.92,
    monnaiesIcones = true, monnaiesNoms = false, monnaiesZero = true, monnaiesOrFormat = "complet",
    fabActif = false, fabBarreNormale = false, fabTaille = 1, fabFond = 0.9, fabTexture = "d1", fabIcone = true,
    fabSon = false, fabTitre = false,
    tsquidActif = false, tsquidCritSon = true, tsquidCanal = "Master",
    softInteract = true,
    pecheActif = true, pecheTouche = "SPACE", pecheTenueTouche = "", pecheSortir = true, pecheAppat = true, pecheWidget = true,
    menageActif = true,
    marchandActif = true, marchandVendre = true, marchandReparer = true, marchandGuilde = false, marchandMessage = true,
    usureActif = true, usureSeuil = 20, usureStyle = "icone", usureTaille = 1, usureSon = true, usureMessage = true,
    usureToujours = false, usureNom = false, usureFond = 0.92, usureLibelle = true, usureTexteLibelle = "",
    boostFPS = false, meteoActif = false, sansMeteo = true, sansBrouillard = true, sansSonMeteo = false,
    fxRayons = false, fxHalo = false, fxMort = false, fxNether = false, fxSecousses = false, fxFlash = false, fxEmpreintes = false, fxPas = false, fxErreurs = false, fxMusique = false, fxEmotes = false,
}

-- Types : « case » (oui/non, « inverse » si la clé dit l'inverse du libellé),
-- « curseur » (min, max, pas), « choix » (valeurs, noms).
Reglages.CATEGORIES = {
    { titre = L["Minicarte"], options = {
        { cle = "minimapCache", type = "case", inverse = true, libelle = L["Bouton sur la minicarte"],
          info = L["Clic : menu principal. Glisser : déplacer."] },
    } },
}

-- Symbole de raid n (1 à 8) en texte, pour les boutons de choix.
local function symbole(n) return ("|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_%d:16|t"):format(n) end

-- Modules : chacun a sa page dans le menu (barre latérale,
-- groupe « Module »).
Reglages.MODULES = {
    { nom = "autoEquip", titre = "Auto Equip", interrupteur = "proposerEquipement", deplacer = true,
      apercu = function(oui) if ns.Proposition and ns.Proposition.apercu then ns.Proposition.apercu(oui) end end,
      vitrine = function() if ns.Proposition and ns.Proposition.vitrine then return ns.Proposition.vitrine() end end,
      desc = L["Propose d'équiper les objets meilleurs que les tiens. Tu choisis jusqu'à quelle qualité les objets « lié quand équipé » sont proposés."],
      options = {
        { cle = "proposerEquipement", type = "case", libelle = L["Proposer les améliorations d'équipement"],
          info = L["Un objet meilleur que le tien (selon ta classe et ta spécialisation) arrive dans tes sacs : une fenêtre te propose de l'équiper."] },
        { cle = "equipFleches", type = "case", libelle = L["Flèche sur les améliorations dans les sacs"],
          info = L["Flèche verte sur les objets de tes sacs meilleurs que les tiens. Flèche dorée avec un niveau : meilleur, mais portable seulement à ce niveau (à garder). Sacs du jeu, Baganator et EllesmereUI Bags."] },
        { cle = "equipBoE", type = "choix", valeurs = { 0, 2, 3, 7 },
          noms = { L["Aucun"], L["Verts"], L["+ Bleus"], L["Tous"] },
          libelle = L["Objets « lié quand équipé »"],
          info = L["Jusqu'à quelle qualité proposer un objet « lié quand équipé » pas encore lié. Les objets déjà liés sont toujours proposés."] },
        { cle = "equipArbre", type = "choix", valeurs = { 0, 1, 2, 3 },
          noms = { L["Automatique"], "1", "2", "3" }, libelle = L["Arbre de talents"],
          info = L["Auto : d'après ta spécialisation (rôle). Quand le rôle ne suffit pas (guerrier, druide ou chaman dégâts), choisis ton arbre. Guerrier 1 Armes, 2 Fureur, 3 Protection · Paladin 1 Sacré, 2 Protection, 3 Vindicte · Chasseur 1 Maîtrise des bêtes, 2 Précision, 3 Survie · Voleur 1 Assassinat, 2 Combat, 3 Finesse · Prêtre 1 Discipline, 2 Sacré, 3 Ombre · Chaman 1 Élémentaire, 2 Amélioration, 3 Restauration · Mage 1 Arcanes, 2 Feu, 3 Givre · Démoniste 1 Affliction, 2 Démonologie, 3 Destruction · Druide 1 Équilibre, 2 Farouche, 3 Restauration. /sg spe montre ce qui est retenu."] },
        { cle = "choisirRecompense", type = "case", libelle = L["Choisir la meilleure récompense de quête"],
          info = L["Quand une quête propose plusieurs récompenses : la meilleure pour toi est sélectionnée (sinon la plus chère à revendre). Tu cliques « Terminer »."] },
    } },
    { nom = "barreXP", titre = L["Barre d'XP"], interrupteur = "barreXP", deplacer = true,
      apercu = function(oui) if ns.BarreXP and ns.BarreXP.apercu then ns.BarreXP.apercu(oui) end end,
      vitrine = function() if ns.BarreXP and ns.BarreXP.vitrine then return ns.BarreXP.vitrine() end end,
      desc = L["Une barre d'XP à part : glisse-la pour la déplacer. En orange, l'XP des quêtes à rendre ; en bleu, le repos."],
      categories = {
        { titre = L["Barre"], options = {
            { cle = "barreXP", type = "case", libelle = L["Afficher la barre d'XP"] },
            { cle = "barreXPLargeur", type = "curseur", min = 300, max = 1000, pas = 10, libelle = L["Largeur"] },
            { cle = "xpTexture", type = "texture", libelle = L["Texture"],
              info = L["Les textures de barre de tes autres addons (SharedMedia…) sont proposées aussi."],
              liste = function() return ns.BarreXP.textures() end },
            { cle = "xpContour", type = "choix", valeurs = { "aucun", "noir", "gris", "accent", "classe" },
              noms = { L["Aucun"], L["Noir"], L["Gris"], L["Accent"], L["Classe"] }, libelle = L["Contour"] },
        } },
        { titre = L["Sur la barre"], options = {
            { cle = "xpCouleurXP", type = "couleur", libelle = L["XP"], couleurDefaut = "accent",
              info = L["Clic : choisir la couleur. Clic droit : couleur d'origine."] },
            { cle = "xpBarreQuetes", type = "case", libelle = L["Quêtes à rendre"],
              couleur = "xpCouleurQuetes", couleurDefaut = "orange",
              info = L["L'XP que te donneront les quêtes terminées, juste après ton XP."] },
            { cle = "xpBarreEnCours", type = "case", libelle = L["Quêtes en cours"],
              couleur = "xpCouleurEnCours", couleurDefaut = "orange",
              info = L["L'XP des quêtes pas encore terminées, en plus pâle."] },
            { cle = "xpBarreRepos", type = "case", libelle = L["Repos"],
              couleur = "xpCouleurRepos", couleurDefaut = "repos" },
        } },
        { titre = L["Textes"], options = {
            { cle = "xpTextes", type = "choix", valeurs = { 0, 1, 2 },
              noms = { L["Aucun"], L["Essentiel"], L["Tout"] }, libelle = L["Textes autour de la barre"],
              info = L["Essentiel : niveau suivant et XP/heure. Tout : aussi le temps à ce niveau, la session, les quêtes terminées et le repos."] },
            { cle = "xpContourTexte", type = "choix", valeurs = { "aucun", "ombre", "fin" },
              noms = { L["Aucun"], L["Ombre"], L["Fin"] }, libelle = L["Contour du texte"],
              info = L["Rend les textes lisibles sur une texture claire."] },
        } },
        { titre = L["Avancé"], options = {
            { cle = "xpMasquerBlizzard", type = "case", libelle = L["Masquer la barre d'XP du jeu"] },
            { cle = "xpNiveauMax", type = "case", libelle = L["Afficher au niveau maximum"] },
            { cle = "xpResetReload", type = "case", libelle = L["Remettre la session à zéro au /reload"] },
        } },
      } },
    { nom = "barreRep", titre = L["Barre de réputation"], interrupteur = "barreRep", deplacer = true,
      apercu = function(oui) if ns.BarreRep and ns.BarreRep.apercu then ns.BarreRep.apercu(oui) end end,
      vitrine = function() if ns.BarreRep and ns.BarreRep.vitrine then return ns.BarreRep.vitrine() end end,
      desc = L["La réputation de la faction que tu suis, dans une barre à part : son rang, où tu en es, ce que tu as gagné et le temps jusqu'au rang suivant. Pour choisir la faction : fenêtre Réputation, « Afficher en barre d'XP »."],
      categories = {
        { titre = L["Barre"], options = {
            { cle = "barreRep", type = "case", libelle = L["Afficher la barre de réputation"] },
            { cle = "barreRepLargeur", type = "curseur", min = 300, max = 1000, pas = 10, libelle = L["Largeur"] },
            { cle = "repTexture", type = "texture", libelle = L["Texture"],
              info = L["Les textures de barre de tes autres addons (SharedMedia…) sont proposées aussi."],
              liste = function() return ns.BarreXP.textures() end },
            { cle = "repContour", type = "choix", valeurs = { "aucun", "noir", "gris", "accent", "classe" },
              noms = { L["Aucun"], L["Noir"], L["Gris"], L["Accent"], L["Classe"] }, libelle = L["Contour"] },
        } },
        { titre = L["Textes"], options = {
            { cle = "repTextes", type = "choix", valeurs = { 0, 1, 2 },
              noms = { L["Aucun"], L["Essentiel"], L["Tout"] }, libelle = L["Textes autour de la barre"],
              info = L["Essentiel : temps jusqu'au rang suivant et réputation par heure. Tout : aussi ce que tu as gagné pendant la session."] },
            { cle = "repContourTexte", type = "choix", valeurs = { "aucun", "ombre", "fin" },
              noms = { L["Aucun"], L["Ombre"], L["Fin"] }, libelle = L["Contour du texte"],
              info = L["Rend les textes lisibles sur une texture claire."] },
        } },
        { titre = L["Avancé"], options = {
            { cle = "repMasquerBlizzard", type = "case", libelle = L["Masquer la barre de réputation du jeu"] },
        } },
      } },
    { nom = "autoLoot", titre = "Auto Loot", interrupteur = "butinRapide", deplacer = true,
      apercu = function(oui) if ns.ListeButin and ns.ListeButin.apercu then ns.ListeButin.apercu(oui) end end,
      vitrine = function() if ns.ListeButin and ns.ListeButin.vitrine then return ns.ListeButin.vitrine() end end,
      desc = L["Ramasse tout le butin d'un coup, sans attendre la fenêtre du jeu. La fenêtre ne s'ouvre que s'il reste quelque chose : objet pour le groupe, sacs pleins…"],
      categories = {
        { titre = L["Ramassage"], options = {
            { cle = "butinRapide", type = "case", libelle = L["Ramassage instantané"],
              info = L["Vide le corps dès qu'il s'ouvre (avec le ramassage automatique, ou Maj + clic droit selon tes réglages du jeu)."] },
            { cle = "butinAuto", type = "case", libelle = L["Ramassage automatique du jeu"],
              info = L["Active l'option « Butin automatique » du jeu pour ce personnage à chaque connexion."] },
            { cle = "butinConfirmerLie", type = "case", libelle = L["Confirmer seul les objets « lié quand ramassé »"],
              info = L["Seulement quand tu joues seul : en groupe, le jeu te demande toujours."] },
        } },
        { titre = L["Sons"], options = {
            { cle = "butinSonPlein", type = "case", libelle = L["Son quand les sacs sont pleins"] },
            { cle = "butinSonPeche", type = "case", libelle = L["Son du moulinet à la pêche"] },
        } },
        { titre = L["Affichage"], options = {
            { cle = "butinListe", type = "case", libelle = L["Afficher le butin ramassé"],
              info = L["Une liste animée de ce que tu ramasses. Bouton « Déplacer » pour la placer."] },
            { cle = "butinDuree", type = "curseur", min = 2, max = 15, pas = 1, libelle = L["Durée d'affichage (secondes)"] },
            { cle = "butinSens", type = "choix", valeurs = { "bas", "haut" }, noms = { L["Vers le bas"], L["Vers le haut"] },
              libelle = L["Sens de la liste"], info = L["Les nouvelles lignes s'ajoutent sous l'ancre (vers le bas) ou au-dessus (vers le haut, si la liste est en bas de l'écran)."] },
        } },
      } },
    { nom = "poubelle", titre = L["Poubelle (sacs pleins)"], interrupteur = "butinPoubelle", deplacer = true,
      apercu = function(oui) if ns.Poubelle and ns.Poubelle.apercu then ns.Poubelle.apercu(oui) end end,
      vitrine = function() if ns.Poubelle and ns.Poubelle.vitrine then return ns.Poubelle.vitrine() end end,
      desc = L["Pendant le ramassage, sacs pleins : une fenêtre propose l'objet gris qui vaut le moins, avec son prix chez le marchand et à l'hôtel des ventes (dernier scan d'Auctionator). Rien n'est jeté sans ton clic sur « Jeter »."],
      options = {
        { cle = "butinPoubelle", type = "case", libelle = L["Proposer de jeter le gris le moins cher quand les sacs sont pleins"] },
    } },
    { nom = "marchand", titre = "Auto Sell & Repair", interrupteur = "marchandActif",
      desc = L["Chez un marchand, tes objets gris sont vendus et ton équipement réparé, sans clic. Maj enfoncé en ouvrant le marchand : rien ne se fait."],
      options = {
        { cle = "marchandActif", type = "case", libelle = L["Activer"] },
        { cle = "marchandVendre", type = "case", libelle = L["Vendre les objets gris"],
          info = L["Seulement les objets de qualité médiocre (gris) qui se vendent."] },
        { cle = "marchandReparer", type = "case", libelle = L["Réparer l'équipement"],
          info = L["Tout ce que tu portes et ce qui est dans tes sacs, si le marchand sait réparer."] },
        { cle = "marchandGuilde", type = "case", libelle = L["Payer avec l'argent de la guilde si possible"],
          info = L["Si ta guilde te le permet ; sinon c'est ton or."] },
        { cle = "marchandMessage", type = "case", libelle = L["Résumé dans la discussion"],
          info = L["Combien de gris vendus, pour combien, et le prix de la réparation."] },
    } },
    { nom = "usure", titre = L["Usure de l'équipement"], interrupteur = "usureActif", deplacer = true,
      apercu = function(oui) if ns.Usure and ns.Usure.apercu then ns.Usure.apercu(oui) end end,
      vitrine = function() if ns.Usure and ns.Usure.vitrine then return ns.Usure.vitrine() end end,
      desc = L["Un petit widget apparaît quand une pièce de ton équipement passe sous le seuil, avec un son et un message une seule fois. Il disparaît après réparation. Pendant que tu règles le module, un aperçu reste affiché."],
      options = {
        { cle = "usureActif", type = "case", libelle = L["Activer"] },
        { cle = "usureSeuil", type = "choix", valeurs = { 10, 20, 30, 50 }, noms = { "10 %", "20 %", "30 %", "50 %" },
          libelle = L["Prévenir sous"] },
        { cle = "usureStyle", type = "choix", valeurs = { "icone", "barre", "texte" },
          noms = { L["Icône"], L["Barre"], L["Texte"] }, libelle = L["Apparence"] },
        { cle = "usureTaille", type = "curseur", min = 0.7, max = 1.6, pas = 0.1, libelle = L["Taille"] },
        { cle = "usureFond", type = "curseur", min = 0, max = 1, pas = 0.05, libelle = L["Opacité du fond"] },
        { cle = "usureLibelle", type = "case", libelle = L["Afficher le libellé"],
          info = L["Le mot devant le pourcentage (style Texte). Coupé : seulement le pourcentage."] },
        { cle = "usureTexteLibelle", type = "texte", max = 24, libelle = L["Libellé personnalisé"],
          indice = L["Équipement"], info = L["Le mot de ton choix ; vide : « Équipement »."] },
        { cle = "usureNom", type = "case", libelle = L["Nom de la pièce la plus usée"] },
        { cle = "usureToujours", type = "case", libelle = L["Toujours afficher"],
          info = L["Le widget reste visible même quand tout va bien (en vert au-dessus du seuil)."] },
        { cle = "usureSon", type = "case", libelle = L["Son d'alerte"] },
        { cle = "usureMessage", type = "case", libelle = L["Message dans la discussion"] },
    } },
    { nom = "autoRangs", titre = "Auto Spell Ranks", interrupteur = "rangsAuto",
      apercu = function(oui) if ns.Rangs and ns.Rangs.apercu then ns.Rangs.apercu(oui) end end,
      vitrine = function() if ns.Rangs and ns.Rangs.vitrine then return ns.Rangs.vitrine() end end,
      desc = L["Garde tes barres d'action sur le plus haut rang de chaque sort : quand tu apprends un nouveau rang, les boutons de l'ancien passent au nouveau, au même endroit (barres de la manette comprises)."],
      options = {
        { cle = "rangsAuto", type = "case", libelle = L["Monter les sorts au plus haut rang"],
          info = L["À la connexion et à chaque sort appris, hors combat. Seulement les boutons de sort : macros, objets et cases vides ne bougent pas. Jamais vers un rang plus bas."] },
        { cle = "rangsMessage", type = "case", libelle = L["Annoncer les changements dans le chat"] },
    } },
    { nom = "autoTir", titre = "Auto Shot / Wand", interrupteur = "tirActif",
      apercu = function(oui) if ns.Tir and ns.Tir.apercu then ns.Tir.apercu(oui) end end,
      vitrine = function() if ns.Tir and ns.Tir.vitrine then return ns.Tir.vitrine() end end, deplacer = true,
      boutons = { { texte = L["Créer la macro de tir"], action = function() ns.Tir.creerMacro() end } },
      desc = L["Chasseurs, mages, prêtres et démonistes : une barre se remplit entre deux tirs. Cours tant qu'elle n'est pas dans le rouge, arrête-toi dans le rouge : le tir part sans retard, puis repars."],
      categories = {
        { titre = L["Barre"], options = {
            { cle = "tirActif", type = "case", libelle = L["Afficher la barre de tir"],
              info = L["Elle apparaît quand tu lances le tir auto ou la baguette. Bouton « Déplacer » pour la placer."] },
            { cle = "tirAffichage", type = "choix", valeurs = { "tir", "combat", "toujours" },
              noms = { L["En tirant"], L["En combat"], L["Toujours"] }, libelle = L["Afficher la barre"],
              info = L["En tirant : seulement quand le tir auto ou la baguette est actif. En combat : aussi pendant tout le combat."] },
            { cle = "tirBarre", type = "choix", valeurs = { "superguide", "jeu" },
              noms = { L["SuperRsk"], L["Celle du jeu"] }, libelle = L["Barre utilisée"],
              info = L["Celle du jeu : la zone rouge se pose sur la barre de tir de Blizzard (à activer dans Options > Options avancées, puis à placer en mode Édition)."] },
            { cle = "tirLargeur", type = "curseur", min = 120, max = 500, pas = 10, libelle = L["Largeur"] },
            { cle = "tirHauteur", type = "curseur", min = 6, max = 30, pas = 1, libelle = L["Hauteur"] },
        } },
        { titre = L["Zone d'arrêt"], options = {
            { cle = "tirArmement", type = "choix", valeurs = { "auto", 0.1, 0.3, 0.5 },
              noms = { L["Auto (mesurée)"], "0,1 s", "0,3 s", "0,5 s" }, libelle = L["Durée de l'armement du tir"],
              info = L["Auto : mesurée sur tes tirs (la bêta a un bug qui l'écourte à ~0,1 s ; la zone suivra quand Blizzard le corrigera). /sg tir affiche la mesure."] },
            { cle = "tirLatence", type = "case", libelle = L["Compter ma latence"],
              info = L["La zone commence plus tôt de ta latence : ton arrêt arrive au serveur à temps."] },
            { cle = "tirAvance", type = "curseur", min = 0, max = 300, pas = 10, libelle = L["Avance en plus (ms)"] },
        } },
        { titre = L["Apparence"], options = {
            { cle = "tirTexture", type = "texture", libelle = L["Texture"],
              info = L["Pour la barre SuperRsk. Les textures de tes autres addons (SharedMedia…) sont proposées aussi."],
              liste = function() return ns.BarreXP.textures() end },
            { cle = "tirContour", type = "choix", valeurs = { "aucun", "noir", "gris", "accent", "classe" },
              noms = { L["Aucun"], L["Noir"], L["Gris"], L["Accent"], L["Classe"] }, libelle = L["Contour"] },
            { cle = "tirCouleurBarre", type = "couleur", libelle = L["Couleur du remplissage"], couleurDefaut = "accent",
              info = L["Clic : choisir la couleur. Clic droit : couleur d'origine."] },
            { cle = "tirSignal", type = "case", libelle = L["Signal « arrête-toi »"],
              couleur = "tirCouleurSignal", couleurDefaut = "vert",
              info = L["Le remplissage change de couleur pile au moment de t'arrêter pour que le tir parte."] },
            { cle = "tirCouleur", type = "couleur", libelle = L["Couleur de la zone"], couleurDefaut = "rouge",
              info = L["Clic : choisir la couleur. Clic droit : couleur d'origine."] },
            { cle = "tirOpacite", type = "curseur", min = 0.1, max = 1, pas = 0.05, pourcent = true,
              libelle = L["Opacité de la zone"], info = L["Elle s'éclaire quand tu es dedans avec le tir auto actif."] },
            { cle = "tirPulsation", type = "case", libelle = L["Pulser quand un tir attend"],
              info = L["Tu as bougé pendant l'armement : la zone reste allumée et pulse jusqu'au départ du tir."] },
            { cle = "tirTemps", type = "case", libelle = L["Afficher le temps avant le tir"],
              info = L["Les secondes qui restent avant le prochain tir, sur la barre SuperRsk."] },
        } },
      } },
    { nom = "vols", titre = L["Points de vol"], interrupteur = "volsCarte",
      desc = L["Tous les maîtres de vol sur la carte du monde, même ceux que tu n'as pas encore découverts : en orange ceux qui restent à prendre."],
      options = {
        { cle = "volsCarte", type = "case", libelle = L["Afficher les points de vol sur la carte"],
          info = L["Ceux de ta faction et les neutres. Ceux que tu connais sont notés quand tu ouvres la carte d'un maître de vol."] },
        { cle = "volsAvecConnus", type = "case", libelle = L["Aussi ceux que je connais"],
          info = L["Décoche pour ne voir que ceux qui restent à découvrir."] },
    } },
    { nom = "marqueurs", titre = L["Marqueurs"], interrupteur = "marqueursActif",
      boutons = { { texte = L["Créer la macro"], action = function() ns.Marqueurs.creerMacro() end } },
      desc = L["Un symbole de raid au-dessus de ta tête, et sur les personnes de ta liste quand elles sont dans ton groupe. Le jeu ne laisse pas un addon les poser seul : un appui sur ta touche (Raccourcis > SuperRsk) ou sur la macro « SG Symboles » les pose tous."],
      options = {
        { cle = "marqueursActif", type = "case", libelle = L["Poser les symboles"],
          info = L["En raid, seuls le chef et ses assistants peuvent poser des symboles : sinon rien ne se passe."] },
        { cle = "marqueurMoi", type = "choix", valeurs = { 0, 1, 2, 3, 4, 5, 6, 7, 8 },
          noms = { L["Aucun"], symbole(1), symbole(2), symbole(3), symbole(4), symbole(5), symbole(6), symbole(7), symbole(8) },
          libelle = L["Mon symbole"],
          info = L["Un symbole ne peut être que sur une personne à la fois : le tien passe avant ceux de la liste."] },
    } },
    { nom = "swapGroupe", titre = L["Swap layer en groupe"], interrupteur = "swapGroupeActif", requiert = "LayerSwap", deplacer = true,
      apercu = function(oui) if ns.SwapGroupe and ns.SwapGroupe.apercu then ns.SwapGroupe.apercu(oui) end end,
      vitrine = function() if ns.SwapGroupe and ns.SwapGroupe.vitrine then return ns.SwapGroupe.vitrine() end end,
      desc = L["Nécessite l'addon LayerSwap (installé et activé), sans lui les boutons n'apparaissent pas. En multibox, deux boutons déplaçables. À gauche : « Quitter le groupe » quand tu es en groupe (ta team est prévenue et part aussi), sinon « Swap layer ». À droite : « Inviter la team » (la liste est dans l'infobulle). Tes persos acceptent seuls (SuperRsk doit être sur chacun) et passent sur ta couche en rejoignant le groupe."],
      options = {
        { cle = "swapGroupeActif", type = "case", libelle = L["Activer le swap layer en groupe"],
          info = L["Sur tes persos aussi : ils acceptent alors seuls l'invitation du main qui vient de partir swapper (15 min), et toujours celles des noms de leur liste de Marqueurs."] },
        { cle = "swapCompteur", type = "case", libelle = L["Compteur de swaps (limite du jeu)"],
          info = L["Sur Forever, le jeu limite les changements de couche à 10 par heure, l'heure partant de ton premier swap. À droite des boutons : tes swaps de l'heure (3/10), en orange quand il en reste peu, en rouge avec l'attente quand c'est plein. Compté par LayerSwap, par personnage."] },
        { cle = "swapButinLibre", type = "case", libelle = L["Butin en accès libre au regroupement"],
          info = L["Dès que tes persos ont rejoint le groupe après « Inviter la team », le butin passe en accès libre (tu dois être chef)."] },
    } },
    { nom = "spyPing", titre = "Spy Ping", interrupteur = "spyPing", requiert = "Spy",
      desc = L["Avec l'addon Spy : un clic sur un ennemi de sa liste le cible et pose un ping dessus, visible par ton groupe. Le jeu ne laisse pas un addon pinger seul : c'est ton clic qui le déclenche."],
      options = {
        { cle = "spyPing", type = "case", libelle = L["Pinger l'ennemi cliqué dans Spy"],
          info = L["Clic gauche sur la ligne. Maj + clic et Ctrl + clic gardent leur rôle dans Spy (liste KOS, ignorés). Rien si l'ennemi est trop loin pour être ciblé."] },
        { cle = "spyPingType", type = "choix", valeurs = { "Warning", "Attack" },
          noms = { L["Attention"], L["Attaque"] }, libelle = L["Type de ping"] },
        { cle = "spyDetection", type = "case", libelle = L["Meilleure détection (plaques ennemies toujours affichées)"],
          info = L["Sur Forever, Spy ne voit un ennemi que par sa plaque de nom, ta cible ou ta souris : le journal de combat est fermé aux addons. Les plaques ennemies restent affichées hors combat et portent plus loin, Spy détecte dès qu'un ennemi entre dans ton champ. Coupe et tes réglages d'avant reviennent."] },
        { cle = "spyWay", type = "case", libelle = L["Repère sur le lieu de la rencontre"],
          info = L["Le jeu ne donne jamais la position d'un ennemi : le repère va là où TU étais quand Spy l'a détecté, pas là où il est maintenant. TomTom s'il est installé, sinon le repère du jeu."] },
    } },
    { nom = "vh", titre = L["Victoires honorables"], interrupteur = "vhActif", deplacer = true,
      apercu = function(oui) if ns.VH and ns.VH.apercu then ns.VH.apercu(oui) end end,
      vitrine = function() if ns.VH and ns.VH.vitrine then return ns.VH.vitrine() end end,
      boutons = { { texte = L["Remettre le widget à sa place"], action = function() ns.VH.recentrer() end } },
      desc = L["Un petit widget déplaçable : tes victoires honorables (et ton rang s'il y en a un). Survole-le pour le classement de ta guilde : partagé entre les membres qui ont SuperRsk, et relevé en passant près des autres (inspection, hors combat). Clique dessus pour le classement complet."],
      options = {
        { cle = "vhActif", type = "case", libelle = L["Afficher le widget"],
          info = L["Glisse-le où tu veux. Survol : aujourd'hui, au total, et le classement de la guilde. Clic : le classement complet."] },
        { cle = "vhMonde", type = "case", libelle = L["Partager avec mes groupes (Tout le monde)"],
          info = L["En groupe, en raid ou en champ de bataille, échange tes victoires avec les joueurs qui ont SuperRsk. Ils apparaissent dans l'onglet « Tout le monde » du classement."] },
        { cle = "vhGuilde", type = "case", libelle = L["Partager avec ma guilde"],
          info = L["Envoie tes victoires honorables aux membres de ta guilde qui ont SuperRsk, et reçoit les leurs. Coupé : tu ne vois plus que les tiennes."] },
        { cle = "vhTop", type = "choix", valeurs = { 5, 10, 20 }, noms = { "5", "10", "20" },
          libelle = L["Joueurs dans le classement"] },
    } },
    { nom = "monnaies", titre = L["Monnaies"], interrupteur = "monnaiesActif", deplacer = true,
      apercu = function(oui) if ns.Monnaies and ns.Monnaies.apercu then ns.Monnaies.apercu(oui) end end,
      vitrine = function() if ns.Monnaies and ns.Monnaies.vitrine then return ns.Monnaies.vitrine() end end,
      boutons = { { texte = L["Remettre le widget à sa place"], action = function() ns.Monnaies.recentrer() end } },
      desc = L["Un petit widget déplaçable avec ton or et les monnaies que tu coches. Survole-le pour toutes tes monnaies."],
      categories = {
        { titre = "Widget", options = {
            { cle = "monnaiesActif", type = "case", libelle = L["Afficher le widget"] },
            { cle = "monnaiesSens", type = "choix", valeurs = { "colonne", "ligne" },
              noms = { L["En colonne"], L["En ligne"] }, libelle = L["Disposition"] },
            { cle = "monnaiesTaille", type = "curseur", min = 0.7, max = 1.6, pas = 0.1, libelle = L["Taille"] },
            { cle = "monnaiesFond", type = "curseur", min = 0, max = 1, pas = 0.05, libelle = L["Opacité du fond"] },
            { cle = "monnaiesIcones", type = "case", libelle = L["Icônes"] },
            { cle = "monnaiesNoms", type = "case", libelle = L["Noms des monnaies"] },
            { cle = "monnaiesZero", type = "case", libelle = L["Afficher les monnaies à 0"] },
            { cle = "monnaiesOrFormat", type = "choix", valeurs = { "complet", "or" },
              noms = { L["Or, argent, cuivre"], L["Or seulement"] }, libelle = L["Format de l'or"] },
        } },
        { titre = L["Monnaies"], options = {
            { cle = "monnaieOr", type = "case", libelle = "|TInterface\\Icons\\INV_Misc_Coin_01:16:16:0:0|t " .. L["Or"] },
        } },
      } },
    { nom = "fabrication", titre = L["Fabrication"], interrupteur = "fabActif", deplacer = true,
      apercu = function(oui) if ns.Fabrication and ns.Fabrication.apercu then ns.Fabrication.apercu(oui) end end,
      vitrine = function() if ns.Fabrication and ns.Fabrication.vitrine then return ns.Fabrication.vitrine() end end,
      boutons = { { texte = L["Remettre la barre à sa place"], action = function() ns.Fabrication.recentrer() end } },
      desc = L["Une barre pour toute une série d'objets fabriqués : le temps total restant, combien sont faits, un repère par objet."],
      categories = {
        { titre = L["Barre"], options = {
            { cle = "fabActif", type = "case", libelle = L["Barre de fabrication en série"],
              info = L["Lance une série de 2 objets ou plus depuis la fenêtre de métier (Créer 10, Créer tout) : la barre apparaît et suit la série jusqu'au bout."] },
            { cle = "fabBarreNormale", type = "case", libelle = L["Garder la barre d'incantation normale"] },
            { cle = "fabTaille", type = "curseur", min = 0.6, max = 1.6, pas = 0.1, libelle = L["Taille"] },
            { cle = "fabFond", type = "curseur", min = 0, max = 1, pas = 0.05, libelle = L["Opacité du fond"] },
            { cle = "fabTexture", type = "texture", libelle = L["Texture"],
              info = L["Les textures de barre de tes autres addons (SharedMedia…) sont proposées aussi."],
              liste = function() return ns.BarreXP.textures() end },
            { cle = "fabIcone", type = "case", libelle = L["Icône de la recette"] },
        } },
        { titre = L["En plus"], options = {
            { cle = "fabSon", type = "case", libelle = L["Son discret à la fin de la série"] },
            { cle = "fabTitre", type = "case", libelle = L["Temps restant dans le titre de la fenêtre de métier"] },
        } },
      } },
    { nom = "peche", titre = "Auto Fishing", interrupteur = "pecheActif", deplacer = true,
      boutons = { { texte = L["Nouvelle session"], action = function()
                      if not ns.Peche then return end
                      ns.Peche.remettreAZero()
                      ns.Jeu.message(L["Pêche : nouvelle session."])
                  end } },
      apercu = function(oui) if ns.Peche and ns.Peche.apercu then ns.Peche.apercu(oui) end end,
      vitrine = function() if ns.Peche and ns.Peche.vitrine then return ns.Peche.vitrine() end end,
      desc = L["Une seule touche pour tout : elle sort ta canne et ta tenue de pêche des sacs, pose l'appât, lance la ligne et ferre le poisson. Ton équipement revient tout seul quand tu montes à cheval ou qu'on t'attaque."],
      options = {
        { cle = "pecheActif", type = "case", libelle = L["Activer Auto Fishing"],
          info = L["La touche n'est qu'empruntée, hors combat : rien ne change dans tes raccourcis."] },
        { cle = "pecheTouche", type = "touche", libelle = L["Ta touche de pêche"],
          info = L["Clic, puis appuie sur la touche voulue (clavier, avec Maj, Ctrl ou Alt si tu veux, molette ou bouton de souris). Avec Espace, la canne doit déjà être en main : sans canne, Espace sert à sauter. Clic droit : Espace."] },
        { cle = "pecheAppat", type = "case", libelle = L["Poser l'appât tout seul"],
          info = L["Plus d'appât sur la canne : la touche pose d'abord le meilleur appât de tes sacs, l'appui suivant lance la ligne."] },
        { cle = "pecheWidget", type = "case", libelle = L["Afficher la carte de pêche"],
          info = L["Prises, valeur et temps de la session, et le bouton pour remettre ton équipement. Survol : le détail. Glisse-la où tu veux."] },
    } },
    { nom = "tenues", titre = "Auto Sets", interrupteur = "tenuesActif",
      boutons = { { texte = L["Ouvrir mes tenues"], action = function() if ns.TenuesUI then ns.TenuesUI.ouvrir() end end } },
      desc = L["Des tenues qui se mettent toutes seules au bon moment, puis ton équipement revient : la Carotte au bout d'un bâton et tes éperons en selle, tes gants d'herboriste ou de mineur au survol d'une plante ou d'un filon, ta tenue de métier quand sa fenêtre est ouverte, une tenue de ville, de champ de bataille ou de donjon. Les objets à bonus de tes sacs sont trouvés pour toi. /sg tenues"],
      options = {
        { cle = "tenuesActif", type = "case", libelle = L["Activer Auto Sets"],
          info = L["Jamais en combat, pendant une incantation ni pendant Auto Fishing : la tenue attend le bon moment."] },
        { cle = "tenuesMessage", type = "case", libelle = L["Me dire quand une tenue change"] },
        { cle = "tenuesDelai", type = "curseur", min = 3, max = 30, pas = 1, libelle = L["Récolte : remettre mon équipement après (secondes)"],
          info = L["Après le survol d'une plante, d'un filon ou d'un corps, la tenue de récolte reste ce temps-là."] },
    } },
    { nom = "menage", titre = L["Ménage des objets de quête"], interrupteur = "menageActif",
      boutons = { { texte = L["Faire le ménage"], action = function() if ns.Menage then ns.Menage.ouvrir() end end } },
      desc = L["Sur demande (/sg menage ou le bouton ci-dessus) : les objets de quête de tes sacs qui ne servent sûrement plus, à jeter un clic par objet. Seuls les objets dont on a la preuve sont proposés : avec Questie, toutes leurs quêtes sont terminées ; sans lui, la quête qu'ils commencent est déjà faite. Les autres (accès de raid, suite de chaîne…) restent cachés, sauf si tu demandes à les voir. Installe Questie pour en trouver plus."],
      options = {
        { cle = "menageActif", type = "case", libelle = L["Me prévenir quand un objet de quête ne sert plus"],
          info = L["Quand tu rends une quête, un message nomme les objets devenus inutiles (sûrs seulement). Sacs pleins sans objet gris à jeter : la Poubelle propose aussi le ménage."] },
    } },
    { nom = "softInteract", titre = L["Interaction rapide"], interrupteur = "softInteract",
      desc = L["Le jeu vise tout seul l'objet le plus proche autour de toi (filon, plante, coffre, objet de quête, bouchon de pêche), jusqu'à 20 m, avec une icône au-dessus, et les objets que tu peux prendre scintillent. Un appui sur ta touche « Interagir avec la cible » (Options > Raccourcis) le prend. Coupe le module et tes réglages d'avant reviennent."],
      options = {
        { cle = "softInteract", type = "case", libelle = L["Viser les objets autour de moi"],
          info = L["Ciblage souple sur 360°, 20 m, objets compris (bouchon de pêche aussi), icône au-dessus de l'objet visé. Sans touche « Interagir avec la cible », rien ne se prend : assigne-la dans Options > Raccourcis."] },
    } },
    { nom = "tsquid", titre = "Tsquid Area", interrupteur = "tsquidActif",
      boutons = { { texte = L["Écouter le son"], action = function()
          if ns.Tsquid then ns.Tsquid.tester()
          else ns.Jeu.message(L["Son introuvable : le jeu ne voit les nouveaux fichiers d'un addon qu'au lancement. Quitte et relance complètement le jeu (un /reload ne suffit pas)."]) end
      end } },
      desc = L["Les petits plus de Tsquid. Coupe le module pour tout arrêter d'un coup."],
      options = {
        { cle = "tsquidActif", type = "case", libelle = L["Activer Tsquid Area"] },
        { cle = "tsquidCritSon", type = "case", libelle = L["Son sur coup critique"],
          info = L["Un son de sabre laser quand ta cible encaisse un coup critique. Sur Forever, le jeu ne dit pas de qui vient le critique : en groupe, ceux des autres sur ta cible sonnent aussi."] },
        { cle = "tsquidCanal", type = "choix", valeurs = { "Master", "SFX", "Music", "Ambience", "Dialog" },
          noms = { L["Général"], L["Effets"], L["Musique"], L["Ambiance"], L["Dialogues"] },
          libelle = L["Canal du son"],
          info = L["Le son suit le volume de ce canal (Options du jeu > Son). Général : toujours entendu tant que le son du jeu est allumé. Effets : baisse avec les bruitages. Musique : se coupe si tu coupes la musique."] },
    } },
    { nom = "boostFPS", titre = "Boost FPS", interrupteur = "boostFPS",
      desc = L["Règle tes graphismes pour plus d'images par seconde et une image nette. Tes réglages d'avant sont gardés : coupe le module et ils reviennent."],
      details = function() return ns.Graphismes and ns.Graphismes.details("boost") or {} end,
      options = {
        { cle = "boostFPS", type = "case", libelle = L["Optimiser mes graphismes pour les FPS"],
          info = L["Ombres correctes, textures hautes, effets au sol gardés. Coupés ou baissés : distance de vue, détails du décor, herbes, eau, occlusion ambiante, effets de profondeur, contours, densité des sorts des autres, réverbération du son. Mêmes réglages en raid et donjon, image plus nette. Tes retouches ensuite restent."] },
    } },
    { nom = "meteo", titre = L["Météo et effets"], interrupteur = "meteoActif",
      desc = L["Coche ce que tu veux couper, décoche pour le retrouver."],
      boutons = { { texte = L["Créer la macro anti-brume"], action = function() ns.Graphismes.creerMacroBrouillard() end } },
      categories = {
        { titre = L["Couper : météo"], options = {
            { cle = "meteoActif", type = "case", libelle = L["Activer"] },
            { cle = "sansMeteo", type = "case", libelle = L["Pluie, neige et sable"],
              info = L["Plus de gouttes ni de flocons. La couleur du ciel reste."] },
            { cle = "sansSonMeteo", type = "case", libelle = L["Bruit de la pluie"],
              info = L["Seulement quand il pleut. Les bruits de fond se taisent aussi, puis reviennent."] },
            { cle = "sansBrouillard", type = "case", libelle = L["Brouillard (en partie)"],
              info = L["Le jeu en garde une partie. Pour tout enlever : la macro anti-brume, en bas."] },
        } },
        { titre = L["Couper : image"], options = {
            { cle = "fxRayons", type = "case", libelle = L["Rayons du soleil"] },
            { cle = "fxHalo", type = "case", libelle = L["Halo lumineux"] },
            { cle = "fxMort", type = "case", libelle = L["Écran gris de la mort"] },
            { cle = "fxNether", type = "case", libelle = L["Voile d'invisibilité"] },
            { cle = "fxSecousses", type = "case", libelle = L["Secousses de l'écran"] },
            { cle = "fxFlash", type = "case", libelle = L["Flashs rouges au bord de l'écran"] },
            { cle = "fxEmpreintes", type = "case", libelle = L["Traces de pas"] },
        } },
        { titre = L["Couper : sons"], options = {
            { cle = "fxPas", type = "case", libelle = L["Bruit des pas"] },
            { cle = "fxErreurs", type = "case", libelle = L["Phrases d'erreur"] },
            { cle = "fxMusique", type = "case", libelle = L["Musique du jeu"] },
            { cle = "fxEmotes", type = "case", libelle = L["Son des emotes"] },
        } },
    } },
}

-- Familles de modules : l'accueil et la barre latérale les rangent ainsi,
-- dans cet ordre (les « Auto » ensemble, puis sacs, affichage, jeu, image).
Reglages.FAMILLES = {
    { cle = "auto", titre = L["Automatique"],
      modules = { "peche", "autoEquip", "tenues", "autoLoot", "marchand", "autoRangs", "autoTir" } },
    { cle = "sacs", titre = L["Sacs et équipement"], modules = { "poubelle", "menage", "usure" } },
    { cle = "affichage", titre = L["Affichage"], modules = { "barreXP", "barreRep", "vols", "vh", "monnaies", "fabrication" } },
    { cle = "jeu", titre = L["Jeu et groupe"], modules = { "softInteract", "marqueurs", "swapGroupe", "spyPing" } },
    { cle = "image", titre = L["Graphismes et ambiance"], modules = { "boostFPS", "meteo", "tsquid" } },
}
do
    local rang, famille = {}, {}
    for i, f in ipairs(Reglages.FAMILLES) do
        for j, nom in ipairs(f.modules) do rang[nom], famille[nom] = i * 100 + j, f end
    end
    for i, m in ipairs(Reglages.MODULES) do
        m.famille = famille[m.nom]
        m.rang = rang[m.nom] or (900 + i)   -- un module oublié ici va à la fin
    end
    table.sort(Reglages.MODULES, function(a, b) return a.rang < b.rang end)
end

-- Un module en plusieurs cartes garde aussi la liste à plat de ses options.
for _, m in ipairs(Reglages.MODULES) do
    if m.categories then
        m.options = {}
        for _, cat in ipairs(m.categories) do
            for _, o in ipairs(cat.options) do m.options[#m.options + 1] = o end
        end
    end
end

local options = {}
for _, liste in ipairs({ Reglages.CATEGORIES, Reglages.MODULES }) do
    for _, cat in ipairs(liste) do
        for _, o in ipairs(cat.options) do
            options[o.cle] = o
            -- Pastille de couleur portée par une case : réglage à part.
            if o.couleur then options[o.couleur] = { cle = o.couleur, type = "couleur" } end
        end
    end
end
Reglages.option = function(cle) return options[cle] end

-- Option ajoutée après le chargement (cases des monnaies du jeu, connues
-- seulement à la connexion) : dans la carte n du module, avec son défaut.
function Reglages.ajouterOption(nom, carte, o, defaut)
    local m
    for _, x in ipairs(Reglages.MODULES) do if x.nom == nom then m = x end end
    if not m or options[o.cle] then return false end
    local cat = m.categories and m.categories[carte]
    if cat then cat.options[#cat.options + 1] = o end
    m.options[#m.options + 1] = o
    options[o.cle] = o
    if Reglages.DEFAUTS[o.cle] == nil then Reglages.DEFAUTS[o.cle] = defaut end
    return true
end

-- Module par son nom (« guide », « barreXP »…), nil s'il n'existe pas.
function Reglages.module(nom)
    for _, m in ipairs(Reglages.MODULES) do
        if m.nom == nom then return m end
    end
end

-- Addon dont ce module a besoin (champ « requiert ») s'il n'est pas chargé,
-- sinon nil.
function Reglages.manquant(m)
    if not (m and m.requiert) then return nil end
    local jeu = ns.Jeu
    if jeu and jeu.addonCharge and jeu.addonCharge(m.requiert) then return nil end
    return m.requiert
end

-- Addons manquants, chacun avec les modules qu'il fait marcher :
-- { { addon = "Spy", modules = { "Spy Ping" } }, … } dans l'ordre des modules.
function Reglages.dependancesManquantes()
    local liste, index = {}, {}
    for _, m in ipairs(Reglages.MODULES) do
        local a = Reglages.manquant(m)
        if a then
            if not index[a] then
                index[a] = { addon = a, modules = {} }
                liste[#liste + 1] = index[a]
            end
            table.insert(index[a].modules, m.titre)
        end
    end
    return liste
end

local ecouteurs = {}

function Reglages.ecouter(f) ecouteurs[#ecouteurs + 1] = f end

local function prevenir(cle, v)
    for _, f in ipairs(ecouteurs) do f(cle, v) end
end

function Reglages.get(cle)
    local db = SuperGuideDB
    local v = db and db[cle]
    -- Ancienne case « verts BoE » décochée : aucun BoE.
    if v == nil and cle == "equipBoE" and db and db.equipVertsBoE == false then return 0 end
    if v == nil then return Reglages.DEFAUTS[cle] end
    return v
end

-- Valeur ramenée dans ce que l'option accepte ; nil = refusée.
local function borner(o, v)
    if not o then return v end
    if o.type == "curseur" then
        v = math.min(o.max, math.max(o.min, tonumber(v) or o.min))
        return tonumber(string.format("%.2f", math.floor(v / o.pas + 0.5) * o.pas))
    elseif o.type == "choix" then
        for _, x in ipairs(o.valeurs) do if x == v then return v end end
        return nil
    elseif o.type == "case" then
        return v and true or false
    elseif o.type == "texte" then
        if v == nil then return "" end
        v = tostring(v):gsub("^%s+", ""):gsub("%s+$", "")
        return v:sub(1, o.max or 24)
    elseif o.type == "touche" then
        -- « T », « SHIFT-F », « BUTTON4 », « MOUSEWHEELUP », et toutes les
        -- touches hors alphabet que le jeu nomme (²  &  é  ù  ,  ;  [ …).
        if type(v) ~= "string" then return nil end
        if v == "" then return "" end   -- aucune touche
        v = v:upper()
        return v:match("^[^%s%c]+$") and #v <= 40 and v or nil
    elseif o.type == "texture" then
        return type(v) == "string" and v ~= "" and v or nil
    elseif o.type == "couleur" then
        -- false = couleur d'origine ; sinon { r, g, b } entre 0 et 1.
        if v == false then return false end
        if type(v) ~= "table" then return nil end
        local c = {}
        for i = 1, 3 do
            if type(v[i]) ~= "number" then return nil end
            c[i] = math.min(1, math.max(0, v[i]))
        end
        return c
    end
    return v
end

-- Rend true si la valeur est acceptée.
function Reglages.set(cle, v)
    v = borner(options[cle], v)
    if v == nil then return false end
    SuperGuideDB = SuperGuideDB or {}
    SuperGuideDB[cle] = v
    prevenir(cle, v)
    return true
end

-- Fenêtre, flèche, bouton de minicarte et cadres du mode Déplacement
-- reviennent à leur place par défaut.
function Reglages.reinitialiserPositions()
    local db = SuperGuideDB
    if db then db.minimapAngle, db.positions = nil, nil end
    prevenir("positions")
end
