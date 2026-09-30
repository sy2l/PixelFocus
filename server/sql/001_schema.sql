-- PixelFocus API — schéma initial (MySQL 5.7+ / MariaDB 10.2+)
-- Toutes les dates sont en UTC.
--
-- Principe: l'historique d'événements (events) est la source de vérité.
-- Progression, série, badges et stock de boosters se recalculent à partir des événements.
-- Chaque événement a un identifiant (UUID) généré par l'app: renvoyer deux fois le même
-- événement ne crée pas de doublon (synchronisation multi-appareils sans conflit).

CREATE TABLE IF NOT EXISTS users (
    id              CHAR(36)     NOT NULL,
    created_at      DATETIME(3)  NOT NULL,
    -- Premier lancement de l'app (image du mois offerte)
    first_launch_at DATETIME(3)  NOT NULL,
    -- Rattachements optionnels (étape suivante)
    apple_sub       VARCHAR(255) NULL,
    google_sub      VARCHAR(255) NULL,
    last_seen_at    DATETIME(3)  NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_users_apple_sub (apple_sub),
    UNIQUE KEY uq_users_google_sub (google_sub)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS auth_tokens (
    -- SHA-256 du jeton (le jeton en clair n'est jamais stocké)
    token_hash   CHAR(64)    NOT NULL,
    user_id      CHAR(36)    NOT NULL,
    platform     VARCHAR(20) NOT NULL,
    device_name  VARCHAR(100) NULL,
    created_at   DATETIME(3) NOT NULL,
    last_seen_at DATETIME(3) NULL,
    PRIMARY KEY (token_hash),
    KEY idx_auth_tokens_user (user_id),
    CONSTRAINT fk_auth_tokens_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS events (
    -- Curseur de synchronisation (ordre de réception)
    seq         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    -- UUID généré par l'app (idempotence)
    id          CHAR(36)     NOT NULL,
    user_id     CHAR(36)     NOT NULL,
    type        VARCHAR(40)  NOT NULL,
    artwork_id  VARCHAR(80)  NULL,
    payload     TEXT         NULL,
    occurred_at DATETIME(3)  NOT NULL,
    received_at DATETIME(3)  NOT NULL,
    PRIMARY KEY (seq),
    UNIQUE KEY uq_events_id (id),
    KEY idx_events_user_seq (user_id, seq),
    CONSTRAINT fk_events_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS purchases (
    id                      BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    user_id                 CHAR(36)     NOT NULL,
    store                   VARCHAR(10)  NOT NULL, -- 'apple' | 'google'
    product_id              VARCHAR(100) NOT NULL,
    transaction_id          VARCHAR(100) NOT NULL,
    original_transaction_id VARCHAR(100) NULL,
    purchased_at            DATETIME(3)  NOT NULL,
    expires_at              DATETIME(3)  NULL,     -- abonnements
    revoked_at              DATETIME(3)  NULL,     -- remboursement / révocation
    raw                     TEXT         NULL,     -- preuve d'achat signée (audit)
    created_at              DATETIME(3)  NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_purchases_store_tx (store, transaction_id),
    KEY idx_purchases_user (user_id),
    CONSTRAINT fk_purchases_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS schema_migrations (
    version    VARCHAR(50) NOT NULL,
    applied_at DATETIME    NOT NULL,
    PRIMARY KEY (version)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
