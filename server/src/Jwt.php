<?php

declare(strict_types=1);

namespace PixelFocus\Api;

/**
 * Outils JWT/JWS sans dépendance:
 * - base64url
 * - lecture d'un JWS (sans vérification, pour des données reçues d'Apple via HTTPS)
 * - signature ES256 (jeton d'accès à l'App Store Server API)
 * - vérification RS256 avec une clé JWK (jetons "Se connecter avec Apple")
 */
final class Jwt
{
    public static function base64UrlEncode(string $data): string
    {
        return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
    }

    public static function base64UrlDecode(string $data): string
    {
        $padded = strtr($data, '-_', '+/') . str_repeat('=', (4 - strlen($data) % 4) % 4);
        $decoded = base64_decode($padded, true);
        if ($decoded === false) {
            throw new \InvalidArgumentException('base64url invalide');
        }
        return $decoded;
    }

    /**
     * Décode l'en-tête et le contenu d'un JWS SANS vérifier la signature.
     * @return array{header: array, payload: array}
     */
    public static function decodeUnverified(string $jws): array
    {
        $parts = explode('.', $jws);
        if (count($parts) !== 3) {
            throw new \InvalidArgumentException('JWS invalide');
        }
        $header = json_decode(self::base64UrlDecode($parts[0]), true);
        $payload = json_decode(self::base64UrlDecode($parts[1]), true);
        if (!is_array($header) || !is_array($payload)) {
            throw new \InvalidArgumentException('JWS invalide');
        }
        return ['header' => $header, 'payload' => $payload];
    }

    /** Signe un JWT en ES256 avec une clé privée EC P-256 (format PEM, ex: clé .p8 d'App Store Connect) */
    public static function signEs256(array $header, array $payload, string $privateKeyPem): string
    {
        $header['alg'] = 'ES256';
        $signingInput = self::base64UrlEncode(json_encode($header, JSON_UNESCAPED_SLASHES))
            . '.' . self::base64UrlEncode(json_encode($payload, JSON_UNESCAPED_SLASHES));

        $key = openssl_pkey_get_private($privateKeyPem);
        if ($key === false) {
            throw new \RuntimeException('Clé privée ES256 illisible');
        }
        $der = '';
        if (!openssl_sign($signingInput, $der, $key, OPENSSL_ALGO_SHA256)) {
            throw new \RuntimeException('Signature ES256 impossible');
        }
        return $signingInput . '.' . self::base64UrlEncode(self::derToRawSignature($der, 32));
    }

    /**
     * Vérifie un JWT RS256 avec un jeu de clés JWK (JWKS) et renvoie son contenu.
     * Lève une exception si la signature, l'émetteur, l'audience ou l'expiration ne conviennent pas.
     */
    public static function verifyRs256(string $jwt, array $jwks, string $issuer, string $audience, ?int $now = null): array
    {
        $parts = explode('.', $jwt);
        if (count($parts) !== 3) {
            throw new \InvalidArgumentException('Jeton invalide');
        }
        ['header' => $header, 'payload' => $payload] = self::decodeUnverified($jwt);
        if (($header['alg'] ?? '') !== 'RS256') {
            throw new \InvalidArgumentException('Algorithme non supporté');
        }

        $jwk = null;
        foreach ($jwks['keys'] ?? [] as $candidate) {
            if (($candidate['kid'] ?? null) === ($header['kid'] ?? null) && ($candidate['kty'] ?? '') === 'RSA') {
                $jwk = $candidate;
                break;
            }
        }
        if ($jwk === null) {
            throw new \InvalidArgumentException('Clé de signature inconnue');
        }

        $pem = self::rsaJwkToPem($jwk['n'], $jwk['e']);
        $valid = openssl_verify($parts[0] . '.' . $parts[1], self::base64UrlDecode($parts[2]), $pem, OPENSSL_ALGO_SHA256);
        if ($valid !== 1) {
            throw new \InvalidArgumentException('Signature invalide');
        }

        $now ??= time();
        if (($payload['iss'] ?? null) !== $issuer) {
            throw new \InvalidArgumentException('Émetteur invalide');
        }
        $aud = $payload['aud'] ?? null;
        if (!($aud === $audience || (is_array($aud) && in_array($audience, $aud, true)))) {
            throw new \InvalidArgumentException('Audience invalide');
        }
        if (!isset($payload['exp']) || (int) $payload['exp'] < $now) {
            throw new \InvalidArgumentException('Jeton expiré');
        }
        return $payload;
    }

    // MARK: - Conversions

    /** Signature ECDSA DER (SEQUENCE { r, s }) -> R||S de longueur fixe (format JWS) */
    private static function derToRawSignature(string $der, int $partLength): string
    {
        $offset = 2;
        if ((ord($der[1]) & 0x80) !== 0) {
            $offset += ord($der[1]) & 0x7f;
        }
        $parts = [];
        for ($i = 0; $i < 2; $i++) {
            if (ord($der[$offset]) !== 0x02) {
                throw new \RuntimeException('Signature DER invalide');
            }
            $length = ord($der[$offset + 1]);
            $value = substr($der, $offset + 2, $length);
            $offset += 2 + $length;
            $value = ltrim($value, "\x00");
            $parts[] = str_pad($value, $partLength, "\x00", STR_PAD_LEFT);
        }
        return $parts[0] . $parts[1];
    }

    /** Clé publique RSA (modulus n, exposant e en base64url) -> PEM SubjectPublicKeyInfo */
    public static function rsaJwkToPem(string $n, string $e): string
    {
        $modulus = self::base64UrlDecode($n);
        $exponent = self::base64UrlDecode($e);

        $rsaPublicKey = self::asn1Sequence(self::asn1Integer($modulus) . self::asn1Integer($exponent));
        $algorithm = self::asn1Sequence("\x06\x09\x2a\x86\x48\x86\xf7\x0d\x01\x01\x01" . "\x05\x00"); // rsaEncryption, NULL
        $bitString = "\x03" . self::asn1Length(strlen($rsaPublicKey) + 1) . "\x00" . $rsaPublicKey;
        $spki = self::asn1Sequence($algorithm . $bitString);

        return "-----BEGIN PUBLIC KEY-----\n" . chunk_split(base64_encode($spki), 64, "\n") . "-----END PUBLIC KEY-----\n";
    }

    private static function asn1Integer(string $bytes): string
    {
        $bytes = ltrim($bytes, "\x00");
        if ($bytes === '' || (ord($bytes[0]) & 0x80) !== 0) {
            $bytes = "\x00" . $bytes;
        }
        return "\x02" . self::asn1Length(strlen($bytes)) . $bytes;
    }

    private static function asn1Sequence(string $content): string
    {
        return "\x30" . self::asn1Length(strlen($content)) . $content;
    }

    private static function asn1Length(int $length): string
    {
        if ($length < 0x80) {
            return chr($length);
        }
        $bytes = ltrim(pack('N', $length), "\x00");
        return chr(0x80 | strlen($bytes)) . $bytes;
    }
}
