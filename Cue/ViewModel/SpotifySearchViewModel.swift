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
}
