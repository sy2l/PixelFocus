<?php
/*
 * Applique les fichiers sql/*.sql pas encore appliqués (dans l'ordre), et les note dans schema_migrations.
 *
 * Usage (SSH o2switch, depuis le dossier de l'API):
 *     php bin/migrate.php
 *
 * Alternative sans SSH: importer les fichiers sql/ dans l'ordre via phpMyAdmin.
 */

declare(strict_types=1);

require __DIR__ . '/../src/bootstrap.php';

use PixelFocus\Api\Database;

$pdo = Database::pdo();
$pdo->exec('CREATE TABLE IF NOT EXISTS schema_migrations (version VARCHAR(50) NOT NULL, applied_at DATETIME NOT NULL, PRIMARY KEY (version)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4');

$applied = $pdo->query('SELECT version FROM schema_migrations')->fetchAll(PDO::FETCH_COLUMN);
$files = glob(__DIR__ . '/../sql/*.sql') ?: [];
sort($files);

$count = 0;
foreach ($files as $file) {
    $version = basename($file, '.sql');
    if (in_array($version, $applied, true)) {
        continue;
    }

    $sql = file_get_contents($file);
    // Découpe simple sur ";" en fin de ligne (les fichiers de migration n'utilisent pas de procédures)
    foreach (preg_split('/;\s*$/m', $sql) as $statement) {
        $statement = trim(preg_replace('/^\s*--.*$/m', '', $statement));
        if ($statement !== '') {
            $pdo->exec($statement);
        }
    }

    $pdo->prepare('INSERT INTO schema_migrations (version, applied_at) VALUES (?, UTC_TIMESTAMP())')->execute([$version]);
    echo "Appliquée: $version\n";
    $count++;
}

echo $count === 0 ? "Base à jour.\n" : "$count migration(s) appliquée(s).\n";
