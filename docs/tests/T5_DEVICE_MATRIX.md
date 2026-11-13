# T5.5 — Matrice des appareils

Date : 2026-11-13. Légende : **OK** exécuté et conforme ; **OK (antérieur)**
exécuté lors d'un lot précédent (référence) ; **À faire** non exécuté ;
**Reporté** matériel absent. Un résultat d'émulateur ne vaut pas
validation sur appareil réel.

## Appareils

| Appareil | Type | Résolution / format | Testé en T5.5 par | Statut |
|---|---|---|---|---|
| Studio, émulateur « téléphone paysage » (tactile, fr-fr) | Simulation | 801 × 413, barre Roblox 58 px | Claude (MCP) | Parcours complet exécuté |
| Studio, émulateur tablette | Simulation | 1179 × 819 (T5.1) | — | OK (antérieur, T5.1) ; non refait |
| Studio, PC | Simulation | 990 × 512 ; 1920 × 1080 à l'échelle (T5.1) | — | OK (antérieur, T5.1) ; non refait |
| Téléphone Android réel | Matériel | Non communiqué | Propriétaire | **Validé** — checklist R1–R10 validé par le propriétaire (déclaration « test validé », 2026-11-13 ; appareil, version Android, détail ligne par ligne et version du place testée non communiqués) |
| Tablette réelle | Matériel | — | — | Non testée (non mentionnée) ; émulateur OK en T5.1 |
| PC Roblox Player (hors Studio) | Matériel | Non communiqué | Propriétaire | **Validé** (P1, même déclaration) |
| Manette physique | Matériel | — | — | **Reporté** (aucune manette, comme E8, U10) |

## Fonctions × plateformes

| Fonction | Émulateur téléphone (T5.5) | Tablette | PC | Téléphone réel | Manette |
|---|---|---|---|---|---|
| HUD sac / Coins / détail | OK | OK (antérieur) | OK (antérieur) | OK (antérieur, T5.1) | — |
| Collecte (demandes réelles) | OK, 79 `SUCCESS` | — | OK (antérieur, touche E) | OK (antérieur) | Reporté (X) |
| Sac plein → refus | OK, `INVENTORY_FULL` ×3 | — | — | À faire | — |
| Vente | OK, touche F réelle, +67 et +35 | — | OK (F) | OK (antérieur, prompt) | Reporté (Y) |
| Boutique : ouvrir / fermer | OK, B ; X : limite de l'outil | — | OK (antérieur) | OK (antérieur, X tactile) | Reporté (croix haut, B) |
| Achat amélioration + effet | OK, clic réel, sac 50 → 75 | — | OK (antérieur) | OK (antérieur, U9b) | Reporté |
| Guidage nouveau joueur | OK, 1/3 → 2/3 → 3/3 → fin | — | OK (antérieur, T5.3) | **À faire** (compte neuf) | Reporté |
| Joueur avancé : pas de guidage | Couvert par Lune + T5.3 | — | OK (antérieur) | OK (console : `COMPLETED`, 2026-11-13) | — |
| Sons et effets | OK (compteurs) | — | OK (antérieur) | OK (antérieur, T5.2) | — |
| Son coupé / effets réduits | OK (antérieur, T5.2) | — | OK (antérieur) | OK (antérieur, T5.2) | — |
| Textes FR | OK | — | OK | À faire (T5.4 L1–L4) | — |
| Textes EN | Lune seulement | — | — | À faire (L5) | — |
| Réapparition du personnage | OK, aucune GUI dupliquée | — | — | — | — |
| Performance | Studio : 60 FPS physique, 405 Mo client (PC, non représentatif) | — | — | **À faire** (15 min) | — |

## Checklist du propriétaire (téléphone réel en paysage)

Place de test : **version 56** sauvegardée le 2026-11-13 avec le code
actuel (correction T55-01 incluse). **À publier par le propriétaire**
avant les tests (la version publiée 53 ne contient pas T55-01).

Compte : un **compte secondaire neuf** sur l'expérience de test. Ne pas
réinitialiser le profil du compte principal.

| # | Action | Attendu | Résultat |
|---|---|---|---|
| R1 | Rejoindre en compte neuf | Accueil ≈ 5 s, puis « Étape 1/3 », consigne tactile | |
| R2 | Toucher une ressource ; maintenir Prendre | Son + éclat, `+1`, étape 2/3 | |
| R3 | Remplir jusqu'à 40 puis 50 | Signal discret à 40 ; « Sac plein ! », son de refus non fatigant | |
| R4 | Aller au stand, toucher Vendre | Son de pièces, pièces vers le solde, toast = Coins crédités | |
| R5 | Toucher Boutique, acheter Sac à dos, fermer (X) | « Sac 50 → 75 », sac `x / 75`, guidage terminé | |
| R6 | Vérifier stick, saut, Prendre, Boutique, prompt, carte du guidage | Aucun chevauchement ni élément coupé | |
| R7 | Paramètres : Son désactivé, puis Effets réduits | Aucun son ; moins d'effets | |
| R8 | Quitter, revenir | Guidage absent ; Coins et niveau conservés | |
| R9 | Session de 15 min | Pas de ralentissement perceptible ; noter la mémoire au début et à la fin (console développeur : `/console`, onglet Memory) ; FPS seulement si l'appareil l'affiche | |
| R10 | Compte en anglais (si possible) | Interface entièrement en anglais | |
| P1 | PC Roblox Player, fenêtre puis plein écran | E, F, B, clic ; rien de coupé au redimensionnement | |

Transmettre pour chaque ligne : OK / KO, modèle et version Android, et
une capture en cas de KO.
