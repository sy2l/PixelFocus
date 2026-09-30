/*
 * AppSchema.swift
 * PixelFocus
 *
 * Liste unique des modèles SwiftData (app, aperçus Xcode, tests).
 */

import SwiftData

enum AppSchema {
    static let models: [any PersistentModel.Type] = [
        SDArtwork.self,
        SDProgress.self,
        SDStreak.self,
        SDWallet.self,
        SDDailyQuota.self,
        SDMonthStats.self,
        SDActiveDay.self,
        SDBadge.self,
        SDEvent.self
    ]

    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let schema = Schema(models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Impossible de créer le ModelContainer: \(error)")
        }
    }
}
