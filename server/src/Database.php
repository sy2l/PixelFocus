<?php

declare(strict_types=1);

namespace PixelFocus\Api;

use PDO;

/**
 * Connexion PDO MySQL/MariaDB (UTF-8, UTC, exceptions).
 */
final class Database
{
    private static ?PDO $pdo = null;

    public static function pdo(): PDO
    {
        if (self::$pdo === null) {
            $db = Config::get('db');
            $dsn = sprintf(
                'mysql:host=%s;port=%d;dbname=%s;charset=utf8mb4',
                $db['host'],
                (int) ($db['port'] ?? 3306),
                $db['name']
            );
            self::$pdo = new PDO($dsn, $db['user'], $db['password'], [
                PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                PDO::ATTR_EMULATE_PREPARES   => false,
            ]);
            self::$pdo->exec("SET time_zone = '+00:00'");
        }
        return self::$pdo;
    }

    /** Date courante UTC au format DATETIME(3) */
    public static function now(): string
    {
        return (new \DateTimeImmutable('now', new \DateTimeZone('UTC')))->format('Y-m-d H:i:s.v');
    }

    /** Convertit une date ISO 8601 (avec fuseau) en DATETIME(3) UTC, ou null si invalide */
    public static function toUtc(string $iso): ?string
    {
        try {
            $date = new \DateTimeImmutable($iso);
        } catch (\Exception) {
            return null;
        }
        return $date->setTimezone(new \DateTimeZone('UTC'))->format('Y-m-d H:i:s.v');
    }

    /** Convertit un DATETIME(3) UTC en ISO 8601 (ex: 2026-09-30T12:00:00.000Z) */
    public static function toIso(?string $utc): ?string
    {
        if ($utc === null) {
            return null;
        }
        $date = new \DateTimeImmutable($utc, new \DateTimeZone('UTC'));
        return $date->format('Y-m-d\TH:i:s.v\Z');
    }
}
