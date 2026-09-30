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
            'purchases'  => $purchases,
            'serverTime' => Database::toIso(Database::now()),
        ]);
    }

    // MARK: - Prochaines étapes

    /** Routes prévues (rattachement Apple/Google, achats, webhooks) — branchées avec StoreKit */
    public static function notImplemented(): never
    {
        Http::error(501, 'not_implemented', 'Disponible dans une prochaine version.');
    }
}
