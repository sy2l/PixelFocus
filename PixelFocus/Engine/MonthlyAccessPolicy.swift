/*
 * MonthlyAccessPolicy.swift
 * PixelFocus
 *
 * Règles pures d'accès à l'image du mois (voir GAME_DESIGN.md §2).
 *
 * Accès accordé si (dans cet ordre):
 * 1. l'image a été achetée à l'unité;
 * 2. c'est l'image offerte à l'installation (1er lancement avant le 25 -> mois en cours, sinon mois suivant);
 * 3. le défi du mois est réussi (N sessions terminées dans ce mois);
 * 4. Premium actif: mois en cours, ou mois précédent jusqu'au 7 inclus;
 * 5. Premium terminé: l'image du mois de la résiliation reste jouable jusqu'à la fin de ce mois.
 *
 * Prix à l'unité: réduit si progression > 50 % et achat avant le 8 du mois suivant, sinon plein tarif.
 *
 * Aucune dépendance SwiftData: testable unitairement.
 */

import Foundation

// MARK: - PremiumStatus
struct PremiumStatus: Equatable {
    var isActive: Bool
    /// Date de fin du dernier abonnement (nil si jamais résilié ou actif)
    var lapsedAt: Date?

    static let none = PremiumStatus(isActive: false, lapsedAt: nil)
}

// MARK: - MonthlyAccess
enum MonthlyAccessReason: Equatable {
    case purchased
    case welcomeGift
    case challenge
    case premium
    case premiumPreviousMonthGrace
    case premiumLapseGift
}

enum MonthlyAccess: Equatable {
    case granted(MonthlyAccessReason)
    case locked

    var isGranted: Bool {
        if case .granted = self { return true }
        return false
    }
}

// MARK: - MonthlyPriceTier
enum MonthlyPriceTier: Equatable {
    /// 0,99 €
    case reduced
    /// 1,99 €
    case full
}

// MARK: - MonthlyAccessPolicy
enum MonthlyAccessPolicy {

    /// Mois de l'image offerte à l'installation.
    static func welcomeMonthISO(
        firstLaunch: Date,
        rules: MonthlyAccessRulesDTO,
        calendar: Calendar = .current
    ) -> String {
        let firstLaunchMonth = DatePolicy.isoMonthString(for: firstLaunch, calendar: calendar)
        let day = calendar.component(.day, from: firstLaunch)
        if day < rules.welcomeCutoffDay {
            return firstLaunchMonth
        }
        return DatePolicy.monthISO(firstLaunchMonth, offsetBy: 1, calendar: calendar) ?? firstLaunchMonth
    }

    /// Accès à l'image du mois `monthISO` à la date `now`.
    static func access(
        monthISO: String,
        now: Date,
        firstLaunch: Date,
        premium: PremiumStatus,
        isPurchased: Bool,
        completedSessionsInMonth: Int,
        rules: MonthlyAccessRulesDTO,
        calendar: Calendar = .current
    ) -> MonthlyAccess {
        if isPurchased {
            return .granted(.purchased)
        }

        if monthISO == welcomeMonthISO(firstLaunch: firstLaunch, rules: rules, calendar: calendar) {
            return .granted(.welcomeGift)
        }

        if completedSessionsInMonth >= rules.challengeSessions {
            return .granted(.challenge)
        }

        let currentMonth = DatePolicy.isoMonthString(for: now, calendar: calendar)

        if premium.isActive {
            if monthISO == currentMonth {
                return .granted(.premium)
            }
            let previousMonth = DatePolicy.monthISO(currentMonth, offsetBy: -1, calendar: calendar)
            let day = calendar.component(.day, from: now)
            if monthISO == previousMonth && day <= rules.premiumPreviousMonthGraceDay {
                return .granted(.premiumPreviousMonthGrace)
            }
            return .locked
        }

        if let lapsedAt = premium.lapsedAt {
            let lapseMonth = DatePolicy.isoMonthString(for: lapsedAt, calendar: calendar)
            if monthISO == lapseMonth && currentMonth == lapseMonth {
                return .granted(.premiumLapseGift)
            }
        }

        return .locked
    }

    /// Palier de prix à l'unité pour l'image du mois `monthISO`.
    /// - revealedRatio: progression de l'utilisateur sur cette image (0...1)
    static func unitPriceTier(
        monthISO: String,
        now: Date,
        revealedRatio: Double,
        rules: MonthlyAccessRulesDTO,
        calendar: Calendar = .current
    ) -> MonthlyPriceTier {
        guard revealedRatio > rules.reducedPriceProgressThreshold,
              let nextMonth = DatePolicy.monthISO(monthISO, offsetBy: 1, calendar: calendar),
              let nextMonthStart = DatePolicy.firstDayOfMonth(nextMonth, calendar: calendar),
              let reducedPriceEnd = calendar.date(
                byAdding: .day,
                value: rules.reducedPriceUntilDayOfNextMonth,
                to: nextMonthStart
              ) else {
            return .full
        }
        // reducedPriceEnd = le (N+1) du mois suivant à 00:00 -> réduit jusqu'au N inclus
        return now < reducedPriceEnd ? .reduced : .full
    }
}
