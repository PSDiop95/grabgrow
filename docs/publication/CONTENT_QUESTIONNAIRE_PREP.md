# Questionnaire de classification — fiche de préparation

Date : 2026-11-23. **Aide à la réponse, pas une réponse.** Le questionnaire
(Creator Dashboard > GRAB & GROW > Gérer l'audience > « Remplissez le
questionnaire sur la classification du contenu ») engage le titulaire du
compte : il le remplit lui-même, en relisant chaque question telle que
Roblox la formule le jour J. Cette fiche décrit seulement ce que le jeu
contient, d'après le code de `main` (`6e63de6`) et le GDD.

## Contenu du jeu, par thème

| Thème | Ce que contient GRAB & GROW | Source |
|---|---|---|
| Violence | Combats contre des gardiens (golems de primitives). Le joueur touche des éclats lumineux, pas le gardien. Une attaque du gardien repousse le joueur et l'étourdit 1,5 s. Ni mort, ni perte, ni arme, ni PvP, ni sang. | `GuardianConfig`, D-034, D-040 |
| Sang, gore | Aucun. | — |
| Peur, horreur | Aucune. Gardiens en blocs colorés, ambiance claire. | Captures `docs/publication/images/` |
| Langage grossier | Aucun texte de ce type (textes EN/FR dans `Localization`). | `Localization.lua` |
| Humour cru | Aucun. | — |
| Romance, contenu sexuel | Aucun. | — |
| Alcool, drogues, tabac | Aucun. | — |
| Jeux d'argent, hasard payant | Aucun achat (aucun `MarketplaceService` d'achat dans le code), aucune loterie ni œuf. Le hasard sert seulement aux positions et attaques des gardiens et aux effets sonores. | `Bootstrap`, `FeedbackController` |
| Communication | Aucun chat ni système social ajouté par le jeu ; réglages Roblox par défaut. | Checklist D |
| Contenu créé par les joueurs | Aucun (pas de construction, pas de texte libre). | — |
| Thèmes sensibles (politique, religion, etc.) | Aucun. Les « sanctuaires sacrés » sont des lieux de fantaisie, sans religion réelle. | GDD |
| Achats / monétisation | Aucun Game Pass, aucun Developer Product. | Checklist E |

## Résultat

Obtenu le 2026-11-23 : **Minimal**, 16+, aucun descripteur. L'âge 16+
vient de l'audience par défaut, pas du contenu ; descendre sous 16 ans
demande le parcours Kids & Select.

### Résultat attendu (hypothèse initiale)

D'après les critères Roblox connus (à revérifier le jour J), un jeu sans
sang, avec une violence légère et irréaliste, devrait obtenir la note la
plus basse (« Minimal »). Ce n'est **pas garanti** : la note dépend des
réponses exactes du propriétaire et de l'appréciation de Roblox.

## Genre (« Infos sur le jeu »)

- Suggestion : **Simulation** (boucle collecter, vendre, améliorer). Le
  sous-genre reste au choix du propriétaire.
- Le genre ne peut être changé que tous les 3 mois.

## Autres étapes de « Gérer l'audience » (propriétaire uniquement)

| Étape | Statut au 2026-11-23 | Remarque |
|---|---|---|
| Améliorer les infos sur le jeu | Incomplet | Probablement le genre (nom, descriptions, icône, miniatures saisis) |
| Vérification d'identité | Incomplet | Pièce d'identité, compte du propriétaire |
| Vérification en deux étapes | Incomplet | Réglage de sécurité du compte |
| Questionnaire de classification | Fait | Maturité « Minimal », âge minimum 16+, aucun descripteur de contenu (API Roblox, lu le 2026-11-23) |
| 100 joueurs très engagés | 0 | Pour les moins de 16 ans |
| Frais Kids & Select (1 000 Robux, remboursables) | Incomplet | Décision et paiement du propriétaire |
