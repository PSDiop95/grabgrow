# GRAB & GROW --- Game Design Document (GDD)

> **Document de référence de production**\
> Version : 1.0 --- 10 novembre 2026\
> Statut : concept validé / spécifications initiales\
> Plateforme : Roblox\
> Moteur : Roblox Studio\
> Langage : Luau\
> Développement : développeur solo assisté par Claude Code\
> Direction artistique : 3D Low Poly\
> Bibliothèque d'assets principale : [Polyfork](https://polyfork.dev/)\
> Nom : **GRAB & GROW** (nom de travail, à vérifier avant publication)

------------------------------------------------------------------------

## 0. Résumé exécutif

**GRAB & GROW** est un jeu Roblox multijoueur de collecte, de
progression et de collection. Le joueur explore des mondes colorés,
ramasse des ressources, remplit son sac, vend sa récolte, améliore son
équipement, collectionne des compagnons et débloque de nouveaux
territoires.

La promesse est immédiatement compréhensible : **ramasser, vendre,
améliorer, recommencer plus efficacement**.

La différenciation repose sur trois éléments :

1.  **Une collecte satisfaisante et rapide** : feedback visuel et
    sonore, séries de collecte (*Grab Combo*), objets rares et
    progression immédiatement perceptible.
2.  **Des événements coopératifs** : les joueurs d'un serveur
    contribuent à des objectifs mondiaux temporaires, par exemple briser
    un cristal géant ou collecter les fragments d'un météore.
3.  **Une progression de collection** : ressources, équipements,
    compagnons, découvertes et récompenses cosmétiques donnent des
    objectifs à court, moyen et long terme.

Le jeu vise une audience internationale et une expérience mobile-first,
tout en prenant en charge PC et tablette. La monétisation doit rester
facultative : le jeu gratuit doit être complet et agréable sans achat.

### 0.1 Vision produit

Créer un jeu facile à comprendre en quelques secondes, amusant dès la
première minute et suffisamment riche pour donner envie de revenir, de
progresser et de jouer avec des amis.

### 0.2 Objectifs de production

-   Livrer une première version publique solide, et non une accumulation
    de systèmes incomplets.
-   Construire une architecture serveur fiable et extensible.
-   Réutiliser des assets Low Poly cohérents issus de Polyfork.
-   Optimiser les performances dès le premier monde.
-   Instrumenter le jeu pour mesurer onboarding, rétention, engagement
    et conversion.
-   Développer le contenu par lots réutilisables.

### 0.3 Principes directeurs

-   **Fun avant complexité** : la collecte doit être plaisante sans
    tutoriel long.
-   **Progression lisible** : chaque achat en jeu doit avoir un effet
    compréhensible.
-   **Social sans contrainte** : jouer avec des amis est avantageux,
    mais jamais obligatoire.
-   **Économie contrôlée** : toutes les récompenses et transactions sont
    validées par le serveur.
-   **Mobile-first** : commandes tactiles, textes lisibles et interface
    compacte.
-   **Production réaliste** : tout système doit être maintenable par une
    seule personne.

------------------------------------------------------------------------

## 1. Fiche d'identité

  -----------------------------------------------------------------------
  Élément                             Décision
  ----------------------------------- -----------------------------------
  Titre de travail                    GRAB & GROW

  Genre                               Simulator / Collect / Progression /
                                      Social

  Plateforme                          Roblox

  Public                              Audience Roblox internationale,
                                      familiale

  Caméra                              Troisième personne

  Contrôles                           Mobile, clavier/souris, manette si
                                      compatible

  Mode                                Multijoueur en serveurs publics

  Style                               3D Low Poly, formes lisibles et
                                      couleurs vives

  Langues initiales                   Anglais et français

  Boucle centrale                     Grab → Fill → Sell → Upgrade →
                                      Unlock

  Mondes initiaux                     4 territoires thématiques

  Monnaies                            Coins, Gems, Stars

  Collection                          Ressources, équipements, pets,
                                      cosmétiques

  Événements                          Objectifs coopératifs temporaires

  Sauvegarde                          Données persistantes par joueur

  Monétisation                        Game Pass et Developer Products

  Bibliothèque 3D                     Polyfork en priorité, assets
                                      spécifiques en complément
  -----------------------------------------------------------------------

------------------------------------------------------------------------

## 2. Public cible et positionnement

### 2.1 Public cible

Le jeu s'adresse principalement aux joueurs Roblox qui apprécient : -
les simulateurs de collecte et d'amélioration ; - les objectifs
fréquents et les récompenses visibles ; - les collections de compagnons
et d'objets ; - les mondes colorés à explorer ; - les expériences
sociales simples avec des amis.

Le jeu doit rester accessible aux nouveaux joueurs. Les systèmes avancés
sont introduits progressivement et ne doivent pas surcharger l'écran de
départ.

### 2.2 Positionnement

GRAB & GROW se positionne comme un **collecting simulator social**, plus
dynamique qu'une simple boucle de clic et plus simple à comprendre qu'un
jeu de gestion complexe.

La différenciation ne doit pas reposer uniquement sur le thème ou les
assets. Elle doit venir de la sensation de collecte, du rythme de
progression et des événements coopératifs.

### 2.3 Promesse en une phrase

> Explore des mondes colorés, attrape des ressources, améliore ton
> équipement et participe à des événements géants avec les autres
> joueurs.

------------------------------------------------------------------------

## 3. Piliers de gameplay

### Pilier A --- Collecte satisfaisante

-   Interaction simple et fiable.
-   Objets faciles à distinguer.
-   Feedback immédiat : animation, son, compteur et effet de collecte.
-   Séries de collecte récompensées par un bonus limité.
-   Objets rares clairement signalés.

### Pilier B --- Progression visible

-   Capacité du sac en hausse.
-   Collecte plus rapide ou plus efficace.
-   Nouveaux outils et apparences.
-   Accès à des ressources de valeur supérieure.
-   Déblocage progressif des mondes.

### Pilier C --- Collection

-   Compagnons (Pets) avec raretés et bonus définis.
-   Index des ressources découvertes.
-   Cosmétiques et titres.
-   Récompenses de quêtes et d'événements.

### Pilier D --- Social et viralité

-   Événements communs au serveur.
-   Classements compréhensibles.
-   Bonus modéré lorsque des amis jouent ensemble.
-   Objectifs de serveur qui créent des moments partageables.
-   Récompenses de groupe sans pénaliser les joueurs solo.

------------------------------------------------------------------------

## 4. Boucle de jeu

### 4.1 Boucle principale

1.  **Grab** --- le joueur collecte des ressources dans une zone.
2.  **Fill** --- le sac se remplit jusqu'à sa capacité maximale.
3.  **Sell** --- le joueur vend sa récolte à une station ou via une
    amélioration d'automatisation.
4.  **Upgrade** --- il améliore son sac, son outil ou ses bonus.
5.  **Unlock** --- il débloque une zone, une ressource ou un monde plus
    avancé.
6.  **Repeat** --- il collecte plus efficacement et poursuit de nouveaux
    objectifs.

### 4.2 Première session

La première session doit montrer la valeur du jeu sans attendre.

Objectifs d'expérience : - Le joueur peut se déplacer et collecter
immédiatement. - Le premier objet collecté déclenche un feedback
clair. - Le premier sac se remplit rapidement. - La première vente
intervient très tôt. - Le premier achat d'amélioration est abordable. -
Le joueur comprend qu'une nouvelle zone est accessible après
progression.

Le tutoriel est contextuel : une instruction courte à l'écran, puis une
flèche ou un marqueur vers l'action suivante. Le joueur ne doit pas être
immobilisé par une séquence de dialogues.

### 4.3 Cadence de récompense --- hypothèses à tester

  Moment de jeu     Récompense ou événement attendu
  ----------------- --------------------------------------------------
  0--15 secondes    Première collecte et feedback
  30--60 secondes   Première vente ou première amélioration
  2--4 minutes      Premier objectif de progression clair
  5--10 minutes     Première nouvelle zone ou objectif intermédiaire
  10--15 minutes    Possibilité de participer à un événement serveur

Ces durées sont des cibles de conception initiales, pas des garanties de
rétention. Elles devront être ajustées avec les tests.

------------------------------------------------------------------------

## 5. Système de collecte --- Grab System

### 5.1 Interaction

La collecte doit fonctionner sur toutes les plateformes.

-   **Mobile** : toucher un objet ou maintenir le bouton d'action
    lorsque le mode de collecte continue est activé.
-   **PC** : clic ou touche d'interaction.
-   **Manette** : bouton d'interaction configuré.
-   L'interaction ne doit pas dépendre d'une précision excessive.

Le prototype doit comparer deux variantes : - **Tap to Grab** : le
joueur sélectionne un objet à portée. - **Hold / Auto Grab** : le joueur
maintient l'action et collecte les objets éligibles à proximité.

La variante finale sera choisie selon la fluidité mobile, le confort et
les résultats des tests. Le serveur reste l'autorité sur la validité de
chaque collecte.

### 5.2 Règles de collecte

Chaque ressource possède : - un identifiant unique ; - un monde et une
zone d'apparition ; - une valeur de vente ; - une rareté ; - un temps de
réapparition ; - une distance d'interaction ; - un effet visuel et
sonore ; - éventuellement une condition de déblocage.

Une collecte est acceptée uniquement si le serveur confirme : - que la
ressource existe et est active ; - que le joueur est suffisamment proche
; - que la ressource est disponible ; - que le joueur n'a pas dépassé sa
capacité ; - que la cadence de collecte est plausible.

Le client peut afficher des effets prédictifs, mais ne peut jamais
attribuer lui-même une ressource ou une monnaie.

### 5.3 Capacité du sac

Le sac possède : - une capacité maximale ; - un compteur courant ; - une
barre de progression ; - une animation de remplissage ; - un état plein
clairement visible.

Quand le sac est plein : - la collecte normale est suspendue ; - une
indication invite à vendre ; - une amélioration peut augmenter la
capacité.

Les ressources sont empilées logiquement dans les données du joueur. Il
n'est pas nécessaire de conserver une instance 3D individuelle de chaque
ressource dans le sac.

### 5.4 Grab Combo

Le *Grab Combo* récompense une collecte régulière.

Règle de base proposée : - chaque collecte valide augmente le compteur
; - le compteur retombe après une courte période sans collecte ; - des
paliers accordent un petit bonus de Coins ou un effet visuel ; - le
bonus est plafonné et calculé côté serveur.

Le Combo ne doit pas devenir une obligation stressante. Il reste un
bonus facultatif, et non une condition pour progresser.

------------------------------------------------------------------------

## 6. Vente et économie de base

### 6.1 Vente

La vente convertit les ressources du sac en Coins.

Formule conceptuelle :

`Coins gagnés = somme(valeur de chaque ressource) × multiplicateurs autorisés`

Les multiplicateurs sont calculés à partir de données validées par le
serveur : équipement, bonus temporaires, bonus d'événement et bonus de
compagnon.

### 6.2 Stations de vente

Chaque monde possède une station de vente facilement identifiable.

-   Interaction simple.
-   Résumé du nombre d'objets vendus.
-   Montant gagné affiché de façon animée.
-   Son et effet visuel satisfaisants.
-   Possibilité future d'un retour automatique ou d'une vente
    automatique via un Game Pass ou une amélioration équilibrée.

### 6.3 Monnaies

  -----------------------------------------------------------------------
  Monnaie                 Rôle                    Sources principales
  ----------------------- ----------------------- -----------------------
  Coins                   Monnaie de progression  Vente, quêtes,
                          principale              événements

  Gems                    Monnaie rare de         Quêtes, événements,
                          progression et de       succès, achats
                          collection              autorisés

  Stars                   Monnaie de prestige ou  Objectifs de long terme
                          de progression spéciale et événements
                                                  spécifiques
  -----------------------------------------------------------------------

Les monnaies doivent avoir des usages distincts. Ne pas créer une
monnaie supplémentaire sans fonction durable.

### 6.4 Règles économiques

-   Les Coins servent aux améliorations régulières.
-   Les Gems servent à certains objets spéciaux et à des options de
    collection.
-   Les Stars sont réservées à une progression de prestige définie
    ultérieurement.
-   Aucun achat Robux ne doit être nécessaire pour débloquer le contenu
    principal.
-   Les prix et récompenses sont centralisés dans des modules de
    configuration.
-   Les transactions sont atomiques autant que possible : une opération
    ne doit pas débiter sans attribuer le contenu correspondant.

------------------------------------------------------------------------

## 7. Progression et améliorations

### 7.1 Équipements

  -----------------------------------------------------------------------
  Équipement              Fonction                Effet de progression
  ----------------------- ----------------------- -----------------------
  Backpack                Capacité de stockage    Plus de ressources par
                                                  trajet

  Grabber                 Efficacité de collecte  Collecte plus rapide ou
                                                  plus de valeur

  Magnet                  Attraction des          Portée de collecte
                          ressources              supérieure

  Boots                   Déplacement             Déplacement plus rapide

  Multiplier              Bonus de vente          Revenus augmentés dans
                                                  une limite équilibrée
  -----------------------------------------------------------------------

Chaque équipement doit avoir : - un niveau ; - un coût ; - un effet
chiffré ; - un visuel évolutif si pertinent ; - une limite de
progression ; - un affichage de l'amélioration suivante.

### 7.2 Paliers

Les améliorations sont organisées en paliers. Un palier doit donner un
bénéfice perceptible et être affiché avant l'achat.

Éviter les augmentations minuscules qui ne se ressentent pas. Les coûts
doivent augmenter plus lentement que la valeur perçue de la progression,
sans créer de mur artificiel.

### 7.3 Déblocage des mondes

Le déblocage d'un monde peut exiger : - un montant de Coins ; - un
niveau minimal d'équipement ; - une quête ou une découverte simple.

Ne pas imposer plusieurs conditions simultanées sans raison. Le joueur
doit comprendre exactement ce qui lui manque.

------------------------------------------------------------------------

## 8. Mondes et contenu initial

La version commerciale cible comprend quatre mondes thématiques. Le
développement doit toutefois commencer par un seul monde complet.

### 8.1 Monde 1 --- Green Valley

**Rôle :** monde d'apprentissage et première boucle de progression.

Ambiance : - île verdoyante ; - collines douces ; - arbres stylisés ; -
rochers, petits ponts et chemins ; - couleurs vertes, jaunes et bleues.

Ressources candidates : - bois ; - pierre ; - fruit ; - cristal vert ; -
fleur lumineuse ; - minerai commun ; - ressource rare de zone.

Contenu : - zone de départ ; - station de vente ; - boutique
d'amélioration ; - espace d'œufs ou de compagnons ; - portail vers le
monde suivant ; - zone d'événement.

### 8.2 Monde 2 --- Golden Desert

**Rôle :** première extension de progression.

Ambiance : - dunes dorées ; - rochers ocres ; - cactus stylisés ; -
ruines non réalistes ; - oasis colorée.

Ressources candidates : - pierre de sable ; - cuivre ; - fossile ; -
cristal jaune ; - minerai d'or ; - artefact rare.

### 8.3 Monde 3 --- Frozen Peaks

**Rôle :** introduire un contraste visuel et des ressources plus
précieuses.

Ambiance : - neige et glace ; - montagnes stylisées ; - grottes
cristallines ; - bleu glacier et violet.

Ressources candidates : - glace ; - cristal bleu ; - minerai argenté ; -
pierre gelée ; - diamant ; - cœur de glace rare.

### 8.4 Monde 4 --- Mystic World

**Rôle :** contenu avancé et objectifs de collection.

Ambiance : - îles flottantes ; - cristaux violets ; - plantes
fantastiques ; - plateformes lumineuses ; - ciel stylisé.

Ressources candidates : - fragment magique ; - cristal violet ; -
poussière d'étoile ; - minerai spectral ; - relique ; - cœur mystique
rare.

### 8.5 Structure réutilisable d'un monde

Chaque monde utilise le même modèle de production : - zone d'arrivée ; -
zone de collecte de base ; - zone avancée ; - station de vente ; -
boutique d'améliorations ; - point de quête ; - point d'événement ; -
portail de sortie ; - décor de fond et repères visuels.

Cette structure permet de créer des mondes supplémentaires sans réécrire
les systèmes.

------------------------------------------------------------------------

## 9. Pets et collection

### 9.1 Fonction

Les Pets sont des compagnons visuels qui suivent le joueur et donnent
des bonus limités.

Ils apportent : - une collection à compléter ; - une identité visuelle
; - un objectif de progression ; - une raison de revenir ; - des
récompenses d'événement.

### 9.2 Raretés

Raretés proposées : - Common ; - Uncommon ; - Rare ; - Epic ; -
Legendary ; - Mythic (réservé à du contenu exceptionnel).

La rareté doit être compréhensible visuellement et textuellement. Les
probabilités d'obtention doivent être affichées lorsqu'un système
aléatoire est utilisé.

### 9.3 Bonus

Les bonus possibles : - petit bonus de vente ; - capacité supplémentaire
; - rayon d'attraction ; - bonus de participation aux événements.

Les bonus sont plafonnés afin de ne pas rendre les joueurs sans Pets
inutiles.

### 9.4 Œufs

-   Chaque œuf a un coût et une liste de contenus.
-   Le joueur voit les Pets possibles.
-   Les probabilités sont visibles avant l'ouverture.
-   Les récompenses sont attribuées côté serveur.
-   Les achats aléatoires avec Robux doivent respecter les règles Roblox
    applicables, y compris les exigences de divulgation et les
    restrictions éventuelles selon la région ou le joueur.
-   Prévoir une alternative non aléatoire pour certains objets de
    collection.

### 9.5 Équipement des Pets

La capacité d'équipement est limitée. Des emplacements supplémentaires
peuvent être proposés comme progression ou achat permanent, sans rendre
le jeu injuste.

Le système d'échange entre joueurs est **hors périmètre de la première
version**. Il introduirait des risques de fraude, de duplication et une
complexité supplémentaire.

------------------------------------------------------------------------

## 10. Événements coopératifs et viralité

Les événements sont la principale différenciation sociale.

### 10.1 Principes

-   Un événement est visible par tous les joueurs du serveur concerné.
-   Une jauge commune progresse grâce aux contributions valides.
-   Chaque joueur participant reçoit une récompense individuelle selon
    des règles simples.
-   La contribution ne doit pas être uniquement financière.
-   Les joueurs arrivés tardivement peuvent encore participer.
-   Les récompenses ne doivent pas créer de déséquilibre économique
    majeur.

### 10.2 Événements initiaux

#### Giant Meteor

Un météore s'écrase dans une arène. Les joueurs collectent ses fragments
pendant une durée limitée. La jauge collective débloque un coffre de
récompense.

#### Golden Rush

Pendant une fenêtre temporaire, des ressources dorées apparaissent dans
une zone. Le serveur cherche à atteindre un objectif commun.

#### Crystal Explosion

Un cristal géant possède une jauge de contribution. Les collectes
validées réduisent sa résistance. À la fin, il libère des ressources et
une récompense de participation.

### 10.3 Cadence

Cible initiale : un événement toutes les 10 à 15 minutes par serveur,
avec variation contrôlée.

Cette fréquence est une hypothèse à tester. Elle ne doit pas interrompre
le rythme normal ni rendre les événements répétitifs.

### 10.4 Friend Boost

Un bonus modéré peut être accordé lorsque des amis sont présents dans le
même serveur.

Règles : - plafond strict ; - pas de bonus cumulatif illimité ; - aucun
avantage indispensable ; - aucune obligation d'inviter des amis pour
progresser.

### 10.5 Server Competition

Des objectifs de serveur peuvent comparer la contribution collective
entre sessions ou périodes définies. Les récompenses doivent rester
cosmétiques ou modérées afin de ne pas créer de pression excessive.

------------------------------------------------------------------------

## 11. Quêtes, succès et rétention

### 11.1 Quêtes

Types de quêtes : - collecter un nombre d'objets ; - vendre une valeur
donnée ; - améliorer un équipement ; - découvrir une ressource ; -
participer à un événement ; - ouvrir un œuf gagné en jeu ; - visiter un
nouveau monde.

### 11.2 Catégories

-   Quêtes de démarrage : guider les premières minutes.
-   Quêtes quotidiennes : objectifs courts et renouvelés.
-   Quêtes hebdomadaires : objectifs plus longs.
-   Succès permanents : jalons de collection et de progression.
-   Quêtes d'événement : objectifs temporaires.

### 11.3 Récompenses

Récompenses possibles : - Coins ; - Gems ; - Stars ; - boosts gagnés en
jeu ; - titres ; - cosmétiques ; - œufs ou objets de collection non
premium.

Les récompenses doivent être configurables et ne doivent pas nécessiter
une connexion compulsive. Les séries quotidiennes ne doivent pas punir
lourdement une absence.

------------------------------------------------------------------------

## 12. Interface et expérience utilisateur

### 12.1 Principes UI

-   Interface lisible sur petit écran.
-   Peu de panneaux ouverts simultanément.
-   Boutons tactiles suffisamment grands.
-   Informations essentielles visibles sans ouvrir un menu.
-   Couleurs cohérentes par type de monnaie et d'action.
-   Animations courtes et non bloquantes.

### 12.2 HUD principal

Éléments : 1. Coins ; 2. Gems ; 3. Stars (si activées dans la
progression initiale) ; 4. capacité du sac ; 5. barre de remplissage ;
6. bouton Pets ; 7. bouton Shop ; 8. bouton Worlds ; 9. bouton Quests ;
10. panneau d'événement ; 11. indicateur du Grab Combo.

### 12.3 Panneaux

-   **Shop** : Game Pass, Developer Products et offres clairement
    séparées.
-   **Upgrades** : niveau actuel, prochain niveau, coût et bénéfice.
-   **Pets** : inventaire, rareté, bonus, équipement.
-   **Worlds** : monde actuel, mondes verrouillés, conditions d'accès.
-   **Quests** : objectifs, progression, récompenses.
-   **Collection** : ressources découvertes et manquantes.
-   **Event** : temps restant, jauge collective, contribution et
    récompense.

### 12.4 Accessibilité

-   Ne pas utiliser uniquement la couleur pour transmettre une
    information.
-   Contraste suffisant.
-   Icônes accompagnées de libellés quand leur sens n'est pas évident.
-   Textes courts.
-   Feedback visuel et audio complémentaire.
-   Contrôles testés sur écran tactile de petite taille.

------------------------------------------------------------------------

## 13. Direction artistique

### 13.1 Style général

-   3D Low Poly ;
-   silhouettes simples et reconnaissables ;
-   formes arrondies ou géométriques cohérentes ;
-   palette saturée mais contrôlée ;
-   matériaux simples ;
-   éclairage lisible ;
-   animations courtes ;
-   effets spéciaux réservés aux actions importantes.

Le jeu doit rester lisible à distance et sur un écran mobile.

### 13.2 Palette indicative

  Usage               Direction colorimétrique
  ------------------- ------------------------------------
  Green Valley        verts, turquoise, jaune doux
  Golden Desert       ocre, sable, orange, or
  Frozen Peaks        bleu glacier, blanc, cyan
  Mystic World        violet, magenta, bleu profond
  Coins               jaune / or
  Gems                bleu
  Stars               blanc doré
  Rare / légendaire   violet / magenta / effets lumineux

### 13.3 Personnages

Le personnage principal doit fonctionner avec les avatars Roblox
standards. Les Pets et personnages non-joueurs peuvent utiliser des
modèles Low Poly adaptés.

Ne pas remplacer le système d'avatar Roblox sans justification. Toute
intégration de personnage Polyfork doit être vérifiée pour le rig, les
animations, les proportions et la compatibilité avec les avatars Roblox.

### 13.4 Effets

-   Collecte : petit éclat et mouvement vers le joueur.
-   Vente : compteur qui monte et effet de pièces.
-   Amélioration : impulsion lumineuse et mise en évidence du nouvel
    équipement.
-   Rare : effet distinctif, bref et lisible.
-   Événement : signal sonore, lumière et annonce visuelle claire.

Limiter les particules simultanées et les effets coûteux.

------------------------------------------------------------------------

## 14. Pipeline d'assets --- Polyfork

### 14.1 Source principale

Site : <https://polyfork.dev/>

Polyfork présente un catalogue d'assets 3D Low Poly et de kits
thématiques. Le site indique que les modèles Low Poly sont gratuits, que
les fichiers GLB sont disponibles et que l'utilisation commerciale est
autorisée sans attribution selon ses informations de licence. Les
fichiers gratuits sont également indiqués comme CC BY 4.0 pour le
partage avec attribution. Les éditions HD et certaines fonctionnalités
sont associées à des offres payantes.

**Règle de production :** vérifier la fiche et la licence de chaque
asset au moment du téléchargement. Conserver une copie de la licence, la
fiche de l'asset, son identifiant Polyfork, sa date de téléchargement et
les éventuelles modifications.

### 14.2 Catégories à rechercher

  Catégorie                Usage dans GRAB & GROW
  ------------------------ --------------------------------------------------
  Terrain / îles           Structure des quatre mondes
  Arbres / végétation      Green Valley et oasis
  Rochers / minerais       Ressources collectables et décor
  Cristaux                 Ressources rares et événements
  Cactus / dunes           Golden Desert
  Glace / neige            Frozen Peaks
  Cristaux / plateformes   Mystic World
  Coffres / caisses        Récompenses et décor
  Props / mobilier         Boutiques, stations, points d'intérêt
  Créatures / animaux      Références ou base de Pets
  Personnages              PNJ éventuels, après validation de compatibilité

Ne pas supposer qu'un asset existe sous une forme ou un nom précis. La
sélection doit être faite dans le catalogue réel.

### 14.3 Stratégie d'utilisation

1.  Rechercher les assets par catégorie et par thème.
2.  Privilégier les kits partageant une palette, une échelle et une
    grille.
3.  Prévisualiser les modèles avant téléchargement.
4.  Vérifier le nombre de triangles, les matériaux, les textures, les
    pivots et la hiérarchie.
5.  Télécharger les fichiers GLB nécessaires.
6.  Importer les modèles dans Roblox Studio avec l'Importer.
7.  Vérifier les matériaux, l'échelle, l'orientation, les collisions et
    le rendu.
8.  Créer des variantes de couleur dans Roblox lorsque cela évite de
    multiplier les meshes.
9.  Réutiliser les mêmes IDs de meshes pour les objets identiques.
10. Enregistrer les références et licences dans le manifeste d'assets.

### 14.4 Compatibilité Roblox

Roblox Studio documente l'import de modèles 3D via `.fbx`, `.gltf` et
`.obj`, et la documentation décrit également la hiérarchie d'import des
fichiers GLTF/GLB. Le pipeline prévu est donc :

`Polyfork GLB → vérification → import Roblox Studio → contrôle → intégration`

Les modèles multi-objets peuvent créer plusieurs MeshParts. Il faut
contrôler la hiérarchie importée et fusionner ou simplifier les éléments
lorsque cela est pertinent, sans dégrader les animations ou les parties
mobiles.

### 14.5 Contraintes de sélection

-   Préférer les modèles simples et réutilisables.
-   Éviter les scènes entières importées comme un seul modèle
    monolithique.
-   Séparer les éléments animés des éléments statiques.
-   Utiliser des collisions simples.
-   Éviter les matériaux PBR complexes si le style final est plat et
    stylisé.
-   Réutiliser les meshes identiques.
-   Ne pas télécharger tout le catalogue : sélectionner uniquement les
    assets nécessaires au lot de production courant.

### 14.6 Budgets de performance --- objectifs internes

Les valeurs suivantes sont des cibles de production à mesurer, pas des
limites officielles Roblox.

  Type d'asset                                      Cible indicative
  ------------------------------ -----------------------------------
  Petite ressource collectable                    100--800 triangles
  Prop simple                                   300--1 500 triangles
  Prop majeur                                 1 500--4 000 triangles
  Pet simple                                    500--3 000 triangles
  Décor majeur                                2 000--6 000 triangles
  Élément de terrain modulaire     selon visibilité et réutilisation

Les objets collectables doivent utiliser des collisions simples ou
aucune collision lorsqu'elles ne sont pas nécessaires. Les modèles
décoratifs doivent être ancrés. Éviter les lumières dynamiques et les
ombres inutiles.

### 14.7 Manifeste d'assets

Chaque asset intégré doit être référencé dans un fichier de suivi, par
exemple `docs/assets/ASSET_MANIFEST.md`.

Champs obligatoires : - nom interne ; - nom Polyfork ; - identifiant ou
URL Polyfork ; - catégorie ; - monde ; - nom du fichier source ; -
format ; - nombre de triangles si disponible ; - licence et date de
vérification ; - modifications réalisées ; - emplacement Roblox ; -
statut : à rechercher / sélectionné / téléchargé / importé / validé /
rejeté.

### 14.8 Assets à créer sur mesure

Polyfork est la source principale, mais ne doit pas forcer des compromis
sur les éléments centraux.

Créer ou adapter sur mesure si nécessaire : - les ressources
emblématiques du jeu ; - les Pets qui définissent la collection ; - les
outils d'amélioration ; - les stations de vente ; - les portails ; - les
effets visuels de rareté ; - les éléments de branding et d'interface.

Les icônes HUD ne doivent pas être remplacées par des rendus 3D
difficiles à lire.

------------------------------------------------------------------------

## 15. Architecture technique Roblox

### 15.1 Principes

-   Architecture modulaire.
-   Autorité serveur pour les données, les monnaies, les collectes, les
    achats et les récompenses.
-   Client responsable de l'interface, des contrôles et des effets non
    autoritaires.
-   Configuration séparée du code.
-   Validation stricte des RemoteEvents.
-   Sauvegardes robustes et versionnées.
-   Aucun secret ou identifiant privé dans les scripts répliqués au
    client.

### 15.2 Services serveur

  Service               Responsabilité
  --------------------- --------------------------------------------------
  PlayerDataService     Chargement, validation et sauvegarde des données
  CollectionService     Validation et attribution des collectes
  InventoryService      Sac et inventaire
  EconomyService        Soldes et transactions
  SellingService        Vente des ressources
  UpgradeService        Achat et application des améliorations
  WorldService          Déblocage et accès aux mondes
  PetService            Inventaire et bonus des Pets
  QuestService          Objectifs et récompenses
  EventService          Événements coopératifs
  MonetizationService   Game Pass et Developer Products
  LeaderboardService    Classements
  AnalyticsService      Événements analytiques

### 15.3 Contrôleurs client

  Contrôleur             Responsabilité
  ---------------------- ---------------------------------
  InputController        Contrôles multi-plateformes
  CollectionController   Ciblage et feedback de collecte
  HUDController          HUD et compteurs
  ShopController         Interfaces de boutique
  PetController          Affichage des compagnons
  WorldController        Portails et transitions
  EventController        Interface d'événement
  EffectsController      Effets visuels et audio

### 15.4 Arborescence indicative

``` text
GRAB_AND_GROW/
├── ReplicatedStorage/
│   ├── Shared/
│   │   ├── Config/
│   │   │   ├── EconomyConfig.lua
│   │   │   ├── ResourcesConfig.lua
│   │   │   ├── WorldsConfig.lua
│   │   │   ├── UpgradesConfig.lua
│   │   │   ├── PetsConfig.lua
│   │   │   └── ProductsConfig.lua
│   │   ├── Types/
│   │   └── Remotes/
│   └── Packages/
├── ServerScriptService/
│   ├── Main.server.lua
│   └── Services/
│       ├── PlayerDataService.lua
│       ├── CollectionService.lua
│       ├── InventoryService.lua
│       ├── EconomyService.lua
│       ├── SellingService.lua
│       ├── UpgradeService.lua
│       ├── WorldService.lua
│       ├── PetService.lua
│       ├── QuestService.lua
│       ├── EventService.lua
│       ├── MonetizationService.lua
│       └── LeaderboardService.lua
├── ServerStorage/
│   ├── AssetLibrary/
│   ├── WorldTemplates/
│   └── PetTemplates/
├── StarterPlayer/
│   └── StarterPlayerScripts/
│       ├── Main.client.lua
│       └── Controllers/
├── StarterGui/
│   └── GameUI/
├── Workspace/
│   ├── World/
│   ├── CollectionZones/
│   ├── SellStations/
│   ├── UpgradeStations/
│   ├── Portals/
│   └── EventArena/
└── docs/
    ├── GDD.md
    ├── ECONOMY.md
    ├── TECHNICAL_ARCHITECTURE.md
    ├── ROADMAP.md
    └── assets/
        └── ASSET_MANIFEST.md
```

Cette arborescence est une cible logique. L'implémentation doit
respecter les conventions Roblox Studio et ne pas créer des dossiers ou
modules vides sans utilité immédiate.

### 15.5 Données joueur

Structure indicative :

``` lua
{
    schemaVersion = 1,
    coins = 0,
    gems = 0,
    stars = 0,

    inventory = {
        resources = {},
        pets = {},
        equippedPets = {},
    },

    upgrades = {
        backpackLevel = 1,
        grabberLevel = 1,
        magnetLevel = 1,
        bootsLevel = 1,
        multiplierLevel = 1,
    },

    progression = {
        currentWorld = "GreenValley",
        unlockedWorlds = { "GreenValley" },
        discoveredResources = {},
        completedQuests = {},
        achievements = {},
    },

    settings = {
        musicEnabled = true,
        sfxEnabled = true,
    },

    stats = {
        totalCollected = 0,
        totalCoinsEarned = 0,
        eventsCompleted = 0,
        playTimeSeconds = 0,
    },
}
```

Cette structure est un contrat initial à faire évoluer avec migration de
schéma. Les données de session temporaires et les données persistantes
doivent être séparées.

### 15.6 Sauvegarde

-   Charger les données à l'arrivée du joueur.
-   Valider et compléter les champs manquants.
-   Utiliser `UpdateAsync` pour les mises à jour nécessitant une
    protection contre les écrasements.
-   Gérer les erreurs et les limites de requêtes.
-   Prévoir des tentatives espacées et une file de sauvegarde.
-   Sauvegarder à intervalles raisonnables et à la sortie, sans dépendre
    uniquement de l'événement de départ.
-   Ne pas sauvegarder chaque collecte individuellement.
-   Tester les déconnexions, erreurs de DataStore et migrations.

### 15.7 Sécurité serveur

Le serveur doit vérifier : - distance et cadence de collecte ; -
existence et disponibilité des ressources ; - capacité du sac ; - solde
avant achat ; - propriété des Game Pass ; - reçus Developer Products ; -
éligibilité aux récompenses d'événement ; - conditions des quêtes ; -
données envoyées par chaque RemoteEvent.

Le client ne doit jamais envoyer un montant de Coins à créditer, un prix
à appliquer ou une récompense à attribuer.

### 15.8 Achats Roblox

-   Utiliser `MarketplaceService` pour les achats.
-   Utiliser `ProcessReceipt` pour les Developer Products.
-   Traiter les reçus de façon idempotente afin qu'un même reçu ne
    crédite pas deux fois un produit.
-   Vérifier les Game Pass côté serveur.
-   Prévoir les cas d'achat annulé, de reçu rejoué ou de données
    temporairement indisponibles.
-   Ne jamais accorder un produit uniquement parce que le client annonce
    que l'achat a réussi.

------------------------------------------------------------------------

## 16. Monétisation

### 16.1 Principes commerciaux

-   Le jeu doit être amusant sans payer.
-   Les achats doivent être compréhensibles et facultatifs.
-   Éviter les murs de progression artificiels.
-   Favoriser les achats permanents de confort et les cosmétiques.
-   Ne pas vendre un avantage qui détruit la compétition.
-   Tester les prix avant de les figer.
-   Respecter les règles Roblox et les exigences applicables aux achats
    aléatoires.

### 16.2 Game Pass --- propositions à tester

  ------------------------------------------------------------------------
  Produit               Effet proposé              Prix de départ à tester
  --------------------- --------------------- ----------------------------
  VIP                   Badge, cosmétique,                       299 Robux
                        bonus social modéré   

  x2 Coins              Double les gains                         399 Robux
                        éligibles             

  Auto Sell             Vente automatique                        249 Robux
                        selon une cadence     
                        plafonnée             

  Extra Pet Slot        Un emplacement de Pet                    199 Robux
                        supplémentaire        

  Premium Name Tag      Apparence de nom                          99 Robux
                        cosmétique            
  ------------------------------------------------------------------------

Les prix sont des hypothèses de test. Les effets doivent être équilibrés
et documentés.

### 16.3 Developer Products --- propositions à tester

  Produit              Effet                                     Prix indicatif
  -------------------- --------------------------------------- ----------------
  Boost Coins 15 min   Bonus temporaire de Coins                       29 Robux
  Boost Luck 15 min    Bonus de chance selon règles publiées           39 Robux
  Pack Gems S          Petit pack de Gems                              49 Robux
  Pack Gems M          Pack intermédiaire                             149 Robux
  Pack Gems L          Grand pack de Gems                             499 Robux
  Event Boost          Petit bonus temporaire d'événement              29 Robux

Ne pas finaliser le catalogue avant les tests économiques. Les produits
ne doivent pas être vendus si leur attribution n'est pas fiable.

### 16.4 Starter Pack

Un pack de bienvenue facultatif peut proposer : - un cosmétique exclusif
; - un Pet non indispensable ; - une quantité limitée de Gems ; - un
boost de courte durée.

Le contenu, la valeur et le prix doivent être affichés clairement. Ne
pas multiplier les fenêtres d'achat intrusives.

### 16.5 Publicité

Les annonces publicitaires et récompenses publicitaires ne font pas
partie du MVP. Elles pourront être évaluées après validation de
l'expérience de base et selon les formats Roblox disponibles et
autorisés au moment de l'intégration.

### 16.6 DevEx

Les Robux gagnés ne sont pas automatiquement équivalents à un revenu
encaissable. Toute projection financière doit distinguer Robux bruts,
frais/partages applicables, Robux éligibles et conditions du programme
Developer Exchange.

------------------------------------------------------------------------

## 17. Analytics et indicateurs de réussite

### 17.1 Événements à instrumenter

-   `tutorial_started`
-   `tutorial_completed`
-   `first_resource_collected`
-   `first_bag_full`
-   `first_sale_completed`
-   `first_upgrade_purchased`
-   `world_unlocked`
-   `pet_egg_opened`
-   `event_joined`
-   `event_completed`
-   `purchase_prompted`
-   `purchase_completed`
-   `session_ended`

Les événements doivent éviter de transmettre des données personnelles
inutiles.

### 17.2 KPI

  Indicateur            Pourquoi le suivre
  --------------------- --------------------------------
  Tutorial completion   Compréhension initiale
  D1 retention          Retour le lendemain
  D7 retention          Valeur de retour à une semaine
  Session length        Engagement
  Sessions per user     Fréquence d'utilisation
  First sale time       Fluidité de la première boucle
  First upgrade time    Lisibilité de la progression
  Event participation   Attrait social
  Payer conversion      Conversion commerciale
  Revenue per payer     Dépense moyenne des acheteurs
  Crash / error rate    Qualité technique

### 17.3 Cibles de travail initiales

Ces seuils sont des objectifs internes à valider, et non des benchmarks
garantis par Roblox.

-   Tutorial completion : viser au moins 80 %.
-   Rétention D1 : objectif initial 25 %.
-   Rétention D7 : objectif initial 10 %.
-   Session moyenne : viser environ 10 minutes.
-   Participation aux événements : objectif initial 50 % des joueurs
    éligibles.

Analyser les cohortes et les sources d'acquisition. Ne pas modifier
plusieurs variables à la fois lors d'un test.

------------------------------------------------------------------------

## 18. Performance et qualité

### 18.1 Plateformes prioritaires

-   Téléphones mobiles d'entrée et de milieu de gamme.
-   Tablettes.
-   PC.

Le mobile constitue la référence de conception de l'interface et des
performances.

### 18.2 Règles d'optimisation

-   Activer et tester l'Instance Streaming lorsque la structure du monde
    le justifie.
-   Réutiliser les mêmes assets et Mesh IDs.
-   Limiter les MeshParts uniques.
-   Réduire les collisions complexes.
-   Ancrer les objets statiques.
-   Limiter les particules, lumières et ombres.
-   Éviter les boucles de calcul inutiles.
-   Utiliser des interactions par proximité et des zones organisées.
-   Ne pas créer une instance serveur pour chaque effet visuel éphémère.
-   Profiler sur appareil réel et dans plusieurs niveaux de qualité
    graphique.

### 18.3 Critères de qualité

-   Pas de duplication de monnaie ou d'objets.
-   Pas de perte de progression lors des scénarios de test.
-   Pas de collecte à distance.
-   Pas d'achat crédité deux fois.
-   Pas de blocage du tutoriel.
-   Interface utilisable sur mobile.
-   Transitions de mondes fiables.
-   Événements terminables et récompenses cohérentes.
-   Temps de chargement acceptable sur appareils modestes.

------------------------------------------------------------------------

## 19. Périmètre de la première version commerciale

### 19.1 Inclus dans la cible de lancement

-   Boucle Grab / Fill / Sell / Upgrade.
-   Green Valley complet.
-   Trois mondes supplémentaires avec contenu de progression.
-   Sac et cinq catégories d'améliorations.
-   Ressources communes et rares.
-   Pets et œufs gagnés en jeu.
-   Quêtes quotidiennes et succès.
-   Trois événements coopératifs.
-   Classements simples.
-   Sauvegarde persistante.
-   Game Pass et Developer Products.
-   HUD mobile-first.
-   Anglais et français.
-   Analytics et outils de test.

### 19.2 MVP technique obligatoire

Avant d'étendre le contenu, le prototype doit inclure : - un petit
espace jouable de Green Valley ; - trois ressources ; - un sac avec
capacité ; - une station de vente ; - une monnaie ; - deux améliorations
; - une sauvegarde fonctionnelle ; - deux joueurs capables de jouer sur
le même serveur.

### 19.3 Hors périmètre initial

-   Échange de Pets entre joueurs.
-   Système complexe de crafting.
-   Combat PvP.
-   Construction libre de base.
-   Monde ouvert continu de très grande taille.
-   Marché entre joueurs.
-   Guildes et clans.
-   Économie pilotée par les joueurs.
-   Événements inter-serveurs complexes.
-   Système de trading ou de revente d'objets.

Ces systèmes ne seront envisagés qu'après validation de la rétention et
de la stabilité.

------------------------------------------------------------------------

## 20. Roadmap de production --- 10 semaines

Le calendrier est une cible ambitieuse pour un développeur solo
utilisant des assets existants et Claude Code. Il doit être ajusté selon
la disponibilité réelle et les résultats des tests.

  -----------------------------------------------------------------------
  Période                 Lot                     Livrable
  ----------------------- ----------------------- -----------------------
  Semaine 1               Fondations              Projet Roblox,
                                                  architecture,
                                                  contrôles, scène
                                                  prototype

  Semaines 2--3           Core loop               Collecte, sac, vente,
                                                  Coins, améliorations

  Semaine 4               Progression             Monde 1, portails,
                                                  déblocage, quêtes

  Semaine 5               Collection et social    Pets, inventaire,
                                                  premier événement

  Semaine 6               Données et monétisation Sauvegarde, sécurité,
                                                  achats

  Semaine 7               Contenu et art          Mondes 2--4,
                                                  intégration Polyfork,
                                                  HUD

  Semaine 8               Qualité                 Optimisation, tests
                                                  multi-plateformes,
                                                  corrections

  Semaine 9               Test fermé              Retours joueurs,
                                                  équilibrage,
                                                  corrections

  Semaine 10              Lancement               Page expérience,
                                                  miniature, publication
                                                  et suivi
  -----------------------------------------------------------------------

### 20.1 Jalons de validation

**Gate 1 --- Core loop** - Collecte fiable. - Sac fonctionnel. - Vente
et achat d'amélioration. - Aucun crédit client non autorisé.

**Gate 2 --- Progression** - Déblocage de monde. - Données
persistantes. - Quêtes et Pets fonctionnels.

**Gate 3 --- Social** - Événement coopératif. - Récompenses validées par
serveur. - Classement sans duplication.

**Gate 4 --- Commercial** - Achats réels testés en environnement
approprié. - `ProcessReceipt` idempotent. - Catalogue et prix validés.

**Gate 5 --- Release** - Tests mobiles et PC. - Pas de bug bloquant
connu. - Analytics actifs. - Visuels et description conformes au jeu.

------------------------------------------------------------------------

## 21. Plan de tests

### 21.1 Gameplay

-   Collecter une ressource disponible.
-   Refuser une ressource trop éloignée.
-   Refuser une collecte trop rapide.
-   Gérer un sac plein.
-   Vendre un sac vide.
-   Vendre un sac rempli.
-   Acheter une amélioration.
-   Refuser un achat sans fonds.
-   Débloquer un monde.
-   Participer à un événement.
-   Recevoir une récompense une seule fois.

### 21.2 Données

-   Première connexion.
-   Reconnexion avec données existantes.
-   Déconnexion pendant une collecte.
-   Déconnexion après une vente.
-   Erreur de sauvegarde simulée.
-   Migration de schéma.
-   Deux sessions rapprochées.
-   Données manquantes ou invalides.

### 21.3 Sécurité

-   RemoteEvent envoyé à cadence excessive.
-   Valeur de ressource falsifiée par le client.
-   Vente sans inventaire.
-   Achat sans fonds.
-   Tentative de déblocage de monde sans condition.
-   Rejeu d'un reçu Developer Product.
-   Récompense d'événement dupliquée.

### 21.4 Plateformes

-   Mobile tactile.
-   PC clavier/souris.
-   Tablette.
-   Plusieurs résolutions.
-   Connexion réseau lente.
-   Serveur avec plusieurs joueurs.
-   Appareil mobile modeste.

------------------------------------------------------------------------

## 22. Risques et mesures de réduction

  -----------------------------------------------------------------------
  Risque                              Mesure
  ----------------------------------- -----------------------------------
  Boucle trop répétitive              Combo, événements, quêtes et
                                      progression visible

  Contenu trop long à produire        Kits Polyfork et structure de monde
                                      réutilisable

  Performance faible sur mobile       Profiling, assets simples,
                                      streaming, collisions légères

  Exploits de monnaie                 Autorité serveur et validation
                                      stricte

  Perte de données                    Sauvegarde robuste, versionnement
                                      et tests

  Monétisation trop agressive         Progression gratuite viable et
                                      achats facultatifs

  Rétention insuffisante              Tester tôt la première session et
                                      les cohortes

  Dépendance aux assets externes      Manifeste, licences conservées et
                                      assets alternatifs

  Périmètre trop ambitieux            MVP strict et gates de validation
  -----------------------------------------------------------------------

------------------------------------------------------------------------

## 23. Critères d'acceptation du projet

Le jeu est prêt pour un lancement public lorsque :

-   un nouveau joueur comprend comment collecter sans aide externe ;
-   il peut compléter plusieurs cycles de vente et d'amélioration ;
-   le sac, les monnaies et les améliorations sont cohérents ;
-   les données persistent après reconnexion ;
-   les quatre mondes sont accessibles selon leurs conditions ;
-   les événements coopératifs fonctionnent sur serveur ;
-   les Pets et leurs bonus sont attribués de manière fiable ;
-   les achats sont traités côté serveur ;
-   les interfaces sont utilisables sur mobile et PC ;
-   les assets ont été contrôlés et consignés ;
-   les tests de sécurité et de sauvegarde ne révèlent aucun bug
    bloquant ;
-   les analytics nécessaires au suivi du lancement sont actifs.

------------------------------------------------------------------------

## 24. Décisions ouvertes à valider par prototype

Les éléments suivants sont des hypothèses de conception et doivent être
confirmés par des tests :

1.  Tap to Grab ou Hold / Auto Grab.
2.  Vente manuelle uniquement ou vente automatique déblocable.
3.  Valeurs exactes des ressources et courbes de coûts.
4.  Nombre de Pets équipables gratuitement.
5.  Bonus maximum des Pets.
6.  Fréquence exacte des événements.
7.  Capacité des serveurs et densité des ressources.
8.  Prix finaux des Game Pass et Developer Products.
9.  Place des Stars dans la progression initiale.
10. Nombre de ressources réellement nécessaires par monde.

Aucune de ces décisions ne doit être figée sans test de gameplay ou
simulation économique.

------------------------------------------------------------------------

## 25. Références de production

### Polyfork

-   Site principal : https://polyfork.dev/
-   Catalogue : https://polyfork.dev/
-   Guide pour agents : https://polyfork.dev/prompt.txt
-   Documentation catalogue : https://polyfork.dev/llms.txt
-   Endpoint MCP : https://polyfork.dev/mcp
-   Guide agents : https://polyfork.dev/agents

Polyfork indique proposer des assets Low Poly gratuits, des fichiers
GLB, des kits cohérents et une licence permettant l'usage commercial
sans attribution. Vérifier les conditions actuelles et conserver la
licence correspondant à chaque asset téléchargé.

### Roblox Creator Hub

-   Importer des modèles :
    https://create.roblox.com/docs/studio/importer
-   Optimisation des performances :
    https://create.roblox.com/docs/performance-optimization/improve
-   Découverte : https://create.roblox.com/docs/discovery
-   Analytics : https://create.roblox.com/docs/production/analytics
-   Monétisation :
    https://create.roblox.com/docs/production/monetization
-   Data Stores :
    https://create.roblox.com/docs/cloud-services/data-stores

### Notes d'implémentation Polyfork

Le site Polyfork décrit un serveur MCP utilisable par des agents de
développement, notamment Claude Code. Son endpoint annoncé est
`https://polyfork.dev/mcp`. L'utilisation de ce MCP est une option de
workflow à configurer et tester ; le GDD ne suppose pas qu'il est déjà
connecté.

------------------------------------------------------------------------

## 26. Historique des versions

  -----------------------------------------------------------------------
  Version                 Date                    Modifications
  ----------------------- ----------------------- -----------------------
  1.0                     2026-11-10              Première version du GDD
                                                  : vision, gameplay,
                                                  mondes, Pets,
                                                  événements,
                                                  monétisation,
                                                  architecture, pipeline
                                                  Polyfork et roadmap

  -----------------------------------------------------------------------

------------------------------------------------------------------------

**Fin du document --- GRAB & GROW GDD v1.0**

Ce document constitue la référence de conception initiale. Toute
modification majeure de gameplay, économie, architecture ou périmètre
doit être reportée ici avant d'être considérée comme validée.
