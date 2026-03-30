//
//  SpotifySearchView.swift
//  Cue
//
//  Created by IS 543 on 2/18/26.
//

import SwiftUI
import UIKit

struct SpotifySearchView: View {
    @EnvironmentObject private var spotifyManager: SpotifyManager
    @EnvironmentObject private var mainTabChrome: MainTabChrome
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = SpotifySearchViewModel()
    @State private var isConnecting = false
    @State private var connectionError: String?
    @State private var playlistSearchQuery = ""
    @State private var isShowingNewPlaylistNameField = false
    @FocusState private var isCreatePlaylistNameFieldFocused: Bool
    var onTrackSelected: (SpotifySearchService.SpotifyTrack) -> Void = { _ in }

    private var isAuthenticated: Bool {
        spotifyManager.isAuthenticated
    }

    private var isEditingPlaylist: Bool {
        viewModel.selectedPlaylistForEditing != nil
    }

    private var hasPlaylistAccess: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return spotifyManager.apiAccessToken != nil
        #endif
    }

    /// Used in playlist editing to show "already added" state in search results.
    private func isTrackInEditingPlaylist(_ track: SpotifySearchService.SpotifyTrack) -> Bool {
        viewModel.playlistTracks.contains(where: { $0.track.id == track.id })
    }

    private var shouldShowNowPlayingRibbon: Bool {
        spotifyManager.playbackError != nil || spotifyManager.isConnected || !spotifyManager.currentTrackName.isEmpty
    }

    /// Clears the custom tab bar in `MainTabView`; extra bottom padding would leave an empty band above the keyboard.
    private var bottomPaddingClearingMainTabBar: CGFloat {
        if mainTabChrome.hideBottomBar { return 0 }
        return shouldShowNowPlayingRibbon ? 84 : 56
    }

    var body: some View {
        VStack(spacing: 0) {
            if spotifyManager.isFinishingAuth {
                finishingAuthView
            } else if !isAuthenticated {
                connectToSpotifyPrompt
            }

            // My playlists (browse & edit)
            if isAuthenticated && !isEditingPlaylist && viewModel.currentPlaylist == nil {
                myPlaylistsSection
                createPlaylistSection
            }

            if !isEditingPlaylist {
                // When creating a new playlist, search songs so users can add tracks.
                if viewModel.currentPlaylist != nil {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("Search songs to add...", text: $viewModel.searchQuery)
                            .autocorrectionDisabled()
                            .disabled(!isAuthenticated)
                        if !viewModel.searchQuery.isEmpty {
                            Button {
                                viewModel.clear()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding()
                }
            }
            
            // States
            if spotifyManager.isFinishingAuth || !isAuthenticated {
                Spacer()
            } else if viewModel.selectedPlaylistForEditing != nil {
                // Playlist editor: add-songs search + playlist tracks
                VStack(alignment: .leading, spacing: 0) {
                    addSongsSection
                    // When searching/adding, hide the existing playlist tracks to keep the UI focused.
                    if viewModel.searchQuery.isEmpty {
                        playlistEditContent
                    }
                }
            } else {
                if viewModel.currentPlaylist != nil {
                    createPlaylistSection
                    if viewModel.isLoading {
                        Spacer()
                        ProgressView("Searching...")
                        Spacer()
                    } else if let error = viewModel.errorMessage {
                        Spacer()
                        Text(error)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding()
                        Spacer()
                    } else if viewModel.tracks.isEmpty && !viewModel.searchQuery.isEmpty {
                        Spacer()
                        Text("No results found")
                            .foregroundColor(.gray)
                        Spacer()
                    } else {
                        if !viewModel.tracks.isEmpty {
                            Text("Search results")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                        }
                        List(viewModel.tracks) { track in
                            let alreadyAdded = viewModel.currentPlaylistAddedTrackIDs.contains(track.id)
                            Button {
                                Task { await viewModel.addTrackToCurrentPlaylist(track) }
                            } label: {
                                HStack {
                                    TrackRowView(track: track)
                                    Spacer()
                                    if alreadyAdded || (viewModel.isAddingTrack && viewModel.lastAddedTrackName == track.name) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.black)
                                    } else {
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundStyle(.black)
                                    }
                                }
                            }
                            .disabled(alreadyAdded)
                            .buttonStyle(.plain)
                        }
                        .listStyle(.plain)
                    }
                } else {
                    Spacer()
                }
            }

            if viewModel.currentPlaylist != nil, let name = viewModel.lastAddedTrackName, !viewModel.isAddingTrack {
                Text("Added \"\(name)\"")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }

        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .padding(.bottom, bottomPaddingClearingMainTabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if shouldShowNowPlayingRibbon {
                nowPlayingBar
            }
        }
        .onAppear {
            // Keep App Remote synced without manual reconnects.
            #if !targetEnvironment(simulator)
            spotifyManager.connectAppRemoteIfNeeded()
            #endif
        }
        .task {
            // Auto-load "My playlists" once we're authenticated and have playlist scopes.
            // Keep it simple: load once when the list is empty and we're not already editing a playlist.
            guard isAuthenticated && hasPlaylistAccess && !isEditingPlaylist else { return }
            guard viewModel.myPlaylists.isEmpty else { return }
            guard !viewModel.isLoadingPlaylists else { return }
            await viewModel.loadMyPlaylists()
        }
        .onChange(of: spotifyManager.apiAccessToken) { _, _ in
            Task {
                // Token can arrive after initial render; load playlists immediately then.
                guard isAuthenticated && hasPlaylistAccess && !isEditingPlaylist else { return }
                guard viewModel.myPlaylists.isEmpty else { return }
                guard !viewModel.isLoadingPlaylists else { return }
                await viewModel.loadMyPlaylists()
            }
        }
        .onChange(of: spotifyManager.isFinishingAuth) { _, finishing in
            guard !finishing else { return }
            Task {
                guard isAuthenticated && hasPlaylistAccess && !isEditingPlaylist else { return }
                guard viewModel.myPlaylists.isEmpty else { return }
                guard !viewModel.isLoadingPlaylists else { return }
                await viewModel.loadMyPlaylists()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            #if !targetEnvironment(simulator)
            if phase == .active {
                spotifyManager.connectAppRemoteIfNeeded()
            } else if phase == .background {
                spotifyManager.disconnect()
            }
            #endif
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            mainTabChrome.hideBottomBar = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            mainTabChrome.hideBottomBar = false
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidHideNotification)) { _ in
            mainTabChrome.hideBottomBar = false
        }
        .onDisappear {
            mainTabChrome.hideBottomBar = false
        }
        .navigationTitle(viewModel.selectedPlaylistForEditing?.name ?? "Spotify")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(viewModel.selectedPlaylistForEditing != nil)
        .toolbar {
            if viewModel.selectedPlaylistForEditing != nil {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        viewModel.closePlaylistEditor()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.black)
                    }
                }
            }
            if isAuthenticated {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sign out") {
                        spotifyManager.signOut()
                        viewModel.clearCurrentPlaylist()
                        viewModel.createPlaylistError = nil
                    }
                    .font(.subheadline)
                }
            }
        }
    }

    private var finishingAuthView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Finishing sign in...")
                .font(.headline)
            Text("This usually takes a moment.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var connectToSpotifyPrompt: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.note")
                .font(.system(size: 40))
                .foregroundStyle(.black)
            Text("Connect to Spotify")
                .font(.headline)
            Text("Sign in with your Spotify account to search for music.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("Opens a browser to sign in with your Spotify account.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                connectionError = nil
                isConnecting = true
                Task { @MainActor in
                    let started = spotifyManager.connectForOnboarding()
                    if !started {
                        connectionError = "Failed to start authorization. Please try again."
                    }
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    isConnecting = false
                }
            } label: {
                if isConnecting {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                } else {
                    Label("Connect with Spotify", systemImage: "link")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.black)
            .padding(.top, 4)
            .disabled(isConnecting)
            if let error = connectionError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.black, lineWidth: 1)
        )
        .cornerRadius(12)
        .padding()
    }

    /// Shown when already signed in on device — tap to get a token from the Spotify app so playback works.
    private var linkSpotifyAppBar: some View {
        HStack {
            Text("To play music, link the Spotify app.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Link Spotify app") {
                spotifyManager.connect()
            }
            .font(.caption)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(UIColor.secondarySystemBackground))
    }

    private var createPlaylistSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let playlist = viewModel.currentPlaylist {
                HStack {
                    Text("Adding to: \(playlist.name)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Done") {
                        viewModel.clearCurrentPlaylist()
                        isShowingNewPlaylistNameField = false
                        isCreatePlaylistNameFieldFocused = false
                    }
                    .font(.subheadline.weight(.medium))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.black, lineWidth: 1)
                )
            } else {
                if !isShowingNewPlaylistNameField {
                    Button {
                        isShowingNewPlaylistNameField = true
                        viewModel.createPlaylistError = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isCreatePlaylistNameFieldFocused = true
                        }
                    } label: {
                        Text("Create new playlist")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.black)
                } else {
                    HStack(spacing: 8) {
                        TextField("Playlist name", text: $viewModel.newPlaylistName)
                            .textFieldStyle(.plain)
                            .autocorrectionDisabled()
                            .focused($isCreatePlaylistNameFieldFocused)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.black, lineWidth: 1)
                            )
                        Button {
                            Task {
                                await viewModel.createPlaylist()
                                if viewModel.currentPlaylist != nil {
                                    isShowingNewPlaylistNameField = false
                                    isCreatePlaylistNameFieldFocused = false
                                }
                            }
                        } label: {
                            if viewModel.isCreatingPlaylist {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                            } else {
                                Text("Create")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.black)
                        .disabled(viewModel.isCreatingPlaylist || viewModel.newPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .onAppear { viewModel.createPlaylistError = nil }
                }
            }
            if let error = viewModel.createPlaylistError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 12)
            }
        }
        .padding(.horizontal)
        .padding(.top, 2)
        .padding(.bottom, 2)
    }

    private var myPlaylistsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let playlist = viewModel.selectedPlaylistForEditing {
                HStack {
                    Text("Editing: \(playlist.name)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        spotifyManager.playPlaylistFromStart(playlistUri: playlist.uri)
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(.black)
                    Button("Done") {
                        viewModel.closePlaylistEditor()
                    }
                    .font(.subheadline.weight(.medium))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.black, lineWidth: 1)
                )
            } else {
                let filteredPlaylists: [SpotifySearchService.SpotifyPlaylist] = {
                    let q = playlistSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    guard !q.isEmpty else { return viewModel.myPlaylists }
                    return viewModel.myPlaylists.filter { $0.name.lowercased().contains(q) }
                }()

                VStack(alignment: .leading, spacing: 8) {
                    TextField("Search playlists...", text: $playlistSearchQuery)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 10)
                        .padding(.vertical, 9)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.black, lineWidth: 1)
                        )
                        .padding(.horizontal, 12)

                    if viewModel.isLoadingPlaylists {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .padding(.vertical, 14)
                    } else if filteredPlaylists.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.myPlaylists.isEmpty ? "No playlists yet." : "No playlists found.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(viewModel.myPlaylists.isEmpty ? "Create one above or sign in to Spotify." : "Try a different search.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            if viewModel.myPlaylists.isEmpty {
                                Button {
                                    Task { await viewModel.loadMyPlaylists() }
                                } label: {
                                    Label("Refresh", systemImage: "arrow.clockwise")
                                        .font(.caption)
                                }
                                .padding(.top, 4)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    } else {
                        ScrollView(.vertical, showsIndicators: true) {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(filteredPlaylists, id: \.id) { playlist in
                                    Button {
                                        Task { await viewModel.selectPlaylistForEditing(playlist) }
                                    } label: {
                                        HStack {
                                            Text(playlist.name)
                                                .lineLimit(1)
                                                .font(.body)
                                                .foregroundStyle(.black)
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .background(Color.white)
                                        .cornerRadius(10)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color.black, lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.trailing, 6)
                                }
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 12)
                        }
                        .frame(maxHeight: .infinity)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)
            }
            if let error = viewModel.playlistEditError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 12)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 4)
    }

    /// When editing a playlist: search Spotify and add results to this playlist.
    @ViewBuilder
    private var addSongsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Search bar scoped to playlist editing (still uses `viewModel.searchQuery`).
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search songs to add…", text: $viewModel.searchQuery)
                    .autocorrectionDisabled()
                if !viewModel.searchQuery.isEmpty {
                    Button {
                        viewModel.clear()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(10)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.black, lineWidth: 1)
            )
            .cornerRadius(10)
            .padding(.horizontal)

            Text("Add songs from Spotify")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.black)
                .padding(.horizontal)

            if viewModel.searchQuery.isEmpty {
                Text("Search above to find songs, then tap + to add them to this playlist.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
            } else if viewModel.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.9)
                    Text("Searching...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            } else if viewModel.tracks.isEmpty {
                Text("No results found")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
            } else {
                List(viewModel.tracks) { track in
                    let alreadyAdded = isTrackInEditingPlaylist(track)
                    Button {
                        Task { await viewModel.addTrackToPlaylistBeingEdited(track) }
                    } label: {
                        HStack {
                            TrackRowView(track: track)
                            Spacer()
                            if alreadyAdded || (viewModel.isAddingTrack && viewModel.lastAddedTrackName == track.name) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.black)
                            } else {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.black)
                            }
                        }
                    }
                    .disabled(alreadyAdded)
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
                .frame(maxHeight: .infinity)
            }
        }
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var playlistEditContent: some View {
        if viewModel.isLoadingPlaylistTracks {
            VStack(spacing: 10) {
                ProgressView()
                Text("Loading playlist...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else if viewModel.playlistTracks.isEmpty {
            VStack(spacing: 8) {
                Text("Playlist tracks")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("No tracks in this playlist.")
                    .foregroundStyle(.secondary)
                Text("Search above to add songs from Spotify.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding()
        } else {
            Text("\(viewModel.playlistTracks.count) track\(viewModel.playlistTracks.count == 1 ? "" : "s") in playlist")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            List {
                ForEach(viewModel.playlistTracks) { item in
                    HStack(spacing: 12) {
                        TrackRowView(track: item.track)
                        Spacer()
                        Button {
                            Task { await viewModel.removeTrackFromPlaylist(item) }
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                                .font(.body)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 2)
                }
                .onDelete { indexSet in
                    guard let idx = indexSet.first, idx < viewModel.playlistTracks.count else { return }
                    let item = viewModel.playlistTracks[idx]
                    Task { await viewModel.removeTrackFromPlaylist(item) }
                }
                .onMove { source, destination in
                    guard let src = source.first, src != destination else { return }
                    Task { await viewModel.moveTrack(from: src, to: destination) }
                }
            }
            .listStyle(.plain)
        }
    }

    private var nowPlayingBar: some View {
        VStack(spacing: 4) {
            if let error = spotifyManager.playbackError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(1)
            }
            HStack(spacing: 10) {
                Button {
                    spotifyManager.previousTrack()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.plain)
                .disabled(!spotifyManager.isConnected)

                Button {
                    spotifyManager.togglePlayPause()
                } label: {
                    Image(systemName: spotifyManager.isPaused ? "play.fill" : "pause.fill")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.plain)
                .disabled(!spotifyManager.isConnected)

                Button {
                    spotifyManager.nextTrack()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.plain)
                .disabled(!spotifyManager.isConnected)

                Divider()
                    .frame(height: 18)
                    .padding(.horizontal, 2)

                Text(spotifyManager.currentTrackName.isEmpty ? "Now playing" : spotifyManager.currentTrackName)
                    .font(.subheadline)
                    .lineLimit(1)
                Spacer()
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.black, lineWidth: 1)
            )
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

struct TrackRowView: View {
    let track: SpotifySearchService.SpotifyTrack
    
    var body: some View {
        HStack(spacing: 12) {
            // Album Art
            AsyncImage(url: track.albumArtURL) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Color(UIColor.systemGray5)
            }
            .frame(width: 50, height: 50)
            .cornerRadius(6)
            
            // Track Info
            VStack(alignment: .leading, spacing: 3) {
                Text(track.name)
                    .font(.body)
                    .lineLimit(1)
                Text(track.artistName)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Duration
            Text(track.durationFormatted)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 4)
    }
}
