/*
 * APIClient.swift
 * PixelFocus
 *
 * Client HTTP de l'API PixelFocus (server/README.md).
 *
 * - JSON, dates ISO 8601, jeton "Authorization: Bearer"
 * - Aucune dépendance externe (URLSession)
 */

import Foundation

// MARK: - DTOs

struct APIEvent: Codable, Equatable {
    let id: String
    let type: String
    let artworkId: String?
    let payload: JSONValue?
    let occurredAt: String
}

struct APIAuthResponse: Decodable {
    let userId: String
    let token: String
    let firstLaunchAt: String
}

struct APIEventsResponse: Decodable {
    struct Rejected: Decodable {
        let id: String?
        let reason: String
    }
    let accepted: [String]
    let duplicates: [String]
    let rejected: [Rejected]
}

struct APIEntitlements: Decodable, Equatable {
    struct Premium: Decodable, Equatable {
        let active: Bool
        let expiresAt: String?
    }
    let premium: Premium
    let purchasedBoostersTotal: Int
    let monthlyArtworkIds: [String]
    let packIds: [String]
}

struct APIStateResponse: Decodable {
    struct User: Decodable {
        let id: String
        let firstLaunchAt: String
        let appleLinked: Bool
    }
    let user: User
    let events: [APIEvent]
    let cursor: Int
    let hasMore: Bool
    let entitlements: APIEntitlements
}

struct APIEntitlementsResponse: Decodable {
    let entitlements: APIEntitlements
}

struct APILinkResponse: Decodable {
    let userId: String
    let token: String?
    let merged: Bool
}

// MARK: - APIError

enum APIError: LocalizedError {
    case notConfigured
    case notAuthenticated
    case server(status: Int, code: String, message: String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "La synchronisation n'est pas encore configurée."
        case .notAuthenticated:
            return "Compte non connecté."
        case .server(_, _, let message):
            return message
        case .invalidResponse:
            return "Réponse du serveur illisible."
        }
    }

    var code: String? {
        if case .server(_, let code, _) = self { return code }
        return nil
    }
}

// MARK: - APIClient

struct APIClient {
    let baseURL: URL
    var token: String?
    var session: URLSession = .shared

    private struct ErrorBody: Decodable {
        struct Detail: Decodable {
            let code: String
            let message: String
        }
        let error: Detail
    }

    // MARK: - Routes

    func createAnonymous(firstLaunchAt: Date, deviceName: String?) async throws -> APIAuthResponse {
        var body: [String: Any] = [
            "platform": "ios",
            "firstLaunchAt": ISO8601DateFormatter.api.string(from: firstLaunchAt)
        ]
        if let deviceName {
            body["deviceName"] = deviceName
        }
        return try await send("POST", "/v1/auth/anonymous", body: body, authenticated: false)
    }

    func postEvents(_ events: [APIEvent]) async throws -> APIEventsResponse {
        try await send("POST", "/v1/events", encodable: ["events": events])
    }

    func getState(since cursor: Int) async throws -> APIStateResponse {
        try await send("GET", "/v1/state?since=\(cursor)")
    }

    func postApplePurchase(transactionId: String) async throws -> APIEntitlements {
        let response: APIEntitlementsResponse = try await send("POST", "/v1/purchases/apple", body: ["transactionId": transactionId])
        return response.entitlements
    }

    func linkApple(identityToken: String) async throws -> APILinkResponse {
        try await send("POST", "/v1/auth/link/apple", body: ["identityToken": identityToken])
    }

    func deleteAccount() async throws {
        struct Deleted: Decodable { let deleted: Bool }
        let _: Deleted = try await send("DELETE", "/v1/account")
    }

    // MARK: - Transport

    private func send<Response: Decodable>(
        _ method: String,
        _ path: String,
        body: [String: Any]? = nil,
        authenticated: Bool = true
    ) async throws -> Response {
        let data = try body.map { try JSONSerialization.data(withJSONObject: $0) }
        return try await perform(method, path, bodyData: data, authenticated: authenticated)
    }

    private func send<Body: Encodable, Response: Decodable>(
        _ method: String,
        _ path: String,
        encodable: Body
    ) async throws -> Response {
        try await perform(method, path, bodyData: try JSONEncoder().encode(encodable), authenticated: true)
    }

    private func perform<Response: Decodable>(
        _ method: String,
        _ path: String,
        bodyData: Data?,
        authenticated: Bool
    ) async throws -> Response {
        guard let url = URL(string: path, relativeTo: baseURL) else { throw APIError.invalidResponse }

        var request = URLRequest(url: url, timeoutInterval: 20)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let bodyData {
            request.httpBody = bodyData
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if authenticated {
            guard let token else { throw APIError.notAuthenticated }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }

        guard (200..<300).contains(http.statusCode) else {
            if let body = try? JSONDecoder().decode(ErrorBody.self, from: data) {
                throw APIError.server(status: http.statusCode, code: body.error.code, message: body.error.message)
            }
            throw APIError.server(status: http.statusCode, code: "http_\(http.statusCode)", message: "Erreur serveur (\(http.statusCode)).")
        }

        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw APIError.invalidResponse
        }
    }
}

// MARK: - Dates

extension ISO8601DateFormatter {
    /// Format des dates échangées avec l'API (ex: 2026-09-30T10:00:00.000Z)
    static let api: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
