<?php

declare(strict_types=1);

namespace PixelFocus\Api;

/**
 * Réponses JSON et lecture de la requête.
 */
final class Http
{
    /** Envoie une réponse JSON et termine */
    public static function json(int $status, array $data): never
    {
        http_response_code($status);
        header('Content-Type: application/json; charset=utf-8');
        header('Cache-Control: no-store');
        echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        exit;
    }

    /** Réponse d'erreur au format {"error": {"code": ..., "message": ...}} */
    public static function error(int $status, string $code, string $message): never
    {
        self::json($status, ['error' => ['code' => $code, 'message' => $message]]);
    }

    /** Corps JSON de la requête (objet), ou erreur 400 */
    public static function body(): array
    {
        $raw = file_get_contents('php://input');
        if ($raw === false || trim($raw) === '') {
            return [];
        }
        $data = json_decode($raw, true);
        if (!is_array($data)) {
            self::error(400, 'invalid_json', 'Le corps de la requête doit être un objet JSON.');
        }
        return $data;
    }

    /** Jeton "Authorization: Bearer ..." (compatible Apache/LiteSpeed en CGI via .htaccess) */
    public static function bearerToken(): ?string
    {
        $header = $_SERVER['HTTP_AUTHORIZATION']
            ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION']
            ?? (function_exists('getallheaders') ? (getallheaders()['Authorization'] ?? null) : null);

        if (!is_string($header) || !preg_match('/^Bearer\s+(\S+)$/i', trim($header), $matches)) {
            return null;
        }
        return $matches[1];
    }
}
