<?php
/*
 * Faux serveurs Apple pour les tests (lancé avec: php -S 127.0.0.1:8098 tests/mock_apple.php).
 *
 * - GET /prod/inApps/v1/transactions/{id}     (App Store Server API, production)
 * - GET /sandbox/inApps/v1/transactions/{id}  (bac à sable)
 * - GET /auth/keys                            (clés publiques "Se connecter avec Apple")
 *
 * Les données viennent de $TEST_DIR/fixtures.json, écrit par tests/api_test.php.
 * Le jeton ES256 de l'API est vérifié avec la clé publique de test: on valide ainsi la signature produite par l'API.
 */

declare(strict_types=1);

$dir = getenv('TEST_DIR');
$fixtures = json_decode((string) @file_get_contents("$dir/fixtures.json"), true) ?: [];
$path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);

header('Content-Type: application/json');

if ($path === '/auth/keys') {
    echo json_encode($fixtures['jwks'] ?? ['keys' => []]);
    return;
}

if (!preg_match('#^/(prod|sandbox)/inApps/v1/transactions/(\d+)$#', $path, $m)) {
    http_response_code(404);
    echo '{}';
    return;
}
[$_, $environment, $transactionId] = $m;

// Vérifie le jeton d'accès ES256
$auth = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
if (!preg_match('/^Bearer (.+)$/', $auth, $tm) || !verifyEs256($tm[1], (string) ($fixtures['ecPublicKey'] ?? ''))) {
    http_response_code(401);
    echo '{"errorMessage":"bad token"}';
    return;
}

$transaction = $fixtures['transactions'][$transactionId] ?? null;
$onlyIn = $transaction['_environment'] ?? 'prod';
if ($transaction === null || $onlyIn !== $environment) {
    http_response_code(404);
    echo '{"errorCode":4040010}';
    return;
}
unset($transaction['_environment']);

// Apple renvoie un JWS signé; la signature n'est pas vérifiée par l'API (réponse obtenue en HTTPS)
$b64 = static fn (string $s): string => rtrim(strtr(base64_encode($s), '+/', '-_'), '=');
echo json_encode(['signedTransactionInfo' => $b64('{"alg":"ES256"}') . '.' . $b64(json_encode($transaction)) . '.' . $b64('sig')]);

function verifyEs256(string $jwt, string $publicKeyPem): bool
{
    $parts = explode('.', $jwt);
    if (count($parts) !== 3 || $publicKeyPem === '') {
        return false;
    }
    $raw = base64_decode(strtr($parts[2], '-_', '+/') . str_repeat('=', (4 - strlen($parts[2]) % 4) % 4));
    if (strlen($raw) !== 64) {
        return false;
    }
    $integer = static function (string $bytes): string {
        $bytes = ltrim($bytes, "\x00");
        if ($bytes === '' || (ord($bytes[0]) & 0x80)) {
            $bytes = "\x00" . $bytes;
        }
        return "\x02" . chr(strlen($bytes)) . $bytes;
    };
    $body = $integer(substr($raw, 0, 32)) . $integer(substr($raw, 32));
    $der = "\x30" . chr(strlen($body)) . $body;
    $payload = json_decode(base64_decode(strtr($parts[1], '-_', '+/')), true);
    return openssl_verify($parts[0] . '.' . $parts[1], $der, $publicKeyPem, OPENSSL_ALGO_SHA256) === 1
        && ($payload['aud'] ?? null) === 'appstoreconnect-v1';
}
