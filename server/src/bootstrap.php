<?php
/*
 * Chargement de l'API: autoload des classes PixelFocus\Api\* depuis src/, gestion des erreurs.
 * Aucune dépendance externe (pas de Composer nécessaire). PHP 8.1 minimum.
 */

declare(strict_types=1);

spl_autoload_register(static function (string $class): void {
    $prefix = 'PixelFocus\\Api\\';
    if (strncmp($class, $prefix, strlen($prefix)) !== 0) {
        return;
    }
    $relative = substr($class, strlen($prefix));
    $file = __DIR__ . '/' . str_replace('\\', '/', $relative) . '.php';
    if (is_file($file)) {
        require $file;
    }
});

// Les avertissements PHP deviennent des exceptions (réponse 500 propre, jamais de HTML d'erreur).
// Les notices de dépréciation sont seulement journalisées.
set_error_handler(static function (int $severity, string $message, string $file, int $line): bool {
    if (!(error_reporting() & $severity)) {
        return false;
    }
    if ($severity === E_DEPRECATED || $severity === E_USER_DEPRECATED) {
        error_log("[PixelFocus API] Deprecated: $message in $file:$line");
        return true;
    }
    throw new ErrorException($message, 0, $severity, $file, $line);
});
