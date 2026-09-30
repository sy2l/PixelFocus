#!/usr/bin/env bash
# Lance les tests d'intégration de l'API sur une base MySQL/MariaDB locale.
#
# Prérequis: PHP 8.1+ (pdo_mysql) et une base de test vide.
# Variables (valeurs par défaut entre parenthèses):
#   DB_HOST (127.0.0.1)  DB_PORT (3306)  DB_NAME (pixelfocus_test)  DB_USER (pf)  DB_PASSWORD (pf)
#   PORT (8099)
#
# ATTENTION: la base DB_NAME est vidée au début du test.

set -euo pipefail
cd "$(dirname "$0")/.."

PORT="${PORT:-8099}"
MOCK_PORT="${MOCK_PORT:-8098}"
export TEST_DIR="$(mktemp -d -t pixelfocus-test-XXXX)"
CONFIG_FILE="$TEST_DIR/config.php"
trap 'rm -rf "$TEST_DIR"; rm -f "$(php -r "echo sys_get_temp_dir();")"/pixelfocus-apple-jwks-*.json; for p in ${SERVER_PID:-} ${MOCK_PID:-}; do kill "$p" 2>/dev/null || true; done' EXIT

cat > "$CONFIG_FILE" <<PHP
<?php
return [
    'db' => [
        'host' => '${DB_HOST:-127.0.0.1}',
        'port' => ${DB_PORT:-3306},
        'name' => '${DB_NAME:-pixelfocus_test}',
        'user' => '${DB_USER:-pf}',
        'password' => '${DB_PASSWORD:-pf}',
    ],
    'env' => 'development',
    'apple' => [
        'bundle_id' => 'com.sy2l.PixelFocus',
        'issuer_id' => '11111111-2222-3333-4444-555555555555',
        'key_id' => 'TESTKEY123',
        'private_key_path' => '$TEST_DIR/AuthKey.p8',
        'api_base_urls' => ['http://127.0.0.1:$MOCK_PORT/prod', 'http://127.0.0.1:$MOCK_PORT/sandbox'],
        'jwks_url' => 'http://127.0.0.1:$MOCK_PORT/auth/keys',
    ],
    'max_events_per_request' => 500,
    'max_payload_bytes' => 4096,
];
PHP
export PIXELFOCUS_CONFIG="$CONFIG_FILE"

# Base vide puis migrations
php -r '
require "src/bootstrap.php";
$pdo = PixelFocus\Api\Database::pdo();
$pdo->exec("SET FOREIGN_KEY_CHECKS = 0");
foreach ($pdo->query("SHOW TABLES")->fetchAll(PDO::FETCH_COLUMN) as $t) { $pdo->exec("DROP TABLE `$t`"); }
$pdo->exec("SET FOREIGN_KEY_CHECKS = 1");
'
php bin/migrate.php

# Serveur PHP local + faux serveurs Apple
php -S "127.0.0.1:$PORT" public/index.php >"$TEST_DIR/api.log" 2>&1 &
SERVER_PID=$!
php -S "127.0.0.1:$MOCK_PORT" tests/mock_apple.php >"$TEST_DIR/mock.log" 2>&1 &
MOCK_PID=$!
sleep 1

API_URL="http://127.0.0.1:$PORT" php tests/api_test.php || { echo "--- journal API ---"; tail -20 "$TEST_DIR/api.log"; exit 1; }
