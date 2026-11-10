# GRAB & GROW — Roadmap

Dernière mise à jour : 2026-11-10

Phasage du MVP repris de l'architecture technique (section 20, T0 à T8).
Le calendrier 10 semaines du GDD (section 20) reste la cible commerciale,
mais son ordre (Pets avant sauvegarde) n'est pas suivi : voir
`decisions/TECHNICAL_DECISIONS.md`, D-004.

Un lot n'est « terminé » que si ses critères ont été vérifiés par un test
réellement exécuté. État détaillé : `PROJECT_STATUS.md`.

## MVP

| Phase | Livrable | Critère de validation | État |
|---|---|---|---|
| T0 | Structure du projet et configurations | Projet organisé, lancement sans erreur dans Studio | Partiel — fichiers prêts, lancement Studio non vérifié |
| T1 | Profil joueur et sauvegarde | Chargement, sauvegarde, reconnexion, pas d'écrasement | À faire |
| T2 | Collecte et inventaire | Collecte validée serveur, sac limité | À faire |
| T3 | Vente et Coins | Transaction fiable, inventaire vidé correctement | À faire |
| T4 | Améliorations (Backpack, Grabber) | Achats validés côté serveur | À faire |
| T5 | HUD et feedback mobile | Boucle complète utilisable sur téléphone | À faire |
| T6 | Tests multijoueurs et anti-exploit | Aucun exploit simple, aucune fuite de données | À faire |
| T7 | Équilibrage MVP | Première session compréhensible et satisfaisante | À faire |
| T8 | Préparation publication | Tests privés concluants | À faire |

## Pour clôturer T0

1. Valider le flux de travail fichiers → Studio (D-001).
2. Créer le fichier place et y synchroniser `src/`.
3. Lancer Play dans Studio : `[Tests] ConfigTests : OK` dans Output, aucune erreur.

## Après le MVP (ne pas commencer avant validation de T0 à T8)

- Magnet, Boots, Multiplier ; achats x10 / x100 / MAX.
- Wild Fruit, Green Crystal ; Grab Combo.
- Golden Desert, Frozen Peaks, Mystic World.
- Gems, Stars et Prestige.
- Pets et œufs ; quêtes et succès ; événements coopératifs.
- Monétisation (Game Pass, Developer Products).
- Classements et fonctions sociales.
