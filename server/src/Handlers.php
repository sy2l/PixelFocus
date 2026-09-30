<?php

declare(strict_types=1);

namespace PixelFocus\Api;

/**
 * Points d'entrée de l'API v1.
 */
final class Handlers
{
    /**
     * Types d'événements acceptés et validation de leur contenu.
     * L'app reste responsable des règles du jeu; le serveur stocke un historique propre.
     */
    private const EVENT_TYPES = [
        'session_completed'       => ['artwork' => true],
        'booster_used'            => ['artwork' => true],
        'booster_earned'          => ['artwork' => false],
        'protection_token_earned' => ['artwork' => false],
        'protection_token_used'   => ['artwork' => false],
        'badge_unlocked'          => ['artwork' => false],
        'monthly_unlocked'        => ['artwork' => true],
        // Jour actif: la daily du jour terminée le jour même (série, badges). payload: {dayISO}
        'day_active'              => ['artwork' => false],
    ];

    // MARK: - Santé

    public static function health(): never
    {
        Database::pdo()->query('SELECT 1');
        Http::json(200, ['ok' => true, 'time' => Database::toIso(Database::now())]);
    }

    // MARK: - Comptes

    /** POST /v1/auth/anonymous {platform, deviceName?, firstLaunchAt?} */
    public static function createAnonymous(): never
    {
        $body = Http::body();
        $result = Auth::createAnonymous(
            (string) ($body['platform'] ?? ''),
            isset($body['deviceName']) ? (string) $body['deviceName'] : null,
            isset($body['firstLaunchAt']) ? (string) $body['firstLaunchAt'] : null
        );
        Http::json(201, $result);
    }

    /** DELETE /v1/account — supprime le compte et toutes ses données (obligation App Store) */
    public static function deleteAccount(): never
    {
        $userId = Auth::requireUserId();
        Database::pdo()->prepare('DELETE FROM users WHERE id = ?')->execute([$userId]);
        Http::json(200, ['deleted' => true]);
    }

    // MARK: - Événements

    /**
     * POST /v1/events {events: [{id, type, artworkId?, payload?, occurredAt}]}
     * Idempotent: un événement déjà reçu (même id) est ignoré.
     */
    public static function postEvents(): never
    {
        $userId = Auth::requireUserId();
        $body = Http::body();
        $events = $body['events'] ?? null;

        if (!is_array($events) || !array_is_list($events)) {
            Http::error(422, 'invalid_events', 'events doit être une liste.');
        }
        $max = (int) Config::get('max_events_per_request', 500);
        if (count($events) > $max) {
            Http::error(413, 'too_many_events', "Au plus $max événements par requête.");
        }

        $accepted = [];
        $duplicates = [];
        $rejected = [];

        $pdo = Database::pdo();
        $insert = $pdo->prepare(
            'INSERT IGNORE INTO events (id, user_id, type, artwork_id, payload, occurred_at, received_at)
             VALUES (?, ?, ?, ?, ?, ?, ?)'
        );
        $now = Database::now();

        $pdo->beginTransaction();
        foreach ($events as $event) {
            $error = self::validateEvent($event, $now);
            $id = is_array($event) && is_string($event['id'] ?? null) ? strtolower($event['id']) : null;
            if ($error !== null) {
                $rejected[] = ['id' => $id, 'reason' => $error];
                continue;
            }

            $payload = isset($event['payload']) ? json_encode($event['payload'], JSON_UNESCAPED_UNICODE) : null;
            $insert->execute([
                $id,
                $userId,
                $event['type'],
                $event['artworkId'] ?? null,
                $payload,
                Database::toUtc($event['occurredAt']),
                $now,
            ]);

            if ($insert->rowCount() === 1) {
                $accepted[] = $id;
            } else {
                $duplicates[] = $id;
            }
        }
        $pdo->commit();

        Http::json(200, [
            'accepted'   => $accepted,
            'duplicates' => $duplicates,
            'rejected'   => $rejected,
        ]);
    }

    /** Raison du refus d'un événement, ou null s'il est valide */
    private static function validateEvent(mixed $event, string $now): ?string
    {
        if (!is_array($event)) {
            return 'not_an_object';
        }
        if (!is_string($event['id'] ?? null) || !Uuid::isValid($event['id'])) {
            return 'invalid_id';
        }
        $type = $event['type'] ?? null;
        if (!is_string($type) || !isset(self::EVENT_TYPES[$type])) {
            return 'unknown_type';
        }

        $artworkId = $event['artworkId'] ?? null;
        if ($artworkId !== null && (!is_string($artworkId) || !preg_match('/^[a-z0-9_]{1,80}$/', $artworkId))) {
            return 'invalid_artwork_id';
        }
        if (self::EVENT_TYPES[$type]['artwork'] && $artworkId === null) {
            return 'missing_artwork_id';
        }

        $occurredAt = is_string($event['occurredAt'] ?? null) ? Database::toUtc($event['occurredAt']) : null;
        if ($occurredAt === null) {
            return 'invalid_occurred_at';
        }
        // Tolérance d'horloge: 24 h dans le futur au maximum
        $limit = (new \DateTimeImmutable($now, new \DateTimeZone('UTC')))->modify('+1 day')->format('Y-m-d H:i:s.v');
        if ($occurredAt > $limit || $occurredAt < '2025-01-01 00:00:00.000') {
            return 'occurred_at_out_of_range';
        }

        if (array_key_exists('payload', $event)) {
            if (!is_array($event['payload'])) {
                return 'invalid_payload';
            }
            $encoded = json_encode($event['payload']);
            if ($encoded === false || strlen($encoded) > (int) Config::get('max_payload_bytes', 4096)) {
                return 'payload_too_large';
            }
        }

        return null;
    }

    // MARK: - État

    /**
     * GET /v1/state?since=<curseur>
     * Renvoie le profil, les achats et les événements reçus après le curseur (synchronisation incrémentale).
     * Pour tout récupérer (nouvel appareil), appeler sans "since".
     */
    public static function getState(): never
    {
        $userId = Auth::requireUserId();
        $since = max(0, (int) ($_GET['since'] ?? 0));
        $limit = 1000;
        $pdo = Database::pdo();

        $user = $pdo->prepare('SELECT id, created_at, first_launch_at, apple_sub IS NOT NULL AS apple_linked, google_sub IS NOT NULL AS google_linked FROM users WHERE id = ?');
        $user->execute([$userId]);
        $userRow = $user->fetch();

        $eventsStatement = $pdo->prepare(
            'SELECT seq, id, type, artwork_id, payload, occurred_at FROM events
             WHERE user_id = ? AND seq > ? ORDER BY seq ASC LIMIT ' . ($limit + 1)
        );
        $eventsStatement->execute([$userId, $since]);
        $rows = $eventsStatement->fetchAll();

        $hasMore = count($rows) > $limit;
        $rows = array_slice($rows, 0, $limit);
        $cursor = $rows === [] ? $since : (int) end($rows)['seq'];

        $events = array_map(static fn (array $row): array => [
            'id'         => $row['id'],
            'type'       => $row['type'],
            'artworkId'  => $row['artwork_id'],
            'payload'    => $row['payload'] === null ? null : json_decode($row['payload'], true),
            'occurredAt' => Database::toIso($row['occurred_at']),
        ], $rows);

        $purchasesStatement = $pdo->prepare(
            'SELECT store, product_id, transaction_id, purchased_at, expires_at, revoked_at FROM purchases
             WHERE user_id = ? ORDER BY purchased_at ASC'
        );
        $purchasesStatement->execute([$userId]);
        $purchases = array_map(static fn (array $row): array => [
            'store'         => $row['store'],
            'productId'     => $row['product_id'],
            'transactionId' => $row['transaction_id'],
            'purchasedAt'   => Database::toIso($row['purchased_at']),
            'expiresAt'     => Database::toIso($row['expires_at']),
            'revokedAt'     => Database::toIso($row['revoked_at']),
        ], $purchasesStatement->fetchAll());

        Http::json(200, [
            'user' => [
                'id'            => $userRow['id'],
                'createdAt'     => Database::toIso($userRow['created_at']),
                'firstLaunchAt' => Database::toIso($userRow['first_launch_at']),
                'appleLinked'   => (bool) $userRow['apple_linked'],
                'googleLinked'  => (bool) $userRow['google_linked'],
            ],
            'events'     => $events,
            'cursor'     => $cursor,
            'hasMore'    => $hasMore,
            'purchases'    => $purchases,
            'entitlements' => Entitlements::forUser($userId),
            'serverTime'   => Database::toIso(Database::now()),
        ]);
    }

    // MARK: - Achats Apple

    /**
     * POST /v1/purchases/apple {transactionId}
     * Le serveur récupère la transaction auprès d'Apple (source faisant autorité), l'enregistre
     * et renvoie les droits à jour. Idempotent.
     */
    public static function postApplePurchase(): never
    {
        $userId = Auth::requireUserId();
        $transactionId = (string) (Http::body()['transactionId'] ?? '');
        if (!preg_match('/^\d{1,40}$/', $transactionId)) {
            Http::error(422, 'invalid_transaction_id', 'transactionId invalide.');
        }

        $transaction = Apple::fetchTransaction($transactionId);
        if ($transaction === null) {
            Http::error(404, 'transaction_not_found', 'Transaction inconnue chez Apple.');
        }

        $error = self::checkAppleTransaction($transaction, $userId);
        if ($error !== null) {
            Http::error($error[0], $error[1], $error[2]);
        }

        $owner = self::purchaseOwner('apple', (string) $transaction['transactionId']);
        if ($owner !== null && $owner !== $userId) {
            Http::error(409, 'owned_by_another_account', 'Cet achat appartient à un autre compte. Connecte-toi avec Apple pour le retrouver.');
        }

        self::upsertApplePurchase($userId, $transaction);
        Http::json(200, ['entitlements' => Entitlements::forUser($userId)]);
    }

    /**
     * POST /v1/webhooks/apple {signedPayload}
     * Notifications App Store Server V2 (renouvellement, expiration, remboursement…).
     * Le contenu n'est pas pris pour argent comptant: on relit la transaction auprès d'Apple.
     * Répond toujours 200 pour les notifications traitées ou ignorées (Apple réessaie sinon).
     */
    public static function appleWebhook(): never
    {
        $signedPayload = (string) (Http::body()['signedPayload'] ?? '');
        try {
            $notification = Jwt::decodeUnverified($signedPayload)['payload'];
            $signedTransaction = $notification['data']['signedTransactionInfo'] ?? null;
            if (!is_string($signedTransaction)) {
                Http::json(200, ['ignored' => 'no_transaction']);
            }
            $transactionId = (string) (Jwt::decodeUnverified($signedTransaction)['payload']['transactionId'] ?? '');
        } catch (\InvalidArgumentException) {
            Http::error(400, 'invalid_payload', 'signedPayload invalide.');
        }

        $transaction = Apple::fetchTransaction($transactionId);
        if ($transaction === null || self::checkAppleTransaction($transaction, null) !== null) {
            Http::json(200, ['ignored' => 'unknown_transaction']);
        }

        // Rattachement: même transaction ou même abonnement d'origine déjà connu
        $userId = self::purchaseOwner('apple', (string) $transaction['transactionId'])
            ?? self::purchaseOwnerByOriginal('apple', (string) ($transaction['originalTransactionId'] ?? ''))
            ?? self::userFromAppAccountToken($transaction['appAccountToken'] ?? null);
        if ($userId === null) {
            Http::json(200, ['ignored' => 'unknown_user']);
        }

        self::upsertApplePurchase($userId, $transaction);
        Http::json(200, ['ok' => true, 'type' => $notification['notificationType'] ?? null]);
    }

    /** Erreur [statut, code, message] si la transaction n'est pas acceptable, sinon null */
    private static function checkAppleTransaction(array $transaction, ?string $userId): ?array
    {
        $bundleId = Config::get('apple')['bundle_id'] ?? null;
        if (($transaction['bundleId'] ?? null) !== $bundleId) {
            return [422, 'wrong_app', "Cette transaction ne concerne pas l'app."];
        }
        if (!Products::isKnown((string) ($transaction['productId'] ?? ''))) {
            return [422, 'unknown_product', 'Produit inconnu.'];
        }
        // L'app associe chaque achat à l'identifiant du compte (appAccountToken)
        $token = $transaction['appAccountToken'] ?? null;
        if ($userId !== null && is_string($token) && $token !== '' && strtolower($token) !== strtolower($userId)) {
            return [409, 'owned_by_another_account', 'Cet achat appartient à un autre compte. Connecte-toi avec Apple pour le retrouver.'];
        }
        return null;
    }

    private static function upsertApplePurchase(string $userId, array $transaction): void
    {
        Database::pdo()->prepare(
            'INSERT INTO purchases (user_id, store, product_id, transaction_id, original_transaction_id, purchased_at, expires_at, revoked_at, raw, created_at)
             VALUES (?, \'apple\', ?, ?, ?, ?, ?, ?, ?, ?)
             ON DUPLICATE KEY UPDATE expires_at = VALUES(expires_at), revoked_at = VALUES(revoked_at), raw = VALUES(raw)'
        )->execute([
            $userId,
            (string) $transaction['productId'],
            (string) $transaction['transactionId'],
            isset($transaction['originalTransactionId']) ? (string) $transaction['originalTransactionId'] : null,
            Apple::msToUtc($transaction['purchaseDate'] ?? null) ?? Database::now(),
            Apple::msToUtc($transaction['expiresDate'] ?? null),
            Apple::msToUtc($transaction['revocationDate'] ?? null),
            json_encode($transaction, JSON_UNESCAPED_SLASHES),
            Database::now(),
        ]);
    }

    private static function purchaseOwner(string $store, string $transactionId): ?string
    {
        $statement = Database::pdo()->prepare('SELECT user_id FROM purchases WHERE store = ? AND transaction_id = ?');
        $statement->execute([$store, $transactionId]);
        $owner = $statement->fetchColumn();
        return $owner === false ? null : (string) $owner;
    }

    private static function purchaseOwnerByOriginal(string $store, string $originalTransactionId): ?string
    {
        if ($originalTransactionId === '') {
            return null;
        }
        $statement = Database::pdo()->prepare('SELECT user_id FROM purchases WHERE store = ? AND original_transaction_id = ? ORDER BY id DESC LIMIT 1');
        $statement->execute([$store, $originalTransactionId]);
        $owner = $statement->fetchColumn();
        return $owner === false ? null : (string) $owner;
    }

    private static function userFromAppAccountToken(mixed $token): ?string
    {
        if (!is_string($token) || !Uuid::isValid($token)) {
            return null;
        }
        $statement = Database::pdo()->prepare('SELECT id FROM users WHERE id = ?');
        $statement->execute([strtolower($token)]);
        $id = $statement->fetchColumn();
        return $id === false ? null : (string) $id;
    }

    // MARK: - Se connecter avec Apple

    /**
     * POST /v1/auth/link/apple {identityToken}
     * - Si ce compte Apple n'est lié à personne: il est rattaché au compte courant.
     * - S'il est déjà lié à un autre compte (ex: nouvel appareil): les données du compte courant
     *   sont fusionnées dans ce compte existant, et un jeton pour ce compte est renvoyé.
     */
    public static function linkApple(): never
    {
        $userId = Auth::requireUserId();
        $identityToken = (string) (Http::body()['identityToken'] ?? '');

        try {
            $claims = Apple::verifyIdentityToken($identityToken);
        } catch (\InvalidArgumentException $error) {
            Http::error(401, 'invalid_identity_token', 'Jeton Apple invalide: ' . $error->getMessage());
        }
        $sub = (string) ($claims['sub'] ?? '');
        if ($sub === '') {
            Http::error(401, 'invalid_identity_token', 'Jeton Apple sans identifiant.');
        }

        $pdo = Database::pdo();
        $statement = $pdo->prepare('SELECT id FROM users WHERE apple_sub = ?');
        $statement->execute([$sub]);
        $existing = $statement->fetchColumn();

        if ($existing === false || $existing === $userId) {
            $pdo->prepare('UPDATE users SET apple_sub = ? WHERE id = ?')->execute([$sub, $userId]);
            Http::json(200, ['userId' => $userId, 'merged' => false]);
        }

        $targetId = (string) $existing;
        $result = Auth::mergeInto($userId, $targetId);
        Http::json(200, ['userId' => $targetId, 'token' => $result['token'], 'merged' => true]);
    }

    // MARK: - Prochaines étapes

    /** Routes prévues (Google Play: rattachement, achats, notifications) — avec l'app Android */
    public static function notImplemented(): never
    {
        Http::error(501, 'not_implemented', 'Disponible dans une prochaine version.');
    }
}
