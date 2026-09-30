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
CONFIG_FILE="$(mktemp -t pixelfocus-config-XXXX.php)"
trap 'rm -f "$CONFIG_FILE"; [[ -n "${SERVER_PID:-}" ]] && kill "$SERVER_PID" 2>/dev/null || true' EXIT

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

# Serveur PHP local
php -S "127.0.0.1:$PORT" public/index.php >/tmp/pixelfocus-api-test.log 2>&1 &
SERVER_PID=$!
sleep 1

API_URL="http://127.0.0.1:$PORT" php tests/api_test.php
