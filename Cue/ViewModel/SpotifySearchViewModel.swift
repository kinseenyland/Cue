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
}
