<?php

declare(strict_types=1);

namespace PixelFocus\Api;

/**
 * Configuration: config/config.php (ou le fichier indiqué par la variable d'environnement PIXELFOCUS_CONFIG).
 */
final class Config
{
    private static ?array $values = null;

    public static function all(): array
    {
        if (self::$values === null) {
            $path = getenv('PIXELFOCUS_CONFIG') ?: __DIR__ . '/../config/config.php';
            if (!is_file($path)) {
                throw new \RuntimeException('Configuration manquante: copier config/config.example.php en config/config.php');
            }
            self::$values = require $path;
        }
        return self::$values;
    }

    public static function get(string $key, mixed $default = null): mixed
    {
        return self::all()[$key] ?? $default;
    }

    public static function isProduction(): bool
    {
        return self::get('env', 'production') === 'production';
    }
}
