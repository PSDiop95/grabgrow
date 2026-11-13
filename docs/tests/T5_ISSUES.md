# T5.5 — Anomalies

Date : 2026-11-13. Classification : P0 critique, P1 majeur, P2 modéré,
P3 mineur. Aucune P0/P1 trouvée. Une correction autorisée : T55-01.

## Ouvertes, trouvées en T5.5

| # | Gravité | Plateforme | Description | Reproduction | Attendu | Obtenu | Preuve | Proposition |
|---|---|---|---|---|---|---|---|---|
| T55-01 | P3 | Toutes | Ponctuation incohérente : le toast `sell.go_sell` finit sans « ! » alors que le HUD `hud.sell_hint` en a un | Remplir le sac, tenter une collecte | « Sac plein ! Vendez au stand ! » / « Bag full! Sell at the stand! » | « Sac plein ! Vendez au stand » (EN : « …Sell at the stand ») | Studio, `NotificationsUI` relu ; `Localization.lua` l. 36 et 136 | **Corrigé** (accord du propriétaire, 2026-11-13) : « ! » ajouté en EN et FR, texte seul. Lune 13 suites OK, luau-lsp 0 erreur, `rojo build` OK ; Studio (sync vérifiée, émulateur fr-fr) : toast « Sac plein ! Vendez au stand ! » |
| T55-02 | P3 (doc) | — | `PROJECT_STATUS.md` titre « T5.3 … PARTIEL » alors que ROADMAP et préflight indiquent « TERMINÉ » | Lecture | Statut unique | Deux statuts | Documents | **Corrigé** dans la mise à jour T5.5 : clôturé par le propriétaire, parcours nouveau joueur sur téléphone réel reporté en T5.5 |

## Points observés, non classés comme anomalies

| Constat | Raison |
|---|---|
| Consigne du guidage « Appuyez sur B ou cliquez sur Boutique » affichée sur l'émulateur tactile | Par conception : la consigne suit le dernier type d'entrée (`OnboardingRules.deviceOf`) ; les touches F et B venaient d'être utilisées. À l'étape 1 (avant toute touche), la consigne tactile s'affichait |
| Clics MCP sur « X » de la boutique sans effet | Limite de l'outil : en mode émulateur, le curseur arrive à x = 592 pour un bouton à 606–670 (fenêtre mise à l'échelle). Gestionnaire `Close.Activated → setOpen(false)` relu ; B ferme ; X validé au toucher réel en T5.1 |
| Sac plein : 1 son `bag_full` par refus espacé de plus de 1,5 s | Règle T5.2 (anti-doublon 1,5 s), validée sur téléphone réel en T5.2. À réécouter pendant la session de 15 min (fatigue sonore) |

## Anomalies antérieures toujours ouvertes (rappel)

| # | Gravité estimée | Échéance |
|---|---|---|
| A-41 (reste) | P3 | Chat ouvert sur téléphone : recouvrement réduit, pas supprimé |
| A-38 | P3 | Glyphes Unicode : OK sur un téléphone et dans Studio ; autres appareils non vérifiés |
| A-26, A-27, A-37 | Sécurité, hors T5 | T6 |
| A-19, A-36 | Équilibrage, hors T5 | T7 |
| A-10, A-12, A-14, A-18, A-20, A-21 | Documentaires / décisions | Voir `PROJECT_STATUS.md` |

Aucune P0 ni P1 connue à ce jour. Cette conclusion ne couvre pas les
appareils non testés (voir `T5_DEVICE_MATRIX.md`).
