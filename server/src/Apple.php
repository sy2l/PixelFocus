<?php

declare(strict_types=1);

namespace PixelFocus\Api;

/**
 * Intégrations Apple, sans intermédiaire:
 * - App Store Server API: récupérer une transaction faisant autorité (achats, renouvellements, remboursements)
 * - Se connecter avec Apple: vérifier le jeton d'identité (JWT RS256) avec les clés publiques d'Apple
 *
 * Configuration: clé 'apple' dans config/config.php (voir config.example.php).
 */
final class Apple
{
    private const SIGN_IN_ISSUER = 'https://appleid.apple.com';

    // MARK: - App Store Server API

    /**
     * Transaction décodée (signedTransactionInfo) récupérée auprès d'Apple.
     * Essaie la production puis le bac à sable (achats de test/TestFlight).
     * @return array|null contenu de la transaction, ou null si Apple ne la connaît pas
     */
    public static function fetchTransaction(string $transactionId): ?array
    {
        $config = self::config();
        $token = self::appStoreApiToken($config);

        foreach ($config['api_base_urls'] as $baseUrl) {
            [$status, $body] = self::httpGet(rtrim($baseUrl, '/') . '/inApps/v1/transactions/' . rawurlencode($transactionId), $token);
            if ($status === 404) {
                continue;
            }
            if ($status !== 200) {
                throw new \RuntimeException("App Store Server API: HTTP $status");
            }
            $data = json_decode($body, true);
            $signed = $data['signedTransactionInfo'] ?? null;
            if (!is_string($signed)) {
                throw new \RuntimeException('App Store Server API: réponse inattendue');
            }
            return Jwt::decodeUnverified($signed)['payload'];
        }
        return null;
    }

    /** Jeton d'accès ES256 à l'App Store Server API (valable 20 minutes) */
    private static function appStoreApiToken(array $config): string
    {
        $keyPath = $config['private_key_path'] ?? '';
        if (!is_string($keyPath) || !is_file($keyPath)) {
            throw new \RuntimeException('Clé App Store Connect (.p8) introuvable: voir apple.private_key_path');
        }
        $now = time();
        return Jwt::signEs256(
            ['kid' => $config['key_id'], 'typ' => 'JWT'],
            [
                'iss' => $config['issuer_id'],
                'iat' => $now,
                'exp' => $now + 1200,
                'aud' => 'appstoreconnect-v1',
                'bid' => $config['bundle_id'],
            ],
            (string) file_get_contents($keyPath)
        );
    }

    // MARK: - Se connecter avec Apple

    /**
     * Vérifie un jeton d'identité "Se connecter avec Apple" et renvoie son contenu (dont "sub").
     * @throws \InvalidArgumentException si le jeton n'est pas valide
     */
    public static function verifyIdentityToken(string $identityToken): array
    {
        $config = self::config();
        return Jwt::verifyRs256($identityToken, self::signInKeys($config), self::SIGN_IN_ISSUER, $config['bundle_id']);
    }

    /** Clés publiques d'Apple (JWKS), mises en cache 24 h dans le dossier temporaire */
    private static function signInKeys(array $config): array
    {
        $url = $config['jwks_url'];
        $cacheFile = sys_get_temp_dir() . '/pixelfocus-apple-jwks-' . md5($url) . '.json';

        if (is_file($cacheFile) && filemtime($cacheFile) > time() - 86400) {
            $cached = json_decode((string) file_get_contents($cacheFile), true);
            if (is_array($cached)) {
                return $cached;
            }
        }

        [$status, $body] = self::httpGet($url, null);
        $keys = json_decode($body, true);
        if ($status !== 200 || !is_array($keys)) {
            throw new \RuntimeException("Clés Apple indisponibles (HTTP $status)");
        }
        @file_put_contents($cacheFile, $body);
        return $keys;
    }

    // MARK: - Helpers

    private static function config(): array
    {
        $config = Config::get('apple');
        if (!is_array($config) || empty($config['bundle_id'])) {
            throw new \RuntimeException('Configuration Apple manquante (clé apple dans config.php)');
        }
        $config['api_base_urls'] ??= [
            'https://api.storekit.itunes.apple.com',
            'https://api.storekit-sandbox.itunes.apple.com',
        ];
        $config['jwks_url'] ??= 'https://appleid.apple.com/auth/keys';
        return $config;
    }

    /** @return array{0: int, 1: string} statut HTTP et corps */
    private static function httpGet(string $url, ?string $bearer): array
    {
        $curl = curl_init($url);
        $headers = ['Accept: application/json'];
        if ($bearer !== null) {
            $headers[] = "Authorization: Bearer $bearer";
        }
        curl_setopt_array($curl, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_HTTPHEADER     => $headers,
            CURLOPT_TIMEOUT        => 15,
            CURLOPT_CONNECTTIMEOUT => 5,
        ]);
        $body = curl_exec($curl);
        $status = (int) curl_getinfo($curl, CURLINFO_RESPONSE_CODE);
        $error = curl_error($curl);

        if ($body === false) {
            throw new \RuntimeException("Requête HTTP impossible: $error");
        }
        return [$status, (string) $body];
    }

    /** Millisecondes depuis 1970 (format Apple) -> DATETIME(3) UTC */
    public static function msToUtc(mixed $milliseconds): ?string
    {
        if (!is_numeric($milliseconds)) {
            return null;
        }
        $seconds = intdiv((int) $milliseconds, 1000);
        $millis = (int) $milliseconds % 1000;
        return gmdate('Y-m-d H:i:s', $seconds) . sprintf('.%03d', $millis);
    }
}
