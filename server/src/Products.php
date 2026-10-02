<?php

declare(strict_types=1);

namespace PixelFocus\Api;

/**
 * Catalogue des produits vendus (identiques sur l'App Store et le Play Store).
 * Doit rester aligné avec l'app iOS (Store/StoreProducts.swift) et GAME_DESIGN.md.
 */
final class Products
{
    public const PREFIX = 'com.sy2l.pixelfocus.';

    public const PREMIUM_MONTHLY = self::PREFIX . 'premium.monthly';
    public const PREMIUM_YEARLY = self::PREFIX . 'premium.yearly';

    /** Boosters (consommables): identifiant -> nombre de boosters */
    public const BOOSTERS = [
        self::PREFIX . 'boosters.1'  => 1,
        self::PREFIX . 'boosters.5'  => 5,
        self::PREFIX . 'boosters.15' => 15,
    ];

    public static function isSubscription(string $productId): bool
    {
        return in_array($productId, [self::PREMIUM_MONTHLY, self::PREMIUM_YEARLY], true);
    }

    public static function boosterAmount(string $productId): int
    {
        return self::BOOSTERS[$productId] ?? 0;
    }

    /**
     * Image du mois achetée à l'unité: "…monthly.2026_10" ou "…monthly.2026_10.reduced"
     * -> identifiant de l'œuvre "monthly_2026_10_main", sinon null.
     */
    public static function monthlyArtworkId(string $productId): ?string
    {
        if (preg_match('/^' . preg_quote(self::PREFIX, '/') . 'monthly\.(\d{4}_\d{2})(\.reduced)?$/', $productId, $m)) {
            return 'monthly_' . $m[1] . '_main';
        }
        return null;
    }

    /** Pack acheté: "…pack.<id>" ou "…pack.<id>.archive" -> "<id>", sinon null */
    public static function packId(string $productId): ?string
    {
        if (preg_match('/^' . preg_quote(self::PREFIX, '/') . 'pack\.([a-z0-9_]+?)(\.archive)?$/', $productId, $m)) {
            return $m[1];
        }
        return null;
    }

    public static function isKnown(string $productId): bool
    {
        return self::isSubscription($productId)
            || self::boosterAmount($productId) > 0
            || self::monthlyArtworkId($productId) !== null
            || self::packId($productId) !== null;
    }
}
