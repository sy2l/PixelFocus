<?php

declare(strict_types=1);

namespace PixelFocus\Api;

/**
 * Routeur minimal: méthode + chemin exact.
 */
final class Router
{
    /** @var array<string, array<string, callable>> */
    private array $routes = [];

    public function add(string $method, string $path, callable $handler): void
    {
        $this->routes[$path][strtoupper($method)] = $handler;
    }

    public function dispatch(string $method, string $uri): never
    {
        $path = '/' . trim((string) parse_url($uri, PHP_URL_PATH), '/');

        if (!isset($this->routes[$path])) {
            Http::error(404, 'not_found', 'Route inconnue.');
        }

        $handler = $this->routes[$path][strtoupper($method)] ?? null;
        if ($handler === null) {
            header('Allow: ' . implode(', ', array_keys($this->routes[$path])));
            Http::error(405, 'method_not_allowed', 'Méthode non autorisée.');
        }

        $handler();
        Http::error(500, 'no_response', 'Aucune réponse produite.');
    }
}
