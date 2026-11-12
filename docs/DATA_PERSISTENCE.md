# GRAB & GROW — Persistance des profils joueurs

Dernière mise à jour : 2026-11-11 (T1)

Références : architecture technique section 7 ; décisions D-006, D-008,
D-009. Réglages : `Shared/Config/DataConfig.lua`.

## Modules

| Module | Rôle |
|---|---|
| `Shared/Config/DataConfig.lua` | Version du schéma, noms de DataStore, reprises, verrou, sauvegarde auto |
| `Systems/DataSchema.lua` | Profil par défaut, contrôle d'intégrité, migrations (logique pure) |
| `Services/PlayerDataService.lua` | Chargement, données en mémoire, sauvegarde, verrou de session |
| `Systems/MemoryDataStore.lua` | Magasin en mémoire (tests, Studio) |
| `Systems/PlayerSession.lua` | Branchement Roblox : PlayerAdded, PlayerRemoving, sauvegarde auto, BindToClose |
| `Bootstrap.server.lua` | Choix du magasin, création du service |

## Stockage

- DataStore : `GrabAndGrow_PlayerData_v1` (production).
- Clé : `Player_<UserId>`.
- Valeur : `{ profile = <profil v1>, session = { id, expiresAt } | nil }`.
  Les autres champs de premier niveau éventuels sont conservés.
- Copies de récupération (D-008) : même DataStore, clé
  `Recovery_<UserId>_<heure Unix du chargement>`, jamais écrasées ni
  supprimées automatiquement.
- Toute lecture et écriture passe par `UpdateAsync` (opération atomique).
- `UserId` associé à la clé (paramètre `userIds`), pour les demandes
  d'effacement.

## API de `PlayerDataService`

Le service est créé par `PlayerDataService.new(dépendances)` et identifie
les joueurs par `UserId`. Chaque fonction retourne
`{ ok, code?, message? }`, sauf `IsLoaded` et `GetData`.

| Fonction | Effet |
|---|---|
| `LoadPlayer(userId)` | Prend le verrou et charge le profil. Bloquant. |
| `IsLoaded(userId)` | `true` seulement si le profil est utilisable. |
| `GetData(userId)` | **Copie** du profil, ou `nil`. Modifier la copie est sans effet. |
| `Update(userId, mutator)` | Seule voie de modification (voir ci-dessous). |
| `SavePlayer(userId)` | Écrit le profil et renouvelle le verrou. |
| `ReleasePlayer(userId)` | Sauvegarde finale, libère le verrou, vide la mémoire. |
| `Shutdown()` | Libère tous les profils, refuse tout nouveau chargement. |

### Modifier un profil (futurs services)

```lua
local result = playerData.Update(userId, function(draft)
    if draft.currencies.coins < cost then
        return false -- abandon : rien ne change
    end
    draft.currencies.coins -= cost
    draft.upgrades.backpackLevel += 1
end)
```

- `mutator` reçoit un brouillon (copie). Le brouillon ne remplace le
  profil que s'il respecte le schéma, sans aucune réparation : tout ou rien.
- Une erreur, un retour `false`, une valeur invalide ou une suspension du
  fil (`task.wait`, appel réseau) annulent la modification.
- `Update` ne déclenche aucune écriture DataStore.
- Coût : une copie et un contrôle du profil par appel. À mesurer en T6.
- Premier utilisateur : `InventoryService.AddResource` (T2, `COLLECTION.md`).
- Vente : `SellService` (T3, `SELLING.md`) retire, crédite et met à jour
  les statistiques dans un seul appel. Aucun changement de schéma en T3.

## Chargement

1. `UpdateAsync` lit la valeur et, dans la même opération, pose le verrou.
2. Clé absente (lue sans erreur) : profil par défaut créé.
3. Valeur présente : migration vers la version courante, puis contrôle.
4. Erreur DataStore : jusqu'à 5 tentatives, attentes de 1, 2, 4, 8 s.
5. Échec définitif, données refusées ou verrou actif : rien n'est écrit,
   aucun profil n'existe en mémoire, le joueur est expulsé avec un message.
   Un échec n'est jamais traité comme un nouveau joueur.

### Intégrité (D-008)

| Constat au chargement | Traitement |
|---|---|
| Champ ou section manquant | Valeur par défaut ajoutée, journalisée |
| Niveau hors bornes, solde négatif, décimale | Borné ou arrondi, journalisé |
| Monde de départ verrouillé | Débloqué, journalisé |
| Clé inconnue (y compris ressource absente de `ResourceConfig`) | Conservée |
| Type incorrect, NaN, section non table, verrou illisible | **Refus** `CorruptData` |
| `schemaVersion` supérieur à celui du serveur | **Refus** `UnsupportedVersion` |
| Migration absente ou en erreur | **Refus** `MigrationFailed` |

Un profil refusé reste intact dans le DataStore : correction manuelle
nécessaire. Bornes des niveaux : `UpgradeConfig` pour les cinq améliorations
(`startLevel` à `startLevel + #levels − 1`, D-015).

### Profil normalisé : copie avant réécriture (D-008, décision définitive)

Un profil est « normalisé » s'il a demandé au moins une correction ci-dessus
ou s'il a été migré.

1. **Chargement** : les corrections sont faites en mémoire uniquement. Le
   DataStore ne reçoit que le verrou ; `profile` reste l'original.
   Journal : `profil normalisé en mémoire uniquement ; original conservé`.
2. **Première sauvegarde** (auto, sortie ou fermeture) : écriture d'abord de
   la copie `Recovery_<UserId>_<heure>` :

   ```lua
   {
       kind = "PreNormalizationBackup",
       userId = 123,
       sourceKey = "Player_123",
       capturedAt = 1793000000,      -- heure Unix du chargement
       serverSchemaVersion = 1,
       repairs = { "upgrades.backpackLevel : 999 -> 16", ... },
       originalProfile = { ... },    -- profil stocké, tel quel
   }
   ```

   Puis, seulement si la copie est confirmée, écriture du profil normalisé.
   Journal : `copie de récupération écrite : Recovery_...`.
3. **Copie impossible** (erreur DataStore après les reprises, ou clé déjà
   occupée par un autre contenu) : sauvegarde refusée, code
   `BackupFailed`, journal `sauvegarde bloquée, copie de récupération
   impossible (D-008)`. Les données restent en mémoire ; la sauvegarde
   suivante réessaie. À la sortie du joueur : verrou libéré sans toucher
   au profil, modifications de la session perdues, original intact.
4. La copie n'est écrite qu'une fois par session.

**Récupération manuelle** : lire la clé `Recovery_...` (Creator Hub,
Data Stores Manager, ou Open Cloud) et réécrire `originalProfile` dans
`Player_<UserId>.profile`, joueur déconnecté et verrou absent ou expiré.

Les migrations explicites suivront une procédure dédiée, à définir avec
la première migration réelle. D'ici là, une migration déclenche la même
copie.

## Sauvegarde

- Périodique : toutes les 60 s par joueur chargé. Écrit toujours, car
  l'écriture renouvelle le verrou.
- À la sortie du joueur (`ReleasePlayer`) et à l'arrêt du serveur
  (`BindToClose` → `Shutdown`, profils traités en parallèle).
- Jamais à chaque modification.
- Une seule écriture à la fois par profil. Une demande reçue pendant une
  écriture provoque une seconde écriture à la suite, qui contient les
  modifications faites entre-temps.
- Échec après toutes les reprises : les données restent en mémoire, la
  sauvegarde suivante réessaie.
- `lastSaveAt` (heure Unix) est fixé à chaque écriture.

## Verrou de session

- Identifiant : `<JobId>:<numéro de chargement>`, unique par chargement.
- Validité : 180 s après la dernière écriture ; renouvelé à chaque
  sauvegarde (60 s).
- Verrou actif d'une autre session : le chargement attend (6 tentatives
  espacées de 5 s), puis refuse `SessionLocked`. Le verrou n'est jamais
  remplacé tant qu'il est valide.
- Verrou expiré : le nouveau serveur le reprend et lit la dernière
  sauvegarde.
- Chaque écriture vérifie que le verrou stocké est le sien. Sinon : aucune
  écriture, code `LockLost`, profil retiré de l'usage, joueur expulsé.
- La libération retire le verrou dans la même écriture que la sauvegarde
  finale. Une session ne peut pas retirer le verrou d'une autre.

## Migrations

`DataSchema.Migrations[n]` transforme un profil de version `n` en version
`n + 1` et fixe son `schemaVersion`. Table vide en v1. Pour passer en v2 :

1. Augmenter `DataConfig.SchemaVersion`.
2. Ajouter `Migrations[1]`.
3. Mettre à jour `newProfile` et le contrôle dans `DataSchema`.
4. Ajouter des tests sur des profils v1 représentatifs.
5. Noter le changement ici.

Attention : après publication d'une v2, un retour à un serveur v1 refuse
les profils déjà migrés (`UnsupportedVersion`). Prévoir le retour arrière
avant toute hausse de version.

## Environnements

| Contexte | Magasin |
|---|---|
| Serveur publié | DataStore `GrabAndGrow_PlayerData_v1` |
| Studio, `DataConfig.Studio.useMemoryStore = true` (défaut) | Mémoire, perdu à l'arrêt |
| Studio, `useMemoryStore = false` | DataStore `GrabAndGrow_PlayerData_v1_Studio` |
| Tests automatisés | `MemoryDataStore` injecté |

Le magasin en mémoire exige `RunService:IsStudio()` **et** le réglage :
il ne peut pas s'activer sur un serveur publié. Studio n'écrit jamais dans
le DataStore de production.

## Limites connues

- **Crash serveur ou coupure brutale** : les modifications depuis la
  dernière sauvegarde réussie sont perdues (jusqu'à 60 s, davantage si les
  sauvegardes échouaient). Le verrou reste posé : le joueur ne peut pas
  recharger son profil avant son expiration (jusqu'à 180 s).
- **Arrêt du serveur** : Roblox accorde environ 30 s à `BindToClose`. Un
  DataStore très lent peut empêcher certaines sauvegardes finales.
- **Sauvegarde de sortie en échec** : la progression depuis la dernière
  sauvegarde réussie est perdue, le verrou expire seul.
- **Serveur figé plus de 180 s puis réveillé** : un autre serveur a pu
  reprendre le profil ; la session figée perd ses modifications non
  sauvegardées (elle ne peut plus écrire).
- **Horloges** : l'expiration compare `os.time()` de serveurs différents ;
  un écart de quelques secondes est sans effet face aux 180 s.
- **Panne DataStore prolongée** : les joueurs sont refusés à l'entrée.
- **Profil corrompu** : le joueur est bloqué jusqu'à correction manuelle.
- **Copie de récupération impossible** : les profils normalisés concernés
  ne sont plus sauvegardés ; leur session est perdue à la sortie (jamais
  l'original).
- **Copies `Recovery_`** : jamais purgées automatiquement ; volume à
  surveiller.
- **Quotas** : une écriture par joueur et par minute, plus chargement et
  sortie. Non mesuré sur un serveur réel.
- **Messages d'expulsion** : texte anglais brut, non localisé.
- **`stats.playTimeSeconds`** : présent dans le schéma, alimenté par aucun
  système pour l'instant.
- **Magasin en mémoire** : ne reproduit ni quotas, ni latence, ni limite
  de taille du DataStore réel.

## État de validation

| Élément | Magasin en mémoire (Lune, Studio) | DataStore réel |
|---|---|---|
| Chargement, nouveau profil | Validé | Validé (V-03) |
| Sauvegarde automatique 60 s | Validé par simulation | Validé (V-01) |
| Sauvegarde à l'arrêt (`BindToClose`) | Validé par simulation | Validé (V-02) |
| Sauvegarde de sortie seule (`PlayerRemoving`, serveur qui continue) | Validé par simulation | **Non isolée** |
| Verrou actif refusé, expiration après crash | Validé par simulation | Validé (V-05) |
| Deux serveurs actifs simultanément | Validé par simulation | **Non vérifié** (Studio : une session par place) |
| Copie de récupération D-008 | Validé par simulation | **Non vérifié** |

Suivi détaillé : `PROJECT_STATUS.md`, V-01 à V-05.

## Protocole V-01 à V-05 (DataStore réel)

Environnement : une **expérience de test dédiée**, jamais celle du jeu
publié. Les DataStores sont propres à chaque expérience : celle de test ne
partage aucune donnée avec la production. Depuis Studio, le service écrit
dans `GrabAndGrow_PlayerData_v1_Studio`.

Preuves : journal Studio (`%LOCALAPPDATA%\Roblox\logs`, lignes
`[Bootstrap]` et `[PlayerData]`). Les valeurs `lastSaveAt` et l'identifiant
du verrou affichés au chargement sont lus dans le DataStore réel : ce sont
les données de test.

### Préparation

1. Studio, `GrabAndGrow.rbxl` ouvert : File > Publish to Roblox As >
   **nouvelle expérience** (nom suggéré : « GrabAndGrow TEST »), privée.
2. Game Settings > Security > **Enable Studio Access to API Services**.
3. `DataConfig.Studio.useMemoryStore = false` (synchronisé par Rojo).
4. Vérifier au Play : `[Bootstrap] DataStore : GrabAndGrow_PlayerData_v1_Studio`.

### Étapes et critères

| Étape | Action | Preuve attendue dans le journal | Valide |
|---|---|---|---|
| E1 | Play, rester **au moins 70 s**, puis Stop | `DataStore : ..._Studio` ; `nouveau profil créé` ou `profil chargé` ; `sauvegarde (auto) OK, lastSaveAt=A` ; `sauvegarde (sortie) OK, lastSaveAt=B` ou `(fermeture serveur)` | V-03, V-01 (écriture) |
| E2 | Play | `profil chargé, lastSaveAt=B, verrou précédent : aucun` | V-02 |
| E3 | Rester au moins 70 s, noter `sauvegarde (auto) OK, lastSaveAt=C`, puis **arrêt forcé de Studio** (processus tué, aucune sauvegarde de sortie) | Pas de ligne `sauvegarde (sortie)` après C | préparation V-05 |
| E4 | Rouvrir Studio et Play **moins de 150 s** après C | `verrou actif ... expire dans N s ; nouvelle tentative` (5 fois), puis `chargement refusé (SessionLocked)` ; joueur expulsé | V-05 (verrou respecté), V-04 partiel |
| E5 | Play **plus de 180 s** après C | `profil chargé, lastSaveAt=C, verrou précédent : studio-... (expiré depuis N s)` | V-05 (reprise), V-01 (persistance sans sortie) |
| E6 (V-04) | Deux fenêtres Studio sur l'expérience de test, Play dans la première puis dans la seconde | Seconde fenêtre : `verrou actif` puis refus ; première fenêtre : sauvegardes auto toujours `OK`, aucune `verrou perdu` | V-04 |
| Fin | Remettre `useMemoryStore = true` | — | — |

E6 est impossible : Studio refuse deux sessions sur le même place
(`RCC-276`) et ferme l'ancienne. Constaté le 2026-11-11 ; dans ce cas, V-04 n'est couvert que par E4 (verrou d'un serveur
arrêté) et par la simulation, et reste noté « partiel ».
