//
//  SpotifySearchViewModel.swift
//  Cue
//
//  Created by IS 543 on 2/18/26.
//

import Foundation
import Combine

class SpotifySearchViewModel: ObservableObject {
    @Published var searchQuery = ""
    @Published var tracks: [SpotifySearchService.SpotifyTrack] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Create playlist flow
    @Published var newPlaylistName = ""
    @Published var isCreatingPlaylist = false
    @Published var createPlaylistError: String?
    @Published var currentPlaylist: SpotifySearchService.SpotifyPlaylist?
    @Published var isAddingTrack = false
    @Published var lastAddedTrackName: String?

    // Browse / edit existing playlist
    @Published var myPlaylists: [SpotifySearchService.SpotifyPlaylist] = []
    @Published var isLoadingPlaylists = false
    @Published var selectedPlaylistForEditing: SpotifySearchService.SpotifyPlaylist?
    @Published var playlistSnapshotId: String?
    @Published var playlistTracks: [SpotifySearchService.PlaylistTrackItem] = []
    @Published var isLoadingPlaylistTracks = false
    @Published var playlistEditError: String?

    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Debounce search so it waits 300ms after user stops typing
        $searchQuery
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .filter { !$0.isEmpty }
            .sink { [weak self] query in
                Task { await self?.search(query: query) }
            }
            .store(in: &cancellables)
    }
    
    @MainActor
    func search(query: String) async {
        isLoading = true
        errorMessage = nil
        do {
            tracks = try await SpotifySearchService.shared.searchTracks(query: query)
        } catch SpotifySearchService.SpotifyError.tokenExpired {
            errorMessage = "Session expired. Tap Connect to sign in again."
        } catch SpotifySearchService.SpotifyError.notAuthenticated {
            errorMessage = "Connect to Spotify to search."
        } catch {
            errorMessage = "Search failed. Make sure you're connected to Spotify."
        }
        isLoading = false
    }
    
    @MainActor
    func clear() {
        searchQuery = ""
        tracks = []
    }

    @MainActor
    func createPlaylist() async {
        let name = newPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            createPlaylistError = "Enter a playlist name."
            return
        }
        isCreatingPlaylist = true
        createPlaylistError = nil
        defer { isCreatingPlaylist = false }
        do {
            let playlist = try await SpotifySearchService.shared.createPlaylist(name: name, description: "Created with Cue", isPublic: true)
            currentPlaylist = playlist
            newPlaylistName = ""
        } catch SpotifySearchService.SpotifyError.notAuthenticated {
            createPlaylistError = "Connect to Spotify first."
        } catch SpotifySearchService.SpotifyError.tokenExpired {
            createPlaylistError = "Session expired. Tap Connect to sign in again."
        } catch SpotifySearchService.SpotifyError.apiError(let status, let message) {
            if status == 403 {
                createPlaylistError = "Playlist permission not granted. Sign out of Spotify in Cue and sign in again to allow creating playlists."
            } else {
                createPlaylistError = message ?? "Spotify returned an error (\(status)). Try again."
            }
        } catch {
            createPlaylistError = "Could not create playlist. Try again."
        }
    }

    @MainActor
    func addTrackToCurrentPlaylist(_ track: SpotifySearchService.SpotifyTrack) async {
        guard let playlist = currentPlaylist else { return }
        isAddingTrack = true
        lastAddedTrackName = nil
        defer { isAddingTrack = false }
        do {
            try await SpotifySearchService.shared.addTracksToPlaylist(playlistId: playlist.id, uris: [track.uri])
            lastAddedTrackName = track.name
        } catch {
            createPlaylistError = "Could not add \"\(track.name)\" to playlist."
        }
    }

    @MainActor
    func clearCurrentPlaylist() {
        currentPlaylist = nil
        lastAddedTrackName = nil
        createPlaylistError = nil
    }

    // MARK: - Browse / edit playlist

    @MainActor
    func loadMyPlaylists() async {
        guard SpotifyManager.shared.tokenForWebAPI != nil else { return }
        isLoadingPlaylists = true
        playlistEditError = nil
        defer { isLoadingPlaylists = false }
        do {
            myPlaylists = try await SpotifySearchService.shared.getMyPlaylists(limit: 50)
        } catch SpotifySearchService.SpotifyError.apiError(let status, let message) {
            if status == 403 {
                playlistEditError = "Playlist access needed. Tap \"Allow creating playlists\" again to grant list access."
            } else {
                playlistEditError = message ?? "Could not load playlists (\(status))."
            }
        } catch SpotifySearchService.SpotifyError.notAuthenticated {
            playlistEditError = "Connect to Spotify first."
        } catch SpotifySearchService.SpotifyError.tokenExpired {
            playlistEditError = "Session expired. Sign in again."
        } catch {
            playlistEditError = "Could not load playlists. Try again."
        }
    }

    @MainActor
    func selectPlaylistForEditing(_ playlist: SpotifySearchService.SpotifyPlaylist) async {
        #if DEBUG
        print("[Cue Spotify] selectPlaylistForEditing: id=\(playlist.id), name=\(playlist.name)")
        #endif
        selectedPlaylistForEditing = playlist
        playlistSnapshotId = nil
        playlistTracks = []
        playlistEditError = nil
        isLoadingPlaylistTracks = true
        defer { isLoadingPlaylistTracks = false }
        do {
            let (snapshotId, tracks) = try await SpotifySearchService.shared.getPlaylistWithTracks(playlistId: playlist.id)
            #if DEBUG
            print("[Cue Spotify] getPlaylistWithTracks returned: snapshotId=\(snapshotId ?? "nil"), tracks.count=\(tracks.count)")
            #endif
            playlistSnapshotId = snapshotId
            playlistTracks = tracks
            if tracks.isEmpty {
                #if DEBUG
                print("[Cue Spotify] tracks empty, trying getPlaylistTracks fallback...")
                #endif
                let more = try? await SpotifySearchService.shared.getPlaylistTracks(playlistId: playlist.id)
                #if DEBUG
                print("[Cue Spotify] getPlaylistTracks fallback: count=\(more?.count ?? 0)")
                #endif
                if let more, !more.isEmpty { playlistTracks = more }
            }
        } catch SpotifySearchService.SpotifyError.apiError(let status, let message) {
            #if DEBUG
            print("[Cue Spotify] selectPlaylistForEditing API error: status=\(status), message=\(message ?? "nil")")
            #endif
            if status == 403 {
                let hint = message.map { " (\($0))" } ?? ""
                playlistEditError = "Access denied\(hint). Try: Sign out, then Connect and \"Allow creating playlists\" again."
            } else {
                playlistEditError = message ?? "Could not load playlist (\(status))."
            }
            selectedPlaylistForEditing = nil
        } catch SpotifySearchService.SpotifyError.notAuthenticated {
            playlistEditError = "Tap \"Allow creating playlists\" to open playlists."
            selectedPlaylistForEditing = nil
        } catch SpotifySearchService.SpotifyError.tokenExpired {
            playlistEditError = "Session expired. Sign in again."
            selectedPlaylistForEditing = nil
        } catch let decodingErr as DecodingError {
            #if DEBUG
            print("[Cue Spotify] selectPlaylistForEditing decoding error: \(decodingErr)")
            #endif
            playlistEditError = "Could not read playlist data from Spotify."
            selectedPlaylistForEditing = nil
        } catch let err {
            #if DEBUG
            print("[Cue Spotify] selectPlaylistForEditing error: \(err)")
            #endif
            playlistEditError = "Could not load playlist. Try again."
            selectedPlaylistForEditing = nil
        }
    }

    @MainActor
    func closePlaylistEditor() {
        selectedPlaylistForEditing = nil
        playlistSnapshotId = nil
        playlistTracks = []
        playlistEditError = nil
    }

    @MainActor
    func addTrackToPlaylistBeingEdited(_ track: SpotifySearchService.SpotifyTrack) async {
        guard let playlist = selectedPlaylistForEditing else { return }
        playlistEditError = nil
        isAddingTrack = true
        lastAddedTrackName = nil
        defer { isAddingTrack = false }
        do {
            try await SpotifySearchService.shared.addTracksToPlaylist(playlistId: playlist.id, uris: [track.uri])
            lastAddedTrackName = track.name
            let newItem = SpotifySearchService.PlaylistTrackItem(track: track, position: playlistTracks.count)
            playlistTracks.append(newItem)
        } catch {
            playlistEditError = "Could not add \"\(track.name)\"."
        }
    }

    @MainActor
    func removeTrackFromPlaylist(_ item: SpotifySearchService.PlaylistTrackItem) async {
        guard let playlist = selectedPlaylistForEditing else { return }
        playlistEditError = nil
        do {
            let newSnapshot = try await SpotifySearchService.shared.removeTracksFromPlaylist(
                playlistId: playlist.id,
                uris: [item.track.uri],
                snapshotId: playlistSnapshotId
            )
            if let snap = newSnapshot { playlistSnapshotId = snap }
            playlistTracks.removeAll { $0.id == item.id }
            // Re-index positions after remove
            playlistTracks = playlistTracks.enumerated().map { SpotifySearchService.PlaylistTrackItem(track: $1.track, position: $0) }
        } catch {
            playlistEditError = "Could not remove \"\(item.track.name)\"."
        }
    }

    @MainActor
    func moveTrack(from sourceIndex: Int, to destinationIndex: Int) async {
        guard let playlist = selectedPlaylistForEditing else { return }
        guard sourceIndex != destinationIndex, sourceIndex >= 0, destinationIndex >= 0,
              sourceIndex < playlistTracks.count, destinationIndex < playlistTracks.count else { return }
        playlistEditError = nil
        let rangeStart = sourceIndex
        let insertBefore: Int = destinationIndex < sourceIndex ? destinationIndex : destinationIndex + 1
        do {
            let newSnapshot = try await SpotifySearchService.shared.reorderPlaylist(
                playlistId: playlist.id,
                rangeStart: rangeStart,
                insertBefore: insertBefore,
                rangeLength: 1,
                snapshotId: playlistSnapshotId
            )
            if let snap = newSnapshot { playlistSnapshotId = snap }
            var tracks = playlistTracks
            let item = tracks.remove(at: sourceIndex)
            let insertIdx = sourceIndex < destinationIndex ? destinationIndex - 1 : destinationIndex
            tracks.insert(item, at: insertIdx)
            playlistTracks = tracks.enumerated().map { SpotifySearchService.PlaylistTrackItem(track: $1.track, position: $0) }
        } catch {
            playlistEditError = "Could not move track."
        }
    }
}
