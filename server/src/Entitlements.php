<?php

declare(strict_types=1);

namespace PixelFocus\Api;

/**
 * Droits d'un utilisateur, calculés à partir de ses achats validés (table purchases).
 */
final class Entitlements
{
    public static function forUser(string $userId): array
    {
        $statement = Database::pdo()->prepare(
            'SELECT product_id, expires_at, revoked_at FROM purchases WHERE user_id = ?'
        );
        $statement->execute([$userId]);
        return self::compute($statement->fetchAll(), Database::now());
    }

    /**
     * @param array<int, array{product_id: string, expires_at: ?string, revoked_at: ?string}> $purchases
     */
    public static function compute(array $purchases, string $nowUtc): array
    {
        $premiumActive = false;
        $premiumExpiresAt = null;
        $lifetime = false;
        $purchasedBoosters = 0;
        $monthlyArtworkIds = [];
        $packIds = [];

        foreach ($purchases as $purchase) {
            if ($purchase['revoked_at'] !== null) {
                continue;
            }
            $productId = $purchase['product_id'];

            if (Products::isLifetime($productId)) {
                $lifetime = true;
                $premiumActive = true;
            } elseif (Products::isSubscription($productId)) {
                $expiresAt = $purchase['expires_at'];
                if ($expiresAt !== null && $expiresAt > $nowUtc) {
                    $premiumActive = true;
                    if ($premiumExpiresAt === null || $expiresAt > $premiumExpiresAt) {
                        $premiumExpiresAt = $expiresAt;
                    }
                }
            } elseif (($amount = Products::boosterAmount($productId)) > 0) {
                $purchasedBoosters += $amount;
            } elseif (($artworkId = Products::monthlyArtworkId($productId)) !== null) {
                $monthlyArtworkIds[$artworkId] = true;
            } elseif (($packId = Products::packId($productId)) !== null) {
                $packIds[$packId] = true;
            }
        }

        return [
            'premium' => [
                'active'    => $premiumActive,
                'lifetime'  => $lifetime,
                'expiresAt' => $lifetime ? null : Database::toIso($premiumExpiresAt),
            ],
            // Total acheté depuis le début (l'app déduit les boosters utilisés via les événements)
            'purchasedBoostersTotal' => $purchasedBoosters,
            'monthlyArtworkIds'      => array_keys($monthlyArtworkIds),
            'packIds'                => array_keys($packIds),
        ];
    }
}
