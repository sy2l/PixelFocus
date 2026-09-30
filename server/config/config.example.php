<?php
/*
 * Configuration de l'API PixelFocus.
 *
 * Copier ce fichier en config.php (même dossier) et renseigner les valeurs.
 * config.php n'est jamais versionné (voir .gitignore).
 *
 * Sur o2switch: la base et l'utilisateur MySQL se créent dans cPanel > Bases de données MySQL.
 * Le nom de la base et de l'utilisateur sont préfixés par ton identifiant cPanel (ex: moncompte_pixelfocus).
 */

return [
    'db' => [
        'host'     => 'localhost',
        'port'     => 3306,
        'name'     => 'moncompte_pixelfocus',
        'user'     => 'moncompte_pfapi',
        'password' => 'CHANGE-ME',
    ],

    // 'production' masque le détail des erreurs dans les réponses
    'env' => 'production',

    // Apple (App Store Connect > Utilisateurs et accès > Intégrations > Achats intégrés)
    'apple' => [
        'bundle_id'        => 'com.sy2l.PixelFocus',
        'issuer_id'        => '00000000-0000-0000-0000-000000000000',
        'key_id'           => 'ABC123DEFG',
        // Clé .p8 téléchargée depuis App Store Connect, à placer HORS du dossier public
        'private_key_path' => __DIR__ . '/AuthKey_ABC123DEFG.p8',
    ],

    // Limites
    'max_events_per_request' => 500,
    'max_payload_bytes'      => 4096,
];
