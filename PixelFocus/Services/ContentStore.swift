/*
 * ContentStore.swift
 * PixelFocus
 *
 * Version: 1.00
 * Date: 15 janvier 2026
 *
 * Store de contenu: ruleset + catalog + artworks.
 *
 * Objectifs:
 * - Exposer RulesetDTO et CatalogDTO en mémoire.
 * - Importer/mettre à jour SDArtwork via SwiftData.
 */

import Foundation
import SwiftData

// MARK: - ContentStore
@MainActor
final class ContentStore: ObservableObject {
    
    // MARK: - Published Properties
    @Published private(set) var ruleset: RulesetDTO?
    @Published private(set) var catalog: CatalogDTO?
    @Published private(set) var isLoaded: Bool = false
    @Published private(set) var loadError: String?

    // MARK: - Dependencies
    private let loader: JSONContentLoader
    private let modelContext: ModelContext

    // MARK: - Init
    init(loader: JSONContentLoader = JSONContentLoader(), modelContext: ModelContext) {
        self.loader = loader
        self.modelContext = modelContext
    }

    // MARK: - Public Methods
    
    /// Charge le contenu initial (ruleset + catalog)
    func loadInitialContent() throws {
        let loadedRuleset: RulesetDTO = try loader.loadFromBundle("ruleset.json", as: RulesetDTO.self)
        let loadedCatalog: CatalogDTO = try loader.loadFromBundle("catalog.json", as: CatalogDTO.self)

        ruleset = loadedRuleset
        catalog = loadedCatalog
        isLoaded = true
        loadError = nil
    }
    
    /// S'assure qu'une œuvre est importée dans SwiftData
    func ensureArtworkImported(artworkId: String) throws {
        // Vérifie si l'œuvre existe déjà
        if try fetchArtwork(artworkId: artworkId) != nil { return }

        // Charge depuis le bundle
        let dto: ArtworkDTO = try loader.loadFromBundle(
            subfolder: "artworks",
            filename: "\(artworkId).json",
            as: ArtworkDTO.self
        )
        
        // Encode les données pour SwiftData
        let paletteJSON = try JSONEncoder().encode(dto.palette)
        let pixelsJSON = try JSONEncoder().encode(dto.pixels.data)
        let revealJSON = try JSONEncoder().encode(dto.reveal.indexSequence)

        // Crée et insère le modèle SwiftData
        let sdArtwork = SDArtwork(
            artworkId: dto.artworkId,
            title: dto.title,
            mode: dto.mode,
            gridWidth: dto.grid.width,
            gridHeight: dto.grid.height,
            paletteJSON: paletteJSON,
            pixelsJSON: pixelsJSON,
            revealSequenceJSON: revealJSON
        )

        modelContext.insert(sdArtwork)
        try modelContext.save()
    }

    // MARK: - Fetch Methods
    
    /// Récupère une œuvre par son ID
    func fetchArtwork(artworkId: String) throws -> SDArtwork? {
        let descriptor = FetchDescriptor<SDArtwork>(
            predicate: #Predicate { $0.artworkId == artworkId }
        )
        return try modelContext.fetch(descriptor).first
    }
    
    /// Récupère toutes les œuvres
    func fetchAllArtworks() throws -> [SDArtwork] {
        let descriptor = FetchDescriptor<SDArtwork>()
        return try modelContext.fetch(descriptor)
    }
    
    /// Récupère les œuvres par mode (daily, weekly, monthly)
    func fetchArtworks(byMode mode: String) throws -> [SDArtwork] {
        let descriptor = FetchDescriptor<SDArtwork>(
            predicate: #Predicate { $0.mode == mode }
        )
        return try modelContext.fetch(descriptor)
    }
}
