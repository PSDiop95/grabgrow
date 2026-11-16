# Rapport de tests analytics — T9

Date : 2026-11-16. Exécutés par Claude, sauf mention contraire. Aucun
DataStore réel touché (Lune : magasin en mémoire ; Studio :
`DataConfig.Studio.useMemoryStore = true`).

## Synthèse

| Test | Résultat | Preuve |
|---|---|---|
| Lune (toutes suites) | PASS | `lune run tools/run_tests.luau` : 21 suites, 429 cas, « TOUS LES TESTS : OK » (401 avant T9 + 28 `AnalyticsTests`) |
| Contrôle de mutation | PASS | Suppression de l'événement de vente : 18 échecs `AnalyticsTests`, code restauré |
| luau-lsp strict | PASS | `luau-lsp analyze ... src` : code de sortie 0, 0 erreur |
| Rojo build | PASS | `rojo build default.project.json` : place construit (356 Ko) |
| Studio solo | PASS | Play sur le place de test (93404872714886), voir ci-dessous |
| Studio multijoueur (Local Server) | NOT TESTED | Non lançable par l'outil ; procédure ci-dessous pour le propriétaire. Couvert en logique par le cas Lune « deux joueurs simultanés » |
| Analytics Roblox (Creator Dashboard) | PARTIAL | Expérience de test privée, sessions du 16/11 (15:18–15:27 et 15:54–16:05) lancées depuis Roblox : « Voir les événements » montre 10 événements économiques et 18 personnalisés, conformes et sans doublon (détail ci-dessous). Non observés dans Roblox : onboarding, progression, `WorldEntered`, `BackpackFull`, succès, déblocage |
| Non-régression économique | PASS | Suites économie, vente, amélioration, succès inchangées et OK ; cas « panne analytics sans effet sur le jeu » (soldes et progression identiques) ; aucune valeur de config modifiée |

## Tests unitaires (Lune, `Tests/AnalyticsTests.lua`)

| Cas | Résultat |
|---|---|
| Événement valide (voyage) | PASS |
| Paramètres invalides (monde, ressource, quantité, montant nul, solde NaN, amélioration et succès inconnus) : 7 ignorés | PASS |
| Joueur absent / sans session / UserId invalide | PASS |
| Événement dupliqué (session ouverte et fermée deux fois) | PASS |
| Transaction refusée (vente, achat, déblocage, collecte, voyage) | PASS |
| Transaction réussie (arguments exacts de la vente) | PASS |
| Profil absent | PASS |
| Erreur simulée du sink : aucune erreur propagée, aucune nouvelle tentative, journal limité | PASS |
| Analytics désactivé : aucun appel | PASS |
| Session terminée : durée serveur arrondie, plus d'événement | PASS |
| Reconnexion : aucune étape rétroactive ni répétée | PASS |
| Onboarding ordonné quand une étape est sautée | PASS |
| Budget : priorité basse écartée d'abord, nouvelle fenêtre | PASS |
| Sac plein : un événement par épisode | PASS |
| Collecte agrégée par lots et par monde | PASS |
| Monde d'une zone de vente borné | PASS |

## Tests d'intégration (Lune, services réels câblés comme Bootstrap)

| Cas | Résultat |
|---|---|
| Première collecte et découverte du journal (une seule fois) | PASS |
| Première vente puis 3 ventes répétées (un événement par vente, montant et solde = profil) | PASS |
| Vente refusée (sac vide) | PASS |
| Première amélioration et achats répétés (SKU, type, solde ; refus sans événement) | PASS |
| Déblocage d'un monde (refus, dépense, solde juste après le débit, progression) | PASS |
| Parcours complet : étapes 1 à 5 une seule fois | PASS |
| Succès = source de Coins (solde final) | PASS |
| Panne analytics sans effet sur le jeu | PASS |
| Analytics désactivé, jeu identique | PASS |
| Reconnexion (reprise à l'étape 3) | PASS |
| Deux joueurs simultanés (événements et soldes non croisés) | PASS |
| Aucune donnée personnelle dans les champs | PASS |
| Déplacement entre mondes | Couvert en unitaire et en Studio (le service de voyage exige la carte) |

## Studio solo (2026-11-16, sink `log`, profil en mémoire)

Parcours réel par les RemoteEvents depuis le client (marche vers les
ressources, puis vers la station de vente) et préréglages Studio pour les
Coins. Sortie observée :

| Action | Événements observés | Résultat |
|---|---|---|
| Arrivée (profil neuf) | `onboarding 1 JoinedGame` | PASS |
| 6 collectes | `JournalDiscovery = 1 [GreenValley,Common]` (une fois), `onboarding 2 FirstCollection` ; aucun événement par collecte | PASS |
| Vente (+6) | `ResourcesCollected = 6 [GreenValley]`, `economy Source 6 Coins -> 6 (Gameplay, Sale:GreenValley)`, `onboarding 3 FirstSale` | PASS |
| Achat Backpack (−75) puis achat refusé | `economy Sink 75 Coins -> 45 (Shop, Upgrade:Backpack)`, `UpgradePurchased [Backpack,2]`, `onboarding 4 FirstUpgrade` ; refus : rien | PASS |
| Déblocage refusé (Frozen Peaks) puis Golden Desert (−1 500) | Refus : rien ; `economy Sink 1500 Coins -> 0 (ContextualPurchase, World:GoldenDesert)`, `progression Worlds 2 GoldenDesert complete` | PASS |
| Succès `world_2` (+1 000) | `economy Source 1000 Coins -> 1000 (Gameplay, Achievement:world_2)` | PASS |
| Voyages aller-retour | `WorldEntered [GoldenDesert]`, `WorldEntered [GreenValley]` | PASS |
| Arrêt de Play | `SessionEnded = 1463` avant la sauvegarde de sortie | PASS |
| Vrais appels Roblox (sink `roblox`, 4 méthodes) | Aucun erreur ; Studio : « AnalyticsService: Log…Event event fired » | PASS |

Étape 5 non envoyée en Studio : **comportement attendu**. Le préréglage
`U7_ready` remet les statistiques à zéro, donc la condition « première
vente » n'était plus remplie au moment du déblocage. L'étape 5 est couverte
par le cas Lune « parcours complet ».

## À faire par le propriétaire

### Studio multijoueur (Local Server, 2 joueurs)

1. Test > Clients and Servers > Local Server, 2 joueurs.
2. Avec chaque joueur : collecter, vendre, acheter une amélioration.
3. Dans l'Output du **serveur** : une ligne `[Analytics] onboarding 1..4`
   par joueur, une ligne `economy` par transaction, aucune en double.
4. Fermer un client : une seule ligne `SessionEnded` pour ce joueur ; le
   second continue normalement.

### Vérification Roblox (après autorisation de publication privée, D5)

1. Publier la version courante dans l'**expérience de test** (jamais la
   production), accès privé.
2. Jouer une session : collecte, vente, amélioration, déblocage, voyage.
3. Creator Dashboard > Analytics > « View Events » : noms, valeurs, SKU,
   flux ; absence de doublons.
4. Après 24 h : onglets Economy, Funnels (Onboarding), Custom.
5. Ne pas conclure à un échec tant que le délai de 24 h n'est pas écoulé.

### Vérification Roblox : constat du 2026-11-16

- Univers 10775875517 : `visibility = PRIVATE` (Open Cloud) ; publication
  de « Test Grab & Grow » le 16/11 à 14:40 (historique d'activité), après
  le code T9 ; place de Studio identique au dépôt avant publication.
- Deux sessions jouées par le propriétaire sur la version publiée.
- « Voir les événements » (Économie, Entonnoirs), rafraîchi après la
  seconde session : « Aucun événement détecté ». Graphiques vides (délai de
  24 h attendu).
- Causes possibles, non départagées : délai de traitement ; filtre de
  Roblox (expérience privée, sessions du propriétaire : non documenté) ;
  échec des appels sur le serveur publié (le jeu continue ; une ligne
  `[Analytics] … en échec` apparaît alors dans la console serveur).
- Console serveur (F9, Log / Server) de la session suivante, à 15:46 :
  `[Bootstrap] Studio : profils en mémoire…`, `[Tests] AnalyticsTests : OK
  (28 cas)`, `[Analytics] onboarding 1 JoinedGame`. Cette session tournait
  donc **dans Studio**, d'où l'absence d'envoi vers Roblox. Le
  comportement du code y est conforme (étapes 1 et 2, découverte du
  journal).
- Reste à faire : une session lancée depuis l'application ou le site Roblox
  (page de l'expérience, bouton Jouer). La console serveur doit alors
  montrer `[Bootstrap] DataStore : …` et ni `[Tests]` ni `[Analytics]`
  (aucune ligne `[Analytics]` = aucun échec d'envoi).

### Vérification Roblox : résultat (2026-11-16, « Voir les événements »)

Les sessions jouées plus tôt depuis Studio n'envoyaient rien (normal) ;
celles lancées depuis Roblox sont arrivées, avec quelques minutes de
retard pour la première.

| Type | Reçus | Contrôle |
|---|---|---|
| Économie `Source` `Sale:GreenValley` (`Gameplay`) | 9 | Montants positifs ; soldes enchaînés sans trou : 236 → 286 → 36 → 100 → 128 → 159 → 170 → 196 → 230 → 266 |
| Économie `Sink` `Upgrade:Boots` (`Shop`) | 1 | 250 Coins, solde 286 → 36 |
| `ResourcesCollected` [GreenValley] | 10 | Un lot à chaque vente (même horodatage) et un au départ (16:05:35, collectes non vendues) |
| `SessionEnded` | 2 | 546 s et 658 s, une par session |
| `JournalDiscovery` [GreenValley, rareté] | 5 | Common ×3, Uncommon, Rare : premières découvertes du profil (journal v3 vide après migration) |
| `UpgradePurchased` [Boots, 2] | 1 | Même horodatage que la dépense |
| Entonnoir d'onboarding | 0 | **Attendu** : le profil publié avait déjà progressé (aucune étape rétroactive) |

Champs personnalisés : uniquement des valeurs de configuration (monde,
rareté, amélioration, niveau). L'identifiant d'utilisateur affiché est la
colonne propre à Roblox, pas un champ envoyé par le jeu.

Restent à observer dans Roblox (déjà validés en Lune et en Studio) :
onboarding (compte ou profil neuf), progression `Worlds` et dépense
`World:*`, succès `Achievement:*`, `WorldEntered`, `BackpackFull`.
Graphiques Economy / Funnels / Custom : à relire après 24 h.
