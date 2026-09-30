<?php
/*
 * Tests d'intégration de l'API (serveur PHP + vraie base MySQL/MariaDB).
 * Lancés par tests/run.sh, qui démarre un serveur local et une base de test.
 *
 * Usage direct: API_URL=http://127.0.0.1:8099 php tests/api_test.php
 */

declare(strict_types=1);

$base = getenv('API_URL') ?: 'http://127.0.0.1:8099';
$failures = 0;
$passed = 0;

function request(string $method, string $path, ?array $body = null, ?string $token = null): array
{
    global $base;
    $headers = ['Content-Type: application/json'];
    if ($token !== null) {
        $headers[] = "Authorization: Bearer $token";
    }
    $context = stream_context_create(['http' => [
        'method'        => $method,
        'header'        => implode("\r\n", $headers),
        'content'       => $body === null ? '' : json_encode($body),
        'ignore_errors' => true,
        'timeout'       => 10,
    ]]);
    $raw = file_get_contents($base . $path, false, $context);
    preg_match('/^HTTP\/\S+\s+(\d+)/', $http_response_header[0] ?? '', $m);
    return ['status' => (int) ($m[1] ?? 0), 'json' => json_decode((string) $raw, true)];
}

function check(string $label, bool $condition, mixed $debug = null): void
{
    global $failures, $passed;
    if ($condition) {
        $passed++;
        echo "  ✓ $label\n";
    } else {
        $failures++;
        echo "  ✗ $label\n";
        if ($debug !== null) {
            echo '      ' . json_encode($debug, JSON_UNESCAPED_UNICODE) . "\n";
        }
    }
}

function uuid(): string
{
    $b = random_bytes(16);
    $b[6] = chr((ord($b[6]) & 0x0f) | 0x40);
    $b[8] = chr((ord($b[8]) & 0x3f) | 0x80);
    return vsprintf('%s%s-%s-%s-%s-%s%s%s', str_split(bin2hex($b), 4));
}

echo "Santé\n";
$r = request('GET', '/v1/health');
check('GET /v1/health → 200', $r['status'] === 200 && $r['json']['ok'] === true, $r);
check('route inconnue → 404', request('GET', '/v1/nope')['status'] === 404);
check('mauvaise méthode → 405', request('GET', '/v1/events')['status'] === 405);

echo "Compte anonyme\n";
$r = request('POST', '/v1/auth/anonymous', ['platform' => 'ios', 'deviceName' => 'iPhone test', 'firstLaunchAt' => '2026-09-10T08:00:00+02:00']);
check('création → 201', $r['status'] === 201, $r);
$token = $r['json']['token'] ?? '';
$userId = $r['json']['userId'] ?? '';
check('jeton et identifiant renvoyés', strlen($token) >= 40 && strlen($userId) === 36, $r['json']);
check('firstLaunchAt conservé (converti en UTC)', ($r['json']['firstLaunchAt'] ?? '') === '2026-09-10T06:00:00.000Z', $r['json']);

$r = request('POST', '/v1/auth/anonymous', ['platform' => 'ios', 'firstLaunchAt' => '2099-01-01T00:00:00Z']);
check('firstLaunchAt futur ignoré', ($r['json']['firstLaunchAt'] ?? '9') < '2099', $r['json']);
check('plateforme invalide → 422', request('POST', '/v1/auth/anonymous', ['platform' => 'windows'])['status'] === 422);
check('JSON invalide → 400', (function () use ($base) {
    $ctx = stream_context_create(['http' => ['method' => 'POST', 'header' => 'Content-Type: application/json', 'content' => '{oops', 'ignore_errors' => true]]);
    file_get_contents($base . '/v1/auth/anonymous', false, $ctx);
    return str_contains($http_response_header[0] ?? '', '400');
})());

echo "Authentification\n";
check('sans jeton → 401', request('GET', '/v1/state')['status'] === 401);
check('jeton invalide → 401', request('GET', '/v1/state', null, 'faux-jeton')['status'] === 401);

echo "Événements\n";
$sessionId = uuid();
$events = [
    ['id' => $sessionId, 'type' => 'session_completed', 'artworkId' => 'daily_2026_09_30', 'payload' => ['minutes' => 25, 'extraMinutesOver30' => 0], 'occurredAt' => '2026-09-30T10:00:00Z'],
    ['id' => uuid(), 'type' => 'booster_used', 'artworkId' => 'daily_2026_09_30', 'payload' => ['source' => 'earned'], 'occurredAt' => '2026-09-30T10:05:00Z'],
    ['id' => uuid(), 'type' => 'booster_earned', 'payload' => ['amount' => 1, 'reason' => 'streak'], 'occurredAt' => '2026-09-30T10:06:00Z'],
];
$r = request('POST', '/v1/events', ['events' => $events], $token);
check('envoi de 3 événements → 3 acceptés', $r['status'] === 200 && count($r['json']['accepted']) === 3, $r);

$r = request('POST', '/v1/events', ['events' => [$events[0]]], $token);
check('renvoi du même événement → doublon ignoré', $r['json']['duplicates'] === [$sessionId] && $r['json']['accepted'] === [], $r['json']);

$invalid = [
    ['id' => 'pas-un-uuid', 'type' => 'session_completed', 'artworkId' => 'x', 'occurredAt' => '2026-09-30T10:00:00Z'],
    ['id' => uuid(), 'type' => 'triche', 'occurredAt' => '2026-09-30T10:00:00Z'],
    ['id' => uuid(), 'type' => 'session_completed', 'occurredAt' => '2026-09-30T10:00:00Z'],
    ['id' => uuid(), 'type' => 'booster_used', 'artworkId' => 'DROP TABLE', 'occurredAt' => '2026-09-30T10:00:00Z'],
    ['id' => uuid(), 'type' => 'booster_earned', 'occurredAt' => '2099-01-01T00:00:00Z'],
    ['id' => uuid(), 'type' => 'booster_earned', 'payload' => 'texte', 'occurredAt' => '2026-09-30T10:00:00Z'],
];
$r = request('POST', '/v1/events', ['events' => $invalid], $token);
$reasons = array_column($r['json']['rejected'] ?? [], 'reason');
check('événements invalides rejetés un par un', $reasons === ['invalid_id', 'unknown_type', 'missing_artwork_id', 'invalid_artwork_id', 'occurred_at_out_of_range', 'invalid_payload'], $reasons);
check('events non-liste → 422', request('POST', '/v1/events', ['events' => ['a' => 1]], $token)['status'] === 422);

echo "État et synchronisation\n";
$r = request('GET', '/v1/state', null, $token);
check('GET /v1/state → 200', $r['status'] === 200, $r);
check('3 événements, dans l\'ordre', array_column($r['json']['events'] ?? [], 'type') === ['session_completed', 'booster_used', 'booster_earned'], $r['json']);
check('payload restitué', ($r['json']['events'][0]['payload']['minutes'] ?? null) === 25, $r['json']['events'][0] ?? null);
check('utilisateur renvoyé', ($r['json']['user']['id'] ?? '') === $userId);
$cursor = $r['json']['cursor'] ?? 0;

$r = request('POST', '/v1/events', ['events' => [['id' => uuid(), 'type' => 'badge_unlocked', 'payload' => ['badgeId' => 'streak_3'], 'occurredAt' => '2026-09-30T11:00:00Z']]], $token);
$r = request('GET', '/v1/state?since=' . $cursor, null, $token);
check('synchro incrémentale: seulement le nouvel événement', array_column($r['json']['events'] ?? [], 'type') === ['badge_unlocked'], $r['json']);

echo "Isolation entre comptes\n";
$other = request('POST', '/v1/auth/anonymous', ['platform' => 'android'])['json']['token'];
$r = request('GET', '/v1/state', null, $other);
check('un autre compte ne voit pas ces événements', ($r['json']['events'] ?? null) === [], $r['json']);
$r = request('POST', '/v1/events', ['events' => [$events[0]]], $other);
check('réutiliser l\'id d\'un autre compte ne crée rien', $r['json']['accepted'] === [], $r['json']);

echo "Achats Apple (faux serveur App Store)\n";
$dir = getenv('TEST_DIR');
$fixtures = [];
function writeFixtures(): void
{
    global $dir, $fixtures;
    file_put_contents("$dir/fixtures.json", json_encode($fixtures));
}
function jws(array $payload): string
{
    $b64 = static fn (string $s): string => rtrim(strtr(base64_encode($s), '+/', '-_'), '=');
    return $b64('{"alg":"ES256"}') . '.' . $b64(json_encode($payload)) . '.' . $b64('sig');
}

// Clé EC de test (comme la clé .p8 d'App Store Connect)
$ec = openssl_pkey_new(['private_key_type' => OPENSSL_KEYTYPE_EC, 'curve_name' => 'prime256v1']);
openssl_pkey_export($ec, $ecPem);
file_put_contents("$dir/AuthKey.p8", $ecPem);
$fixtures['ecPublicKey'] = openssl_pkey_get_details($ec)['key'];

$future = (time() + 30 * 86400) * 1000;
$bundle = 'com.sy2l.PixelFocus';
$p = 'com.sy2l.pixelfocus.';
$fixtures['transactions'] = [
    '1001' => ['transactionId' => '1001', 'originalTransactionId' => '1001', 'bundleId' => $bundle, 'productId' => $p . 'premium.monthly', 'purchaseDate' => time() * 1000, 'expiresDate' => $future, 'appAccountToken' => $userId],
    '1002' => ['transactionId' => '1002', 'originalTransactionId' => '1002', 'bundleId' => $bundle, 'productId' => $p . 'boosters.5', 'purchaseDate' => time() * 1000],
    '9003' => ['transactionId' => '9003', 'originalTransactionId' => '9003', 'bundleId' => $bundle, 'productId' => $p . 'monthly.2026_10.reduced', 'purchaseDate' => time() * 1000, '_environment' => 'sandbox'],
    '1004' => ['transactionId' => '1004', 'bundleId' => 'com.autre.app', 'productId' => $p . 'boosters.1', 'purchaseDate' => time() * 1000],
    '1005' => ['transactionId' => '1005', 'bundleId' => $bundle, 'productId' => $p . 'premium.yearly', 'purchaseDate' => time() * 1000, 'expiresDate' => $future, 'appAccountToken' => '00000000-0000-4000-8000-000000000000'],
    '1006' => ['transactionId' => '1006', 'bundleId' => $bundle, 'productId' => 'com.inconnu', 'purchaseDate' => time() * 1000],
];
writeFixtures();

$r = request('POST', '/v1/purchases/apple', ['transactionId' => '1001'], $token);
check('abonnement mensuel validé → Premium actif', $r['status'] === 200 && ($r['json']['entitlements']['premium']['active'] ?? false) === true, $r);
$r = request('POST', '/v1/purchases/apple', ['transactionId' => '1002'], $token);
check('5 boosters achetés comptabilisés', ($r['json']['entitlements']['purchasedBoostersTotal'] ?? 0) === 5, $r);
$r = request('POST', '/v1/purchases/apple', ['transactionId' => '9003'], $token);
check('image du mois achetée (bac à sable) → débloquée', in_array('monthly_2026_10_main', $r['json']['entitlements']['monthlyArtworkIds'] ?? [], true), $r);
check('autre app → 422', request('POST', '/v1/purchases/apple', ['transactionId' => '1004'], $token)['status'] === 422);
check('produit inconnu → 422', request('POST', '/v1/purchases/apple', ['transactionId' => '1006'], $token)['status'] === 422);
check('achat d\'un autre compte → 409', request('POST', '/v1/purchases/apple', ['transactionId' => '1005'], $token)['status'] === 409);
check('transaction inconnue → 404', request('POST', '/v1/purchases/apple', ['transactionId' => '424242'], $token)['status'] === 404);
check('transactionId invalide → 422', request('POST', '/v1/purchases/apple', ['transactionId' => 'abc'], $token)['status'] === 422);
request('POST', '/v1/purchases/apple', ['transactionId' => '1001'], $token);
$r = request('GET', '/v1/state', null, $token);
check('revalider le même achat ne crée pas de doublon', count($r['json']['purchases'] ?? []) === 3, $r['json']['purchases'] ?? null);

echo "Notifications App Store\n";
$fixtures['transactions']['1002']['revocationDate'] = time() * 1000;
writeFixtures();
$r = request('POST', '/v1/webhooks/apple', ['signedPayload' => jws(['notificationType' => 'REFUND', 'data' => ['signedTransactionInfo' => jws(['transactionId' => '1002'])]])]);
check('remboursement reçu → 200', $r['status'] === 200 && ($r['json']['ok'] ?? false) === true, $r);
$r = request('GET', '/v1/state', null, $token);
check('boosters remboursés retirés', ($r['json']['entitlements']['purchasedBoostersTotal'] ?? -1) === 0, $r['json']['entitlements'] ?? null);

$fixtures['transactions']['1007'] = ['transactionId' => '1007', 'originalTransactionId' => '1001', 'bundleId' => $bundle, 'productId' => $p . 'premium.monthly', 'purchaseDate' => time() * 1000, 'expiresDate' => $future + 30 * 86400000];
writeFixtures();
$r = request('POST', '/v1/webhooks/apple', ['signedPayload' => jws(['notificationType' => 'DID_RENEW', 'data' => ['signedTransactionInfo' => jws(['transactionId' => '1007'])]])]);
$state = request('GET', '/v1/state', null, $token)['json'];
check('renouvellement rattaché au bon compte', count($state['purchases'] ?? []) === 4, $state['purchases'] ?? null);
check('notification illisible → 400', request('POST', '/v1/webhooks/apple', ['signedPayload' => 'n/importe/quoi'])['status'] === 400);

echo "Se connecter avec Apple\n";
$rsa = openssl_pkey_new(['private_key_type' => OPENSSL_KEYTYPE_RSA, 'private_key_bits' => 2048]);
$details = openssl_pkey_get_details($rsa)['rsa'];
$b64u = static fn (string $s): string => rtrim(strtr(base64_encode($s), '+/', '-_'), '=');
$fixtures['jwks'] = ['keys' => [['kty' => 'RSA', 'kid' => 'test-kid', 'use' => 'sig', 'alg' => 'RS256', 'n' => $b64u($details['n']), 'e' => $b64u($details['e'])]]];
writeFixtures();
$identityToken = static function (array $claims) use ($rsa, $b64u): string {
    $input = $b64u(json_encode(['alg' => 'RS256', 'kid' => 'test-kid'])) . '.' . $b64u(json_encode($claims));
    openssl_sign($input, $signature, $rsa, OPENSSL_ALGO_SHA256);
    return $input . '.' . $b64u($signature);
};
$claims = ['iss' => 'https://appleid.apple.com', 'aud' => $bundle, 'sub' => 'apple-user-1', 'exp' => time() + 600];

$r = request('POST', '/v1/auth/link/apple', ['identityToken' => $identityToken($claims)], $token);
check('rattachement Apple du compte courant', $r['status'] === 200 && ($r['json']['merged'] ?? true) === false, $r);
check('jeton Apple d\'une autre app → 401', request('POST', '/v1/auth/link/apple', ['identityToken' => $identityToken(['aud' => 'com.autre'] + $claims)], $token)['status'] === 401);
check('jeton Apple expiré → 401', request('POST', '/v1/auth/link/apple', ['identityToken' => $identityToken(['exp' => time() - 10] + $claims)], $token)['status'] === 401);
check('jeton Apple falsifié → 401', request('POST', '/v1/auth/link/apple', ['identityToken' => $identityToken($claims) . 'x'], $token)['status'] === 401);

// Nouvel appareil: compte anonyme, une session, puis connexion Apple → fusion dans le compte existant
$device2 = request('POST', '/v1/auth/anonymous', ['platform' => 'android'])['json']['token'];
request('POST', '/v1/events', ['events' => [['id' => uuid(), 'type' => 'day_active', 'payload' => ['dayISO' => '2026-09-30'], 'occurredAt' => '2026-09-30T12:00:00Z']]], $device2);
$r = request('POST', '/v1/auth/link/apple', ['identityToken' => $identityToken($claims)], $device2);
check('nouvel appareil → fusion dans le compte existant', ($r['json']['merged'] ?? false) === true && ($r['json']['userId'] ?? '') === $userId, $r);
$mergedToken = $r['json']['token'] ?? '';
$state = request('GET', '/v1/state', null, $mergedToken)['json'];
check('le compte fusionné contient les événements des 2 appareils', in_array('day_active', array_column($state['events'] ?? [], 'type'), true) && in_array('session_completed', array_column($state['events'] ?? [], 'type'), true), $state);
check('Premium retrouvé sur le nouvel appareil', ($state['entitlements']['premium']['active'] ?? false) === true);
check('ancien jeton anonyme du nouvel appareil invalide', request('GET', '/v1/state', null, $device2)['status'] === 401);

echo "Routes prévues\n";
check('POST /v1/purchases/google → 501', request('POST', '/v1/purchases/google', [], $token)['status'] === 501);

echo "Suppression du compte\n";
check('DELETE /v1/account → 200', request('DELETE', '/v1/account', null, $token)['status'] === 200);
check('jeton supprimé ensuite → 401', request('GET', '/v1/state', null, $token)['status'] === 401);

echo "\n$passed réussi(s), $failures échec(s)\n";
exit($failures === 0 ? 0 : 1);
