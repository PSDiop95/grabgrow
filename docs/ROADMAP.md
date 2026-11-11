# GRAB & GROW — Roadmap

Dernière mise à jour : 2026-11-11

Phasage du MVP repris de l'architecture technique (section 20, T0 à T8).
Le calendrier 10 semaines du GDD (section 20) reste la cible commerciale,
mais son ordre (Pets avant sauvegarde) n'est pas suivi : voir
`decisions/TECHNICAL_DECISIONS.md`, D-004.

Un lot n'est « terminé » que si ses critères ont été vérifiés par un test
réellement exécuté. État détaillé : `PROJECT_STATUS.md`.

## MVP

| Phase | Livrable | Critère de validation | État |
|---|---|---|---|
| T0 | Structure du projet et configurations | Projet organisé, lancement sans erreur dans Studio | Terminé le 2026-11-10 — analyse Luau propre, `ConfigTests : OK` dans Studio |
| T1 | Profil joueur et sauvegarde | Chargement, sauvegarde, reconnexion, pas d'écrasement | Code et tests terminés le 2026-11-11 (44 cas OK sous Lune et dans Studio) — commité localement ; sauvegarde auto, sauvegarde de sortie et DataStore réel **non vérifiés** (V-01 à V-05) |
| T2 | Collecte et inventaire | Collecte validée serveur, sac limité | À faire |
| T3 | Vente et Coins | Transaction fiable, inventaire vidé correctement | À faire |
| T4 | Améliorations (Backpack, Grabber) | Achats validés côté serveur | À faire |
| T5 | HUD et feedback mobile | Boucle complète utilisable sur téléphone | À faire |
| T6 | Tests multijoueurs et anti-exploit | Aucun exploit simple, aucune fuite de données | À faire |
| T7 | Équilibrage MVP | Première session compréhensible et satisfaisante | À faire |
| T8 | Préparation publication | Tests privés concluants | À faire |

## Prochaine phase : T2

Collecte et inventaire, par-dessus `PlayerDataService.Update`
(`DATA_PERSISTENCE.md`). Démarrage soumis à la validation de T1 par le
propriétaire. D-008 et D-009 acceptées ; la persistance réelle
reste à vérifier (`PROJECT_STATUS.md`, V-01 à V-05).

## Après le MVP (ne pas commencer avant validation de T0 à T8)

- Magnet, Boots, Multiplier ; achats x10 / x100 / MAX.
- Wild Fruit, Green Crystal ; Grab Combo.
- Golden Desert (contenu réel ; seule l'entrée verrouillée existe), Frozen Peaks, Mystic World.
- Gems, Stars et Prestige.
- Pets et œufs ; quêtes et succès ; événements coopératifs.
- Monétisation (Game Pass, Developer Products).
- Classements et fonctions sociales.
