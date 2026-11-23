# T10.3 — Plan de tests manuels : deux joueurs, mobile, captures

Date : 2026-11-22 — Statut : **A exécutée** le 2026-11-22 (Local Server
lancé par le propriétaire, scénarios pilotés par MCP) : résultats dans
`phases/T10_4_FINAL_VALIDATION_REPORT.md` §5 (M8, M10 non exécutés en
réel). M10 et M12 ont changé d'attendu depuis D-035 (accès conservé,
3 unités réclamées). B (mobile) et C (captures) : à exécuter. Place : place de test
93404872714886 (jamais `GrabAndGrow.rbxl`). Noter pour chaque point OK / KO
et, en cas d'écart, la ligne d'Output ou une capture.

Préparation commune :

- Reconstruire les sites si besoin (Edit, barre de commande) : contenu de `tools/studio/build_sacred_sites.luau`.
- Préréglages, fenêtre **Server**, barre de commande :
  `game.ServerStorage.StudioTestHooks.ApplyPreset:Invoke("J_full", game.Players.Player1)`
  (idem pour `Player2` ; `J_world4` = 4 mondes, journal vide ; sans préréglage = nouveau joueur).
- Lignes à surveiller dans l'Output Server : `[Guardian] GuardianReward:…`, `[Security]`, erreurs `[Guardian]`, `[PlayerData]`.

## A. Local Server — Test > Clients and Servers > Local Server, 2 joueurs

| # | Scénario | Étapes | Attendu |
|---|---|---|---|
| M1 | Accès séparé | Player1 `J_full`, Player2 sans préréglage ; tous deux à l'autel du Sanctuaire des racines | P1 : « Appuyez pour réveiller le gardien » ; P2 : « Débloquez… » ou « Ressources du monde trouvées : x/5 » ; P2 ne peut pas activer (`REQUIREMENT_NOT_MET`) |
| M2 | Combat d'un seul joueur, observateur | P1 active, P2 (`J_full`) reste dans l'arène sans activer | P2 ne voit ni barre de vie, ni zones, ni éclats, ni gardien animé ; aucune touche ni poussée pour P2 ; aucun message pour P2 |
| M3 | Deux combats simultanés au même site | P1 et P2 (`J_full`) activent à quelques secondes d'écart | Chaque fenêtre a sa propre barre de vie, ses propres éclats et attaques ; le gardien regarde chaque joueur dans sa fenêtre ; un éclat de P1 ne peut pas être pris par P2 |
| M4 | Dégâts indépendants | P1 prend 6 éclats, P2 aucun | PV de P1 : 18/24 ; PV de P2 : 24/24 |
| M5 | Victoires simultanées | P1 et P2 terminent dans la même minute | Deux lignes `GuardianReward` (users différents, `combat=` différents, `first=true`) ; chaque autel affiche le retour du gardien pour son joueur seulement |
| M6 | Victoire de l'un, combat de l'autre | P1 gagne pendant que P2 est à mi-vie | Le gardien disparaît dans la fenêtre de P1 seulement ; P2 continue son combat normalement |
| M7 | Réapparition personnelle | Après M6, P2 gagne ; P1 réactive avant 45 s | P1 : `GUARDIAN_RESPAWNING` avec compte à rebours ; P2 a son propre compte à rebours |
| M8 | Déconnexion pendant le combat | P1 en combat à mi-vie : fermer la fenêtre Player1 | Aucune ligne `GuardianReward` pour P1 ; combat de P2 non affecté ; aucune erreur Server |
| M9 | Déconnexion juste après la victoire | P2 gagne puis se déconnecte immédiatement | Une seule ligne `GuardianReward` ; aucune erreur |
| M10 | Reconnexion (état actuel, session) | P2 relance Player2 après M9 | Accès **perdu** (comportement attendu tant que l'option A n'est pas implémentée) ; noter le résultat |
| M11 | Sortie d'arène | P1 en combat sort de l'anneau > 20 s | Message d'avertissement puis fin sans victoire ; P2 inchangé |
| M12 | Ressource sacrée | P1 après victoire prend un nœud sacré ; P2 sans victoire essaie | P1 : « bientôt disponible » (`NOT_AVAILABLE`) ; P2 : refus (`REQUIREMENT_NOT_MET`) ; aucun sac modifié |
| M13 | Collecte normale pendant un combat d'autrui | P2 collecte des ressources du monde pendant le combat de P1 | Collecte de P2 normale ; aucune interférence |
| M14 | Output | Fin de session | Aucune erreur `[Guardian]`, `[SacredSites]` ou `[PlayerData]` ; `[Security]` seulement pour des refus provoqués |

## B. Mobile — recul et latence

Le recul est appliqué par le client sur son propre personnage ; les touches
sont jugées par le serveur sur la position qu'il connaît. Avec de la
latence, un joueur qui esquive au dernier moment sur son écran peut encore
être « touché » côté serveur. À mesurer.

Réglage de latence Studio : File > Studio Settings > Network > Incoming
Replication Lag (0 ; 0,1 ; 0,25 ; 0,5 s), puis Test > Device
(Galaxy A23 ou téléphone équivalent, paysage).

| # | Vérification | Mesure | Seuil proposé (hypothèse) |
|---|---|---|---|
| L1 | Recul visible et court | Poussée de ≈ 18 studs, sans téléportation ni tremblement | Aucun retour en arrière visible (rubber-band) |
| L2 | `MovementValidator` | Output Server pendant 10 touches | 0 correction ou refus de mouvement lié au recul |
| L3 | Esquive tardive | Sortir de la zone pendant les 0,3 dernières secondes de l'annonce, 10 essais par latence | Faux touchés ≤ 1/10 à 0,1 s ; noter le taux à 0,25 et 0,5 s |
| L4 | Étourdissement | Après une touche, appuyer sur Grab | Refus `STUNNED` pendant 1,5 s, message lisible |
| L5 | Lisibilité des zones | Les 9 attaques, en paysage et portrait | Zone et projectile lisibles avant l'impact ; aucune zone cachée par le HUD |
| L6 | Bouton Grab sur éclat | Prendre 10 éclats au pouce | Cible correcte (éclat le plus proche), libellé lisible |
| L7 | HUD | Barre de vie, phase, bannières | Aucun chevauchement avec le sac, les Coins, le bouton Grab |

Appareil réel Galaxy A23 (si disponible) : refaire L1, L3 (latence réelle,
Wi-Fi puis 4G), L5, L6 et noter les images/seconde moyennes pendant un
combat du Mystic Guardian (le plus chargé) avec la mesure de référence de
`performance/T10_1_BASELINE_A23.md`.

## C. Captures — Studio au premier plan

Studio doit être la fenêtre active (sinon le viewport capturé est noir).
Dossier proposé : `docs/phases/T10_3_captures/`.

| # | Capture | Mode |
|---|---|---|
| C1 à C4 | Vue d'ensemble de chaque site (pont, arène, autel, terrasse) | Edit |
| C5 à C8 | Chaque gardien de face, à hauteur de joueur | Edit ou Play |
| C9 | Autel : états verrouillé, éligible, retour du gardien | Play |
| C10 | Combat Forest : zone annoncée + éclats + HUD | Play |
| C11 | Une attaque par forme : anneau, cercle, ligne, cône | Play |
| C12 | Bannière de victoire et gardien masqué | Play |
| C13 | Message « bientôt disponible » sur un nœud sacré | Play |
| C14 | Émulateur téléphone paysage et portrait pendant un combat | Test > Device |

Si l'enregistrement du place est souhaité : File > Save to File As…
`places/T10_1_prototype.rbxl` (ou nouveau nom), jamais `GrabAndGrow.rbxl`.
