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

    /// Playlist with snapshot_id for remove/reorder operations.
    struct PlaylistDetails: Codable {
        let id: String
        let name: String?
        let snapshotId: String?
        enum CodingKeys: String, CodingKey {
            case id, name
            case snapshotId = "snapshot_id"
        }
    }

    /// A track in a playlist (position = index when loaded).
    struct PlaylistTrackItem: Identifiable {
        let track: SpotifyTrack
        let position: Int
        var id: String { track.id }
    }

    struct SpotifyTrack: Codable, Identifiable {
        let id: String
        let name: String
        let uri: String
        let durationMs: Int
        let artists: [Artist]
        let album: Album

        init(id: String, name: String, uri: String, durationMs: Int = 0, artists: [Artist] = [], album: Album = Album(name: nil, images: nil)) {
            self.id = id
            self.name = name
            self.uri = uri
            self.durationMs = durationMs
            self.artists = artists
            self.album = album
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(String.self, forKey: .id)
            name = try c.decode(String.self, forKey: .name)
            uri = try c.decode(String.self, forKey: .uri)
            durationMs = (try c.decodeIfPresent(Int.self, forKey: .durationMs)) ?? 0
            artists = (try c.decodeIfPresent([Artist].self, forKey: .artists)) ?? []
            album = (try c.decodeIfPresent(Album.self, forKey: .album)) ?? Album(name: nil, images: nil)
        }

        var durationSeconds: Int { durationMs / 1000 }
        var durationFormatted: String {
            let mins = durationSeconds / 60
            let secs = durationSeconds % 60
            return String(format: "%d:%02d", mins, secs)
        }
        var artistName: String { artists.first?.name ?? "" }
        var albumArtURL: URL? { URL(string: album.images?.first?.url ?? "") }

        struct Artist: Codable { let name: String }
        struct Album: Codable {
            let name: String?
            let images: [SpotifyImage]?
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

    /// Add tracks to a playlist. URIs should be like "spotify:track:...". Uses POST /playlists/{id}/items.
    /// Viewing playlist content uses the same resource: GET /playlists/{id} (embeds items) or GET /playlists/{id}/items (paginated).
    func addTracksToPlaylist(playlistId: String, uris: [String]) async throws {
        guard !uris.isEmpty else { return }
        var request = URLRequest(url: URL(string: "\(baseURL)/playlists/\(playlistId)/items")!)
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

    /// Fetch current user's playlists. GET /me/playlists. Uses API token only (playlist-read scope).
    func getMyPlaylists(limit: Int = 50, offset: Int = 0) async throws -> [SpotifyPlaylist] {
        var components = URLComponents(string: "\(baseURL)/me/playlists")!
        components.queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ]
        var request = URLRequest(url: components.url!)
        try await setAuthForPlaylistRead(request: &request)
        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as? HTTPURLResponse
        let statusCode = httpResponse?.statusCode ?? -1
        if statusCode == 401 {
            let refreshed = await SpotifyManager.shared.refreshWebAPITokenIfNeeded()
            if refreshed { return try await getMyPlaylists(limit: limit, offset: offset) }
            await MainActor.run { SpotifyManager.shared.clearWebAPICredentialsOnRefreshFailure() }
            throw SpotifyError.tokenExpired
        }
        guard statusCode == 200 else {
            if statusCode == 429 {
                // Rate limited: read Retry-After so UI can tell user how long to wait.
                let retryHeader = httpResponse?.value(forHTTPHeaderField: "Retry-After")
                if let retryHeader,
                   let seconds = Int(retryHeader), seconds > 0 {
                    let msg = "Could not load playlists (429). Too many requests. Try again in about \(seconds) seconds."
                    throw SpotifyError.apiError(status: statusCode, message: msg)
                } else {
                    let msg = "Could not load playlists (429). Too many requests. Please wait and try again."
                    throw SpotifyError.apiError(status: statusCode, message: msg)
                }
            }
            let msg = (try? JSONDecoder().decode(SpotifyErrorPayload.self, from: data)).flatMap { $0.error?.message }
            throw SpotifyError.apiError(status: statusCode, message: msg)
        }
        let decoded = try JSONDecoder().decode(PlaylistsResponse.self, from: data)
        return decoded.items
    }

    /// Get playlist details including snapshot_id (for remove/reorder). GET /playlists/{id}. Uses cached user country for market when available.
    func getPlaylistDetails(playlistId: String) async throws -> PlaylistDetails {
        var components = URLComponents(string: "\(baseURL)/playlists/\(playlistId)")!
        if let market = cachedUserCountry, !market.isEmpty {
            components.queryItems = [URLQueryItem(name: "market", value: market)]
        }
        var request = URLRequest(url: components.url!)
        try await setAuthForPlaylistRead(request: &request)
        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        if statusCode == 401 {
            let refreshed = await SpotifyManager.shared.refreshWebAPITokenIfNeeded()
            if refreshed { return try await getPlaylistDetails(playlistId: playlistId) }
            await MainActor.run { SpotifyManager.shared.clearWebAPICredentialsOnRefreshFailure() }
            throw SpotifyError.tokenExpired
        }
        guard statusCode == 200 else {
            let msg = (try? JSONDecoder().decode(SpotifyErrorPayload.self, from: data)).flatMap { $0.error?.message }
            throw SpotifyError.apiError(status: statusCode, message: msg)
        }
        return try JSONDecoder().decode(PlaylistDetails.self, from: data)
    }

    /// User's country from /me (for market parameter). Cached for the session.
    private var cachedUserCountry: String?

    /// Load playlist and its tracks in one request. GET /playlists/{id}?fields=... avoids separate /tracks call (which can 403). Returns (snapshotId, tracks).
    func getPlaylistWithTracks(playlistId: String) async throws -> (snapshotId: String?, tracks: [PlaylistTrackItem]) {
        if cachedUserCountry == nil {
            cachedUserCountry = (try? await getCurrentUserCountry()) ?? nil
        }
        var components = URLComponents(string: "\(baseURL)/playlists/\(playlistId)")!
        // No fields filter: get full playlist so response has standard tracks.items shape (field filtering can change structure).
        if let market = cachedUserCountry, !market.isEmpty {
            components.queryItems = [URLQueryItem(name: "market", value: market)]
        }
        var request = URLRequest(url: components.url!)
        try await setAuthForPlaylistRead(request: &request)
        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        if statusCode == 401 {
            let refreshed = await SpotifyManager.shared.refreshWebAPITokenIfNeeded()
            if refreshed { return try await getPlaylistWithTracks(playlistId: playlistId) }
            await MainActor.run { SpotifyManager.shared.clearWebAPICredentialsOnRefreshFailure() }
            throw SpotifyError.tokenExpired
        }
        guard statusCode == 200 else {
            let msg = (try? JSONDecoder().decode(SpotifyErrorPayload.self, from: data)).flatMap { $0.error?.message }
            #if DEBUG
            print("[Cue Spotify] getPlaylistWithTracks(\(playlistId)) HTTP \(statusCode): \(msg ?? "no message")")
            #endif
            throw SpotifyError.apiError(status: statusCode, message: msg)
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let snapshotId = json?["snapshot_id"] as? String
        #if DEBUG
        let topLevelKeys = json?.keys.sorted() ?? []
        let tracksKey = json?["tracks"]
        let tracksType = tracksKey == nil ? "nil" : (tracksKey is [String: Any] ? "object" : (tracksKey is [[String: Any]] ? "array" : "other"))
        print("[Cue Spotify] getPlaylistWithTracks(\(playlistId)) response keys: \(topLevelKeys), tracks type: \(tracksType)")
        if let itemsVal = json?["items"] {
            let itemsType = type(of: itemsVal)
            let isNull = itemsVal is NSNull
            if let arr = itemsVal as? [Any] {
                print("[Cue Spotify] response 'items': type=\(itemsType), isArray count=\(arr.count), firstKeys=\((arr.first as? [String: Any])?.keys.sorted().prefix(5).map { String(describing: $0) } ?? [])")
            } else {
                print("[Cue Spotify] response 'items': type=\(itemsType), isNSNull=\(isNull)")
            }
        }
        if let rawString = String(data: data, encoding: .utf8), rawString.count > 500 {
            let snippet = String(rawString.prefix(2500))
            print("[Cue Spotify] response body snippet (first 2500 chars):\n\(snippet)...")
        }
        #endif
        let entries = try parsePlaylistTrackEntries(data: data)
        let tracks = entries.enumerated().compactMap { idx, entry -> PlaylistTrackItem? in
            guard let track = entry.track else { return nil }
            return PlaylistTrackItem(track: track, position: idx)
        }
        #if DEBUG
        print("[Cue Spotify] getPlaylistWithTracks(\(playlistId)) parsed entries=\(entries.count), tracks=\(tracks.count)")
        #endif
        return (snapshotId, tracks)
    }

    /// Get tracks in a playlist. Uses the same resource as add/remove/reorder: GET /playlists/{id}/items first, then GET .../tracks if 404.
    func getPlaylistTracks(playlistId: String) async throws -> [PlaylistTrackItem] {
        if cachedUserCountry == nil {
            cachedUserCountry = (try? await getCurrentUserCountry()) ?? nil
        }
        do {
            return try await fetchPlaylistTracksPage(playlistId: playlistId, path: "items", market: cachedUserCountry)
        } catch SpotifyError.apiError(let status, _) where status == 404 {
            return try await fetchPlaylistTracksPage(playlistId: playlistId, path: "tracks", market: cachedUserCountry)
        }
    }

    private func getCurrentUserCountry() async throws -> String? {
        var request = URLRequest(url: URL(string: "\(baseURL)/me")!)
        try await setAuthAndRefreshIfNeeded(request: &request)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return json?["country"] as? String
    }

    private func fetchPlaylistTracksPage(playlistId: String, path: String, market: String? = nil) async throws -> [PlaylistTrackItem] {
        var allItems: [PlaylistTrackItem] = []
        var offset = 0
        let limit = 50
        while true {
            var components = URLComponents(string: "\(baseURL)/playlists/\(playlistId)/\(path)")!
            var queryItems = [
                URLQueryItem(name: "limit", value: "\(limit)"),
                URLQueryItem(name: "offset", value: "\(offset)")
            ]
            if let market = market, !market.isEmpty {
                queryItems.append(URLQueryItem(name: "market", value: market))
            }
            components.queryItems = queryItems
            var request = URLRequest(url: components.url!)
            try await setAuthForPlaylistRead(request: &request)
            let (data, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            if statusCode == 401 {
                let refreshed = await SpotifyManager.shared.refreshWebAPITokenIfNeeded()
                if refreshed { return try await fetchPlaylistTracksPage(playlistId: playlistId, path: path, market: market) }
                await MainActor.run { SpotifyManager.shared.clearWebAPICredentialsOnRefreshFailure() }
                throw SpotifyError.tokenExpired
            }
            guard statusCode == 200 else {
                let msg = (try? JSONDecoder().decode(SpotifyErrorPayload.self, from: data)).flatMap { $0.error?.message }
                throw SpotifyError.apiError(status: statusCode, message: msg)
            }
            let entries = try parsePlaylistTrackEntries(data: data)
            let pageItems = entries.enumerated().compactMap { idx, entry -> PlaylistTrackItem? in
                guard let track = entry.track else { return nil }
                return PlaylistTrackItem(track: track, position: offset + idx)
            }
            allItems.append(contentsOf: pageItems)
            if pageItems.count < limit { break }
            offset += limit
        }
        return allItems
    }

    /// Decode playlist items from { "items": [...] }, { "tracks": { "items": [...] } }, or { "tracks": [ ... ] } (array).
    private func parsePlaylistTrackEntries(data: Data) throws -> [PlaylistTrackEntry] {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let rawItems: [[String: Any]]?
        let source: String

        func itemsFromTopLevel() -> ([[String: Any]], String)? {
            guard let raw = json?["items"] else {
                #if DEBUG
                print("[Cue Spotify] parsePlaylistTrackEntries: no 'items' key")
                #endif
                return nil
            }
            if raw is NSNull {
                #if DEBUG
                print("[Cue Spotify] parsePlaylistTrackEntries: 'items' is NSNull → empty")
                #endif
                return ([], "items")
            }
            // Top-level "items" can be the array directly, or a paging object { "items": [...], "total", ... }
            if let items = raw as? [[String: Any]] { return (items, "items") }
            if let itemsAny = raw as? [Any] {
                let converted = itemsAny.compactMap { $0 as? [String: Any] }
                #if DEBUG
                print("[Cue Spotify] parsePlaylistTrackEntries: 'items' as [Any] count=\(itemsAny.count) → converted=\(converted.count)")
                #endif
                return (converted, "items")
            }
            if let ns = raw as? NSArray {
                let converted = ns.compactMap { $0 as? [String: Any] }
                #if DEBUG
                print("[Cue Spotify] parsePlaylistTrackEntries: 'items' as NSArray count=\(ns.count) → converted=\(converted.count)")
                #endif
                return (converted, "items")
            }
            // Spotify new API: top-level "items" is a paging object; the array is at items.items
            if let itemsObj = raw as? [String: Any],
               let inner = itemsObj["items"] as? [[String: Any]] {
                #if DEBUG
                print("[Cue Spotify] parsePlaylistTrackEntries: 'items' is paging object, items.items count=\(inner.count)")
                #endif
                return (inner, "items.items")
            }
            if let itemsObj = raw as? [String: Any], let innerAny = itemsObj["items"] as? [Any] {
                let converted = innerAny.compactMap { $0 as? [String: Any] }
                #if DEBUG
                print("[Cue Spotify] parsePlaylistTrackEntries: 'items' is paging object, items.items [Any] count=\(converted.count)")
                #endif
                return (converted, "items.items")
            }
            if let itemsObj = raw as? NSDictionary, let inner = itemsObj["items"] as? NSArray {
                let converted = inner.compactMap { $0 as? [String: Any] }
                #if DEBUG
                print("[Cue Spotify] parsePlaylistTrackEntries: 'items' is paging object (NS), items.items count=\(converted.count)")
                #endif
                return (converted, "items.items")
            }
            #if DEBUG
            print("[Cue Spotify] parsePlaylistTrackEntries: 'items' type=\(type(of: raw)), could not extract array")
            #endif
            return nil
        }

        if let (items, src) = itemsFromTopLevel() {
            rawItems = items
            source = src
        } else if let tracksObj = json?["tracks"] as? [String: Any], let items = tracksObj["items"] as? [[String: Any]] {
            rawItems = items
            source = "tracks.items"
        } else if let tracksObj = json?["tracks"] as? [String: Any], let itemsAny = tracksObj["items"] as? [Any] {
            rawItems = itemsAny.compactMap { $0 as? [String: Any] }
            source = "tracks.items"
        } else if let tracksArr = json?["tracks"] as? [[String: Any]] {
            rawItems = tracksArr
            source = "tracks[]"
        } else {
            rawItems = nil
            source = "none"
        }
        #if DEBUG
        print("[Cue Spotify] parsePlaylistTrackEntries: source=\(source), rawItems.count=\(rawItems?.count ?? 0)")
        #endif
        guard let rawItems else {
            let fallback = (try? JSONDecoder().decode(PlaylistTracksResponse.self, from: data))?.items ?? []
            #if DEBUG
            print("[Cue Spotify] parsePlaylistTrackEntries: using fallback decoder, count=\(fallback.count)")
            #endif
            return fallback
        }
        let decoder = JSONDecoder()
        var decodeFailCount = 0
        let result = rawItems.compactMap { item -> PlaylistTrackEntry? in
            // Old API: { "track": { ... } } or { "track": null }. New API: { "item": { ... } } (track object).
            if let trackObj = item["track"] as? [String: Any], !trackObj.isEmpty {
                if let track = try? decodeTrack(from: trackObj, decoder: decoder) {
                    return PlaylistTrackEntry(track: track)
                }
                decodeFailCount += 1
                return nil
            }
            if item["track"] == nil || item["track"] is NSNull, item["item"] == nil || item["item"] is NSNull {
                return PlaylistTrackEntry(track: nil)
            }
            // New API: track is under "item"
            if let itemObj = item["item"] as? [String: Any], !itemObj.isEmpty {
                if let track = try? decodeTrack(from: itemObj, decoder: decoder) {
                    return PlaylistTrackEntry(track: track)
                }
                decodeFailCount += 1
                return nil
            }
            if let track = try? decodeTrack(from: item, decoder: decoder) {
                return PlaylistTrackEntry(track: track)
            }
            decodeFailCount += 1
            return nil
        }
        #if DEBUG
        if decodeFailCount > 0 {
            print("[Cue Spotify] parsePlaylistTrackEntries: \(decodeFailCount) item(s) failed track decode, result.count=\(result.count)")
        }
        #endif
        return result
    }

    private func decodeTrack(from dict: [String: Any], decoder: JSONDecoder) throws -> SpotifyTrack? {
        let data = try JSONSerialization.data(withJSONObject: dict)
        do {
            return try decoder.decode(SpotifyTrack.self, from: data)
        } catch {
            #if DEBUG
            let keys = dict.keys.sorted()
            print("[Cue Spotify] decodeTrack failed: keys=\(keys), error=\(error)")
            #endif
            return nil
        }
    }

    /// Remove items from a playlist. DELETE /playlists/{id}/items. Body: { "items": [{ "uri": "..." }] }, optional snapshot_id.
    func removeTracksFromPlaylist(playlistId: String, uris: [String], snapshotId: String?) async throws -> String? {
        guard !uris.isEmpty else { return snapshotId }
        var request = URLRequest(url: URL(string: "\(baseURL)/playlists/\(playlistId)/items")!)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await setAuthAndRefreshIfNeeded(request: &request)
        var body: [String: Any] = [
            "items": uris.map { ["uri": $0] }
        ]
        if let snap = snapshotId { body["snapshot_id"] = snap }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        if statusCode == 401 {
            let refreshed = await SpotifyManager.shared.refreshWebAPITokenIfNeeded()
            if refreshed { return try await removeTracksFromPlaylist(playlistId: playlistId, uris: uris, snapshotId: snapshotId) }
            await MainActor.run { SpotifyManager.shared.clearWebAPICredentialsOnRefreshFailure() }
            throw SpotifyError.tokenExpired
        }
        guard statusCode == 200 else {
            let msg = (try? JSONDecoder().decode(SpotifyErrorPayload.self, from: data)).flatMap { $0.error?.message }
            throw SpotifyError.apiError(status: statusCode, message: msg)
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return json?["snapshot_id"] as? String
    }

    /// Reorder items in a playlist. PUT /playlists/{id}/items. Body: range_start, insert_before, range_length, optional snapshot_id.
    func reorderPlaylist(playlistId: String, rangeStart: Int, insertBefore: Int, rangeLength: Int = 1, snapshotId: String?) async throws -> String? {
        var request = URLRequest(url: URL(string: "\(baseURL)/playlists/\(playlistId)/items")!)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await setAuthAndRefreshIfNeeded(request: &request)
        var body: [String: Any] = [
            "range_start": rangeStart,
            "insert_before": insertBefore,
            "range_length": rangeLength
        ]
        if let snap = snapshotId { body["snapshot_id"] = snap }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        if statusCode == 401 {
            let refreshed = await SpotifyManager.shared.refreshWebAPITokenIfNeeded()
            if refreshed { return try await reorderPlaylist(playlistId: playlistId, rangeStart: rangeStart, insertBefore: insertBefore, rangeLength: rangeLength, snapshotId: snapshotId) }
            await MainActor.run { SpotifyManager.shared.clearWebAPICredentialsOnRefreshFailure() }
            throw SpotifyError.tokenExpired
        }
        guard statusCode == 200 else {
            let msg = (try? JSONDecoder().decode(SpotifyErrorPayload.self, from: data)).flatMap { $0.error?.message }
            throw SpotifyError.apiError(status: statusCode, message: msg)
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return json?["snapshot_id"] as? String
    }

    private func setAuthAndRefreshIfNeeded(request: inout URLRequest) async throws {
        guard let token = SpotifyManager.shared.tokenForWebAPI else {
            throw SpotifyError.notAuthenticated
        }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    /// Use only the API (browser) token for playlist read. Playback token has no playlist-read scope and returns 403.
    private func setAuthForPlaylistRead(request: inout URLRequest) async throws {
        guard let token = SpotifyManager.shared.tokenForPlaylistRead else {
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

    private struct PlaylistsResponse: Codable {
        let items: [SpotifyPlaylist]
    }

    private struct PlaylistWithItemsResponse: Decodable {
        let snapshotId: String?
        /// tracks.items can be either array directly or { items: [...] } wrapper
        let itemEntries: [PlaylistTrackEntry]
        enum CodingKeys: String, CodingKey {
            case tracks
            case snapshotId = "snapshot_id"
        }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            snapshotId = try c.decodeIfPresent(String.self, forKey: .snapshotId)
            // Try decoding tracks as a bare array
            if let arr = try? c.decode([PlaylistTrackEntry].self, forKey: .tracks) {
                itemEntries = arr
            } else if let wrapper = try? c.decode(ItemsWrapper.self, forKey: .tracks) {
                itemEntries = wrapper.items
            } else {
                itemEntries = []
            }
        }
        struct ItemsWrapper: Decodable { let items: [PlaylistTrackEntry] }
    }

    private struct PlaylistTracksResponse: Codable {
        let items: [PlaylistTrackEntry]
    }

    private struct PlaylistTrackEntry: Codable {
        let track: SpotifyTrack?
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
