# Plan de publication — GRAB & GROW

Version : T9 (2026-11-16). **Document de préparation : aucune étape n'est
autorisée par ce document.** Chaque publication, changement de visibilité
ou modification de l'expérience demande l'accord explicite du propriétaire.

## 1. Environnements

| Environnement | Rôle | DataStore |
|---|---|---|
| Studio | Développement, tests automatisés | Mémoire (`useMemoryStore`) ou `_Studio` |
| Expérience de test (place 93404872714886) | Tests privés, vérification analytics | Test (jamais la production) |
| Expérience de production « GRAB & GROW » (univers 10778642065, place de départ 114057331912339, créée le 2026-11-23, privée) | Test fermé puis public | Production, vierge au lancement |

Règle : aucun test destructif ni essai de transaction sur la production.

## 2. Checklist avant publication

- [x] T9 et T10 validées par le propriétaire (D-039).
- [x] Version candidate : `main` `6e63de6`, scripts du place identiques (2026-11-23).
- [ ] Tous les tests automatisés OK (Lune, luau-lsp strict, Rojo build).
- [ ] Studio solo et Local Server à 2 joueurs OK sur la version à publier.
- [ ] Événements analytics vus dans « View Events » de l'expérience de test.
- [ ] Checklist `PUBLICATION_READINESS_CHECKLIST.md` sans BLOCKED.
- [ ] Version du place notée (numéro de version Roblox) et commit Git
      correspondant identifié.
- [ ] `GrabAndGrow.rbxl` local non modifié par la publication.

## 3. Scénarios de validation (version candidate)

1. Nouveau joueur : arrivée, guidage 1/3 → 3/3, première vente, première
   amélioration.
2. Joueur existant : reconnexion, inventaire et Coins restaurés.
3. Quatre mondes : déblocage, voyage aller-retour, collecte et vente dans
   chaque monde.
4. Journal : découvertes, aucune récompense.
5. Deux joueurs sur le même serveur : ventes simultanées, inventaires
   indépendants.
6. Mobile réel portrait et paysage ; PC ; tablette si disponible.
7. Analytics : onboarding, économie, progression, custom dans « View
   Events », sans doublon.

## 4. Test fermé

- Accès : expérience privée, testeurs invités (Roblox autorise jusqu'à 10
  testeurs anticipés) ou membres du groupe.
- Durée proposée : 1 à 2 semaines (hypothèse).
- Collecte : analytics Roblox (KPI A à D) et retours écrits des testeurs.
- Pas d'équilibrage sur un échantillon trop faible : relever, ne pas
  conclure.

## 5. Critères de sortie du test fermé (proposés, à valider)

- Aucun incident de perte ou de duplication de données.
- Aucune erreur serveur récurrente dans les journaux.
- Funnel d'onboarding mesuré de bout en bout (étapes 1 à 4 reçues).
- Événements économiques cohérents avec les soldes (pas de solde négatif,
  pas de doublon).
- Retours mobiles sans problème bloquant de lisibilité ou de contrôle.

## 6. Suivi des premières données

| Moment | Lecture |
|---|---|
| J0 | « View Events » : noms, valeurs, SKU ; débit (`dropped` absent des journaux) |
| J1–J2 | Graphiques Economy, Funnel, Custom |
| J7 | D1, sessions, durée ; première lecture du funnel |
| Fin du test | Relevé complet `ANALYTICS_KPI_FRAMEWORK.md` |

## 7. Procédure de retour arrière

1. Creator Dashboard > place > Version History : republier la dernière
   version validée (propriétaire).
2. Si le défaut touche les données : rendre l'expérience privée, ne pas
   écrire de correctif de données sans test sur DataStore de test.
3. Les profils restent compatibles : le schéma v3 n'est pas modifié par T9 ;
   un serveur plus ancien refuse un profil de version future sans l'écraser
   (`UnsupportedVersion`).
4. Analytics défaillant : `AnalyticsConfig.enabled = false` puis
   republication ; le jeu est identique.

## 8. Gestion des incidents

| Gravité | Exemple | Réaction |
|---|---|---|
| P0 | Perte ou duplication de progression, exploit économique | Expérience privée, retour arrière, analyse des journaux `[Security]`, `[Sell]`, `[Upgrade]` |
| P1 | Monde ou vente inutilisable, erreur serveur fréquente | Retour arrière ou correctif testé, republication |
| P2 | Défaut visuel, texte, analytics manquant | Correctif dans le lot suivant |

Pour chaque incident : date, version, symptôme, cause, correction, test
ajouté. Consigner dans `docs/` (rapport de phase ou décision).

## 9. Procédure de mise en production (propriétaire)

Préparée le 2026-11-23. Chaque étape est une action du propriétaire ;
l'agent ne publie rien et ne change aucun réglage.

1. **Synchroniser** : ouvrir le place de test, reconnecter Rojo sur `main`,
   puis comparer `lune run tools/repo_script_hashes.luau` avec
   `tools/studio/place_script_hashes.luau` (mode Edit). Les deux listes
   doivent être identiques.
2. **Enregistrer** le place de test et noter son numéro de version.
3. **Créer l'expérience de production** : File > Publish to Roblox As…
   > *New experience*, nom « GRAB & GROW ». Ne jamais publier par-dessus
   l'expérience de test. Le DataStore de production est alors vierge
   (les DataStores sont propres à chaque expérience).
4. Dans la nouvelle expérience : **laisser privée**, activer « Enable Studio
   Access to API Services » seulement si un test Studio sur ce DataStore
   est prévu (sinon le laisser désactivé), appareils : téléphone,
   tablette, ordinateur.
5. Renseigner nom, descriptions EN/FR (`STORE_PAGE_DRAFT.md` §2), icône et
   miniatures validées, puis le questionnaire de classification.
6. **Test fermé** (§4) sur cette expérience privée : scénarios §3, dont
   Galaxy A23 et recul des gardiens avec latence réelle.
7. Après les critères §5 seulement : changer la visibilité en public
   (autorisation explicite requise). Noter version, date et commit dans
   `PROJECT_STATUS.md`.

