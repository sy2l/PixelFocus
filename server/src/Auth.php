<?php

declare(strict_types=1);

namespace PixelFocus\Api;

/**
 * Comptes anonymes et jetons d'accès.
 *
 * - L'app crée un compte anonyme au premier lancement et garde le jeton dans le trousseau.
 * - Seul le hash SHA-256 du jeton est stocké en base.
 * - Rattachement Apple / Google: étape suivante (routes /v1/auth/link/*).
 */
final class Auth
{
    private const PLATFORMS = ['ios', 'android', 'web'];

    /**
     * Crée un utilisateur anonyme et son premier jeton.
     * @return array{userId: string, token: string, firstLaunchAt: string}
     */
    public static function createAnonymous(string $platform, ?string $deviceName, ?string $firstLaunchIso): array
    {
        if (!in_array($platform, self::PLATFORMS, true)) {
            Http::error(422, 'invalid_platform', 'platform doit être ios, android ou web.');
        }

        $now = Database::now();
        $firstLaunch = self::sanitizeFirstLaunch($firstLaunchIso, $now);
        $userId = Uuid::v4();
        $token = self::newToken();

        $pdo = Database::pdo();
        $pdo->beginTransaction();
        $pdo->prepare('INSERT INTO users (id, created_at, first_launch_at, last_seen_at) VALUES (?, ?, ?, ?)')
            ->execute([$userId, $now, $firstLaunch, $now]);
        $pdo->prepare('INSERT INTO auth_tokens (token_hash, user_id, platform, device_name, created_at, last_seen_at) VALUES (?, ?, ?, ?, ?, ?)')
            ->execute([hash('sha256', $token), $userId, $platform, self::cleanDeviceName($deviceName), $now, $now]);
        $pdo->commit();

        return ['userId' => $userId, 'token' => $token, 'firstLaunchAt' => Database::toIso($firstLaunch)];
    }

    /** Identifiant de l'utilisateur authentifié par le jeton Bearer, ou erreur 401 */
    public static function requireUserId(): string
    {
        $token = Http::bearerToken();
        if ($token === null) {
            Http::error(401, 'unauthorized', 'Jeton manquant.');
        }

        $hash = hash('sha256', $token);
        $pdo = Database::pdo();
        $statement = $pdo->prepare('SELECT user_id FROM auth_tokens WHERE token_hash = ?');
        $statement->execute([$hash]);
        $userId = $statement->fetchColumn();
        if ($userId === false) {
            Http::error(401, 'unauthorized', 'Jeton invalide.');
        }

        $now = Database::now();
        $pdo->prepare('UPDATE auth_tokens SET last_seen_at = ? WHERE token_hash = ?')->execute([$now, $hash]);
        $pdo->prepare('UPDATE users SET last_seen_at = ? WHERE id = ?')->execute([$now, $userId]);

        return (string) $userId;
    }

    /**
     * Fusionne le compte $sourceId dans $targetId (ex: compte anonyme d'un nouvel appareil
     * rattaché à un compte Apple déjà connu), supprime $sourceId et renvoie un jeton pour $targetId.
     * @return array{token: string}
     */
    public static function mergeInto(string $sourceId, string $targetId): array
    {
        $pdo = Database::pdo();

        // Plateforme et nom de l'appareil courant (jeton de la requête)
        $statement = $pdo->prepare('SELECT platform, device_name FROM auth_tokens WHERE token_hash = ?');
        $statement->execute([hash('sha256', (string) Http::bearerToken())]);
        $device = $statement->fetch() ?: ['platform' => 'ios', 'device_name' => null];

        $token = self::newToken();
        $now = Database::now();

        $pdo->beginTransaction();
        $pdo->prepare('UPDATE events SET user_id = ? WHERE user_id = ?')->execute([$targetId, $sourceId]);
        $pdo->prepare('UPDATE purchases SET user_id = ? WHERE user_id = ?')->execute([$targetId, $sourceId]);
        $pdo->prepare(
            'UPDATE users target JOIN users source ON source.id = ?
             SET target.first_launch_at = LEAST(target.first_launch_at, source.first_launch_at)
             WHERE target.id = ?'
        )->execute([$sourceId, $targetId]);
        $pdo->prepare('DELETE FROM users WHERE id = ?')->execute([$sourceId]);
        $pdo->prepare('INSERT INTO auth_tokens (token_hash, user_id, platform, device_name, created_at, last_seen_at) VALUES (?, ?, ?, ?, ?, ?)')
            ->execute([hash('sha256', $token), $targetId, $device['platform'], $device['device_name'], $now, $now]);
        $pdo->commit();

        return ['token' => $token];
    }

    private static function newToken(): string
    {
        return rtrim(strtr(base64_encode(random_bytes(32)), '+/', '-_'), '=');
    }

    /**
     * Date du premier lancement envoyée par l'app (conservée dans le trousseau).
     * Refusée si invalide, dans le futur ou avant 2025: on retient alors la date du jour.
     */
    private static function sanitizeFirstLaunch(?string $iso, string $now): string
    {
        if ($iso === null) {
            return $now;
        }
        $utc = Database::toUtc($iso);
        if ($utc === null || $utc > $now || $utc < '2025-01-01 00:00:00.000') {
            return $now;
        }
        return $utc;
    }

    private static function cleanDeviceName(?string $name): ?string
    {
        if ($name === null) {
            return null;
        }
        $name = trim(preg_replace('/[\x00-\x1F\x7F]/u', '', $name) ?? '');
        return $name === '' ? null : mb_substr($name, 0, 100);
    }
}
