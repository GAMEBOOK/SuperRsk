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
    equipArbre = 0, proposerEquipement = true, equipBoE = 2, choisirRecompense = true,
    minimapCache = false,
    barreXP = true, barreXPLargeur = 580, xpTexture = "d1", xpContour = "noir", xpTextes = 2, xpContourTexte = "fin",
    xpBarreQuetes = true, xpBarreEnCours = false, xpBarreRepos = true,
    xpCouleurXP = false, xpCouleurQuetes = false, xpCouleurEnCours = false, xpCouleurRepos = false,
    xpNiveauMax = false, xpResetReload = false, xpMasquerBlizzard = true,
    butinRapide = true, butinAuto = true, butinConfirmerLie = false,
    butinSonPlein = false, butinSonPeche = true, butinListe = false,
    rangsAuto = true, rangsMessage = true,
    tirActif = true, tirAffichage = "combat", tirBarre = "superguide", tirLargeur = 220, tirArmement = "auto", tirLatence = true, tirAvance = 0,
    tirCouleur = false, tirOpacite = 0.35, tirPulsation = true,
    tirHauteur = 14, tirTexture = "d1", tirContour = "noir", tirCouleurBarre = false, tirTemps = false,
    tirSignal = true, tirCouleurSignal = false,
    volsCarte = true, volsAvecConnus = true,
    deplGrille = true, deplAimant = true,
    marqueursActif = true, marqueurMoi = 1,
    swapGroupeActif = true, swapButinLibre = true,
    spyPing = true, spyPingType = "Warning", spyWay = false, spyDetection = true,
    vhActif = true, vhGuilde = true, vhTop = 10,
    tsquidActif = false, tsquidCritSon = true, tsquidCanal = "Master",
    softInteract = true,
    boostFPS = false, meteoActif = false, sansMeteo = true, sansBrouillard = true,
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
    { nom = "autoEquip", titre = "Auto Equip", interrupteur = "proposerEquipement",
      desc = L["Propose d'équiper les objets meilleurs que les tiens. Tu choisis jusqu'à quelle qualité les objets « lié quand équipé » sont proposés."],
      options = {
        { cle = "proposerEquipement", type = "case", libelle = L["Proposer les améliorations d'équipement"],
          info = L["Un objet meilleur que le tien (selon ta classe et ta spécialisation) arrive dans tes sacs : une fenêtre te propose de l'équiper."] },
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
    { nom = "autoLoot", titre = "Auto Loot", interrupteur = "butinRapide", deplacer = true,
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
        } },
      } },
    { nom = "autoRangs", titre = "Auto Spell Ranks", interrupteur = "rangsAuto",
      desc = L["Garde tes barres d'action sur le plus haut rang de chaque sort : quand tu apprends un nouveau rang, les boutons de l'ancien passent au nouveau, au même endroit (barres de la manette comprises)."],
      options = {
        { cle = "rangsAuto", type = "case", libelle = L["Monter les sorts au plus haut rang"],
          info = L["À la connexion et à chaque sort appris, hors combat. Seulement les boutons de sort : macros, objets et cases vides ne bougent pas. Jamais vers un rang plus bas."] },
        { cle = "rangsMessage", type = "case", libelle = L["Annoncer les changements dans le chat"] },
    } },
    { nom = "autoTir", titre = "Auto Shot / Wand", interrupteur = "tirActif", deplacer = true,
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
    { nom = "swapGroupe", titre = L["Swap groupé"], interrupteur = "swapGroupeActif",
      desc = L["Nécessite l'addon LayerSwap (installé et activé), sans lui les boutons n'apparaissent pas. En multibox : deux boutons déplaçables, « Quitter + swap » (quitte le groupe puis demande le swap) et « Valider mon layer » (réinvite tes persos). Ils acceptent seuls (SuperRsk doit être sur chacun) et passent sur ta couche en rejoignant le groupe."],
      options = {
        { cle = "swapGroupeActif", type = "case", libelle = L["Activer le swap groupé"],
          info = L["Sur tes persos aussi : ils acceptent alors seuls l'invitation du main qui vient de partir swapper (15 min), et toujours celles des noms de leur liste de Marqueurs."] },
        { cle = "swapButinLibre", type = "case", libelle = L["Butin en accès libre au regroupement"],
          info = L["Dès que tes persos ont rejoint le groupe après « Valider mon layer », le butin passe en accès libre (tu dois être chef)."] },
    } },
    { nom = "spyPing", titre = "Spy Ping", interrupteur = "spyPing",
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
    { nom = "vh", titre = L["Victoires honorables"], interrupteur = "vhActif",
      boutons = { { texte = L["Recentrer le widget"], action = function() ns.VH.recentrer() end } },
      desc = L["Un petit widget déplaçable : tes victoires honorables (et ton rang s'il y en a un). Survole-le pour le classement de ta guilde : partagé entre les membres qui ont SuperRsk, et relevé en passant près des autres (inspection, hors combat)."],
      options = {
        { cle = "vhActif", type = "case", libelle = L["Afficher le widget"],
          info = L["Glisse-le où tu veux. Survol : aujourd'hui, au total, et le classement de la guilde."] },
        { cle = "vhGuilde", type = "case", libelle = L["Partager avec ma guilde"],
          info = L["Envoie tes victoires honorables aux membres de ta guilde qui ont SuperRsk, et reçoit les leurs. Coupé : tu ne vois plus que les tiennes."] },
        { cle = "vhTop", type = "choix", valeurs = { 5, 10, 20 }, noms = { "5", "10", "20" },
          libelle = L["Joueurs dans le classement"] },
    } },
    { nom = "softInteract", titre = L["Interaction rapide"], interrupteur = "softInteract",
      desc = L["Comme dans SuperKili : le jeu vise tout seul l'objet le plus proche autour de toi (filon, plante, coffre, objet de quête, bouchon de pêche), jusqu'à 20 m, avec une icône au-dessus. Un appui sur ta touche « Interagir avec la cible » (Options > Raccourcis) le prend. Coupe le module et tes réglages d'avant reviennent."],
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
      desc = L["Règle tes graphismes pour plus d'images par seconde et une image nette (la même liste qu'EllesmereUI). Tes réglages d'avant sont gardés : coupe le module et ils reviennent."],
      options = {
        { cle = "boostFPS", type = "case", libelle = L["Optimiser mes graphismes pour les FPS"],
          info = L["Ombres correctes, textures hautes, effets au sol gardés. Coupés ou baissés : distance de vue, détails du décor, herbes, eau, occlusion ambiante, effets de profondeur, contours, densité des sorts des autres, réverbération du son. Mêmes réglages en raid et donjon, image plus nette. Tes retouches ensuite restent."] },
    } },
    { nom = "meteo", titre = L["Météo et brouillard"], interrupteur = "meteoActif",
      desc = L["Retire la pluie, la neige, les tempêtes de sable et le brouillard : la vue reste dégagée et le jeu plus fluide. Coupe le module et tes réglages d'avant reviennent."],
      options = {
        { cle = "meteoActif", type = "case", libelle = L["Activer"] },
        { cle = "sansMeteo", type = "case", libelle = L["Retirer la météo"],
          info = L["Pluie, neige, tempêtes (weatherDensity 0)."] },
        { cle = "sansBrouillard", type = "case", libelle = L["Retirer le brouillard"],
          info = L["Le brouillard volumétrique (volumeFog 0)."] },
    } },
}

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

-- Module par son nom (« guide », « barreXP »…), nil s'il n'existe pas.
function Reglages.module(nom)
    for _, m in ipairs(Reglages.MODULES) do
        if m.nom == nom then return m end
    end
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
