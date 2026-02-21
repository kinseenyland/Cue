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
        guard var token = SpotifyManager.shared.accessToken else {
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
            let refreshed = await SpotifyManager.shared.refreshAccessTokenIfNeeded()
            if refreshed, let newToken = SpotifyManager.shared.accessToken {
                request.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                (data, response) = try await URLSession.shared.data(for: request)
                statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            } else {
                // Refresh failed or no refresh token → clear token so user can reconnect
                await MainActor.run { SpotifyManager.shared.accessToken = nil }
                throw SpotifyError.tokenExpired
            }
        }

        guard statusCode == 200 else {
            throw SpotifyError.badResponse
        }

        let decoded = try JSONDecoder().decode(SearchResponse.self, from: data)
        return decoded.tracks.items
    }
    
    private struct SearchResponse: Codable {
        let tracks: TracksWrapper
        struct TracksWrapper: Codable { let items: [SpotifyTrack] }
    }
    
    enum SpotifyError: Error {
        case notAuthenticated
        case badResponse
        case tokenExpired
    }
}
