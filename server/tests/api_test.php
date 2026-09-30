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

echo "Routes prévues\n";
check('POST /v1/purchases/apple → 501', request('POST', '/v1/purchases/apple', [], $token)['status'] === 501);

echo "Suppression du compte\n";
check('DELETE /v1/account → 200', request('DELETE', '/v1/account', null, $token)['status'] === 200);
check('jeton supprimé ensuite → 401', request('GET', '/v1/state', null, $token)['status'] === 401);

echo "\n$passed réussi(s), $failures échec(s)\n";
exit($failures === 0 ? 0 : 1);
