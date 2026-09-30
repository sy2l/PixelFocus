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

    // Apple: achats, notifications App Store, "Se connecter avec Apple"
    $router->add('POST', '/v1/purchases/apple', [Handlers::class, 'postApplePurchase']);
    $router->add('POST', '/v1/webhooks/apple', [Handlers::class, 'appleWebhook']);
    $router->add('POST', '/v1/auth/link/apple', [Handlers::class, 'linkApple']);

    // Google Play: avec l'app Android
    foreach (['/v1/auth/link/google', '/v1/purchases/google', '/v1/webhooks/google'] as $path) {
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
