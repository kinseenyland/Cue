//
//  SpotifySearchService.swift
//  Cue
//
//  Created by IS 543 on 2/18/26.
//

import Foundation

class SpotifySearchService {
    static let shared = SpotifySearchService()
    private let baseURL = "https://api.spotify.com/v1"
    
    struct SpotifyPlaylist: Codable {
        let id: String
        let name: String
        let uri: String
    }

    struct SpotifyTrack: Codable, Identifiable {
        let id: String
        let name: String
        let uri: String
        let durationMs: Int
        let artists: [Artist]
        let album: Album
        
        var durationSeconds: Int { durationMs / 1000 }
        var durationFormatted: String {
            let mins = durationSeconds / 60
            let secs = durationSeconds % 60
            return String(format: "%d:%02d", mins, secs)
        }
        var artistName: String { artists.first?.name ?? "" }
        var albumArtURL: URL? { URL(string: album.images.first?.url ?? "") }
        
        struct Artist: Codable { let name: String }
        struct Album: Codable {
            let name: String
            let images: [SpotifyImage]
        }
        struct SpotifyImage: Codable { let url: String }
        
        enum CodingKeys: String, CodingKey {
            case id, name, uri, artists, album
            case durationMs = "duration_ms"
        }
    }
    
    func searchTracks(query: String) async throws -> [SpotifyTrack] {
        guard var token = SpotifyManager.shared.tokenForWebAPI else {
            throw SpotifyError.notAuthenticated
        }

        var components = URLComponents(string: "\(baseURL)/search")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "type", value: "track"),
            URLQueryItem(name: "limit", value: "10") // Spotify Search API allows 0-10 only
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        var (data, response) = try await URLSession.shared.data(for: request)
        var statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1

        // Token expired (401) → refresh and retry once
        if statusCode == 401 {
            let refreshed = await SpotifyManager.shared.refreshWebAPITokenIfNeeded()
            if refreshed, let newToken = SpotifyManager.shared.tokenForWebAPI {
                request.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                (data, response) = try await URLSession.shared.data(for: request)
                statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            } else {
                await MainActor.run { SpotifyManager.shared.clearWebAPICredentialsOnRefreshFailure() }
                throw SpotifyError.tokenExpired
            }
        }

        guard statusCode == 200 else {
            throw SpotifyError.badResponse
        }

        let decoded = try JSONDecoder().decode(SearchResponse.self, from: data)
        return decoded.tracks.items
    }

    /// Current user's Spotify ID (needed for creating playlists).
    func getCurrentUserId() async throws -> String {
        var request = URLRequest(url: URL(string: "\(baseURL)/me")!)
        try await setAuthAndRefreshIfNeeded(request: &request)
        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        if statusCode == 401 {
            try await handle401AndRetryGetUserId()
            return try await getCurrentUserId()
        }
        if statusCode != 200 {
            let msg = (try? JSONDecoder().decode(SpotifyErrorPayload.self, from: data)).flatMap { $0.error?.message }
            throw SpotifyError.apiError(status: statusCode, message: msg)
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let id = json?["id"] as? String else { throw SpotifyError.badResponse }
        return id
    }

    /// Create a playlist for the current user. Uses POST /me/playlists (no user_id). Requires playlist-modify-public or playlist-modify-private.
    func createPlaylist(name: String, description: String? = nil, isPublic: Bool = true) async throws -> SpotifyPlaylist {
        var request = URLRequest(url: URL(string: "\(baseURL)/me/playlists")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await setAuthAndRefreshIfNeeded(request: &request)
        let body: [String: Any] = [
            "name": name,
            "description": description ?? "",
            "public": isPublic
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        if statusCode == 401 {
            let refreshed = await SpotifyManager.shared.refreshWebAPITokenIfNeeded()
            if refreshed { return try await createPlaylist(name: name, description: description, isPublic: isPublic) }
            await MainActor.run { SpotifyManager.shared.clearWebAPICredentialsOnRefreshFailure() }
            throw SpotifyError.tokenExpired
        }
        if statusCode != 201 {
            let msg = (try? JSONDecoder().decode(SpotifyErrorPayload.self, from: data)).flatMap { $0.error?.message }
            throw SpotifyError.apiError(status: statusCode, message: msg)
        }
        let decoded = try JSONDecoder().decode(SpotifyPlaylist.self, from: data)
        return decoded
    }

    /// Add tracks to a playlist. URIs should be like "spotify:track:...".
    func addTracksToPlaylist(playlistId: String, uris: [String]) async throws {
        guard !uris.isEmpty else { return }
        var request = URLRequest(url: URL(string: "\(baseURL)/playlists/\(playlistId)/tracks")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await setAuthAndRefreshIfNeeded(request: &request)
        let body = ["uris": uris] as [String: Any]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        if statusCode == 401 {
            let refreshed = await SpotifyManager.shared.refreshWebAPITokenIfNeeded()
            if refreshed { try await addTracksToPlaylist(playlistId: playlistId, uris: uris); return }
            await MainActor.run { SpotifyManager.shared.clearWebAPICredentialsOnRefreshFailure() }
            throw SpotifyError.tokenExpired
        }
        guard statusCode == 201 else { throw SpotifyError.badResponse }
    }

    private func setAuthAndRefreshIfNeeded(request: inout URLRequest) async throws {
        guard let token = SpotifyManager.shared.tokenForWebAPI else {
            throw SpotifyError.notAuthenticated
        }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    private func handle401AndRetryGetUserId() async throws {
        let refreshed = await SpotifyManager.shared.refreshWebAPITokenIfNeeded()
        if !refreshed {
            await MainActor.run { SpotifyManager.shared.clearWebAPICredentialsOnRefreshFailure() }
            throw SpotifyError.tokenExpired
        }
    }
    
    private struct SearchResponse: Codable {
        let tracks: TracksWrapper
        struct TracksWrapper: Codable { let items: [SpotifyTrack] }
    }
    
    enum SpotifyError: Error {
        case notAuthenticated
        case badResponse
        case tokenExpired
        /// API returned non-success; status and message from response body when available.
        case apiError(status: Int, message: String?)
    }
}

/// Spotify error response body: { "error": { "status": 403, "message": "..." } }
private struct SpotifyErrorPayload: Codable {
    let error: Inner?
    struct Inner: Codable {
        let status: Int?
        let message: String?
    }
}
