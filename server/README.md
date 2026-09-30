# PixelFocus API

Petite API PHP + MySQL, sans framework ni dépendance, pensée pour un hébergement mutualisé (o2switch).

- **PHP 8.1 minimum** (extensions : `pdo_mysql`, `mbstring`, `openssl`)
- **MySQL 5.7+ ou MariaDB 10.2+**
- Aucune plateforme tierce : les seuls services externes seront Apple et Google (validation des achats).

## Principe

- **Compte anonyme** créé automatiquement au premier lancement de l'app ; le jeton reste dans le trousseau (iOS) ou le Keystore (Android).
- **Historique d'événements** = source de vérité (session terminée, booster utilisé, badge…). Chaque événement a un UUID généré par l'app : un renvoi ne crée jamais de doublon, plusieurs appareils ne se contredisent pas.
- **Hors ligne d'abord** : l'app fonctionne sans réseau et envoie ses événements dès qu'elle peut.

## Routes (v1)

| Méthode | Route | Rôle |
|---|---|---|
| GET | `/v1/health` | Vérifie que l'API et la base répondent |
| POST | `/v1/auth/anonymous` | Crée un compte anonyme → `{userId, token, firstLaunchAt}` |
| POST | `/v1/events` | Envoie un lot d'événements (idempotent) |
| GET | `/v1/state?since=<curseur>` | Profil, achats et événements reçus après le curseur |
| DELETE | `/v1/account` | Supprime le compte et toutes ses données (obligatoire sur l'App Store) |
| POST | `/v1/auth/link/apple` · `/v1/auth/link/google` | *Prévu* : rattacher un compte Apple / Google |
| POST | `/v1/purchases/apple` · `/v1/purchases/google` | *Prévu* : valider un achat |
| POST | `/v1/webhooks/apple` · `/v1/webhooks/google` | *Prévu* : notifications des stores (renouvellements, remboursements) |

Authentification : en-tête `Authorization: Bearer <token>` (sauf `health` et `auth/anonymous`).

### Exemple : envoyer des événements

```json
POST /v1/events
{
  "events": [
    {
      "id": "9b2f6a3e-8f1d-4c1e-9a52-2d6f7c1b0e11",
      "type": "session_completed",
      "artworkId": "daily_2026_09_30",
      "payload": { "minutes": 25, "extraMinutesOver30": 0 },
      "occurredAt": "2026-09-30T10:00:00+02:00"
    }
  ]
}
```

Réponse : `{"accepted": [...], "duplicates": [...], "rejected": [{"id": ..., "reason": ...}]}`

Types acceptés : `session_completed`, `booster_used`, `booster_earned`, `protection_token_earned`, `protection_token_used`, `badge_unlocked`, `monthly_unlocked`.

## Structure

```
server/
├── public/            ← racine web du sous-domaine (index.php + .htaccess)
├── src/               ← code de l'API
├── config/            ← config.example.php (config.php non versionné)
├── sql/               ← migrations SQL, appliquées dans l'ordre
├── bin/migrate.php    ← applique les migrations
└── tests/             ← tests d'intégration (run.sh)
```

## Déploiement sur o2switch

1. **Sous-domaine** — cPanel › *Domaines* : créer `api.tondomaine.fr` avec comme racine `pixelfocus-api/public`.
2. **Fichiers** — envoyer le dossier `server/` dans `~/pixelfocus-api/` (Gestionnaire de fichiers, FTP, ou `git` en SSH).
3. **Base** — cPanel › *Bases de données MySQL* : créer une base (ex. `moncompte_pixelfocus`), un utilisateur, et lui donner *tous les privilèges* sur la base.
4. **Configuration** — copier `config/config.example.php` en `config/config.php` et renseigner la base.
5. **Tables** — en SSH : `cd ~/pixelfocus-api && php bin/migrate.php`
   (sans SSH : importer `sql/001_schema.sql` dans phpMyAdmin).
6. **PHP** — cPanel › *Sélecteur de version PHP* : choisir PHP 8.1 ou plus récent.
7. **HTTPS** — cPanel › *SSL/TLS Status* : vérifier que le certificat du sous-domaine est actif (AutoSSL).
8. **Vérifier** — ouvrir `https://api.tondomaine.fr/v1/health` → `{"ok":true,...}`

Sauvegardes : o2switch sauvegarde automatiquement fichiers et bases (JetBackup). Pense à tester une restauration de temps en temps.

## Tests

```bash
# Base de test vide (elle est réinitialisée par le script)
DB_HOST=127.0.0.1 DB_NAME=pixelfocus_test DB_USER=pf DB_PASSWORD=pf ./tests/run.sh
```

## Sécurité

- Seul le hash SHA-256 des jetons est stocké.
- Requêtes SQL préparées uniquement.
- `config/config.php` n'est jamais versionné et n'est pas dans le dossier public.
- En production (`env = production`), les erreurs ne sont jamais détaillées dans les réponses (voir le journal d'erreurs PHP dans cPanel).
