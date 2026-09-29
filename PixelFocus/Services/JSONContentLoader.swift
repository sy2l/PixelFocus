/*
 * JSONContentLoader.swift
 * PixelFocus
 *
 * Version: 1.0
 * Date: 15 janvier 2026
 *
 * Chargeur JSON (Bundle -> DTO).
 *
 * Objectifs:
 * - Centraliser la lecture JSON.
 * - Faciliter le passage à une source distante (API PHP) sans changer les DTO.
 */

import Foundation

// MARK: - JSONContentLoader
final class JSONContentLoader {
    
    // MARK: - Error Types
    enum LoaderError: Error, LocalizedError {
        case fileNotFound(String)
        case decodeFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .fileNotFound(let filename):
                return "Fichier non trouvé: \(filename)"
            case .decodeFailed(let details):
                return "Échec du décodage: \(details)"
            }
        }
    }

    // MARK: - Public Methods
    
    /// Charge un fichier JSON depuis le bundle principal
    func loadFromBundle<T: Decodable>(_ filename: String, as type: T.Type) throws -> T {
        guard let url = Bundle.main.url(forResource: filename, withExtension: nil) else {
            throw LoaderError.fileNotFound(filename)
        }

        let data = try Data(contentsOf: url)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw LoaderError.decodeFailed("\(filename): \(error)")
        }
    }
    
    /// Charge un fichier JSON depuis un sous-dossier du bundle.
    ///
    /// Le projet utilise des dossiers synchronisés Xcode: selon la configuration, les fichiers de
    /// `Resources/artworks/` sont copiés soit dans `artworks/`, soit à la racine du bundle.
    /// On cherche donc dans le sous-dossier, puis à la racine.
    func loadFromBundle<T: Decodable>(subfolder: String, filename: String, as type: T.Type) throws -> T {
        let fullPath = "\(subfolder)/\(filename)"
        let name = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension.isEmpty ? "json" : (filename as NSString).pathExtension

        let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: subfolder)
            ?? Bundle.main.url(forResource: name, withExtension: ext)

        guard let url else {
            throw LoaderError.fileNotFound(fullPath)
        }

        let data = try Data(contentsOf: url)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw LoaderError.decodeFailed("\(fullPath): \(error)")
        }
    }
}
