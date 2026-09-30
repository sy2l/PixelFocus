<?php
/*
 * PixelFocus API — point d'entrée unique.
 * Le dossier public/ est la racine du sous-domaine (ex: api.tondomaine.fr).
 */

declare(strict_types=1);

require __DIR__ . '/../src/bootstrap.php';

use PixelFocus\Api\Config;
use PixelFocus\Api\Handlers;
use PixelFocus\Api\Http;
use PixelFocus\Api\Router;

try {
    $router = new Router();

    $router->add('GET', '/v1/health', [Handlers::class, 'health']);

    $router->add('POST', '/v1/auth/anonymous', [Handlers::class, 'createAnonymous']);
    $router->add('DELETE', '/v1/account', [Handlers::class, 'deleteAccount']);

    $router->add('POST', '/v1/events', [Handlers::class, 'postEvents']);
    $router->add('GET', '/v1/state', [Handlers::class, 'getState']);

    // Prochaines étapes (StoreKit / Play Billing, rattachement de compte)
    foreach (['/v1/auth/link/apple', '/v1/auth/link/google', '/v1/purchases/apple', '/v1/purchases/google', '/v1/webhooks/apple', '/v1/webhooks/google'] as $path) {
        $router->add('POST', $path, [Handlers::class, 'notImplemented']);
    }

    $router->dispatch($_SERVER['REQUEST_METHOD'] ?? 'GET', $_SERVER['REQUEST_URI'] ?? '/');
} catch (\Throwable $error) {
    error_log('[PixelFocus API] ' . $error);
    $message = 'Erreur interne.';
    try {
        if (!Config::isProduction()) {
            $message = $error->getMessage();
        }
    } catch (\Throwable) {
        // configuration illisible: message générique
    }
    Http::error(500, 'internal_error', $message);
}
