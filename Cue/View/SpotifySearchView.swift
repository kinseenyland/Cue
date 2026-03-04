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
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = SpotifySearchViewModel()
    @State private var isConnecting = false
    @State private var connectionError: String?
    var onTrackSelected: (SpotifySearchService.SpotifyTrack) -> Void = { _ in }

    private var isAuthenticated: Bool {
        (spotifyManager.accessToken != nil || spotifyManager.apiAccessToken != nil) && !spotifyManager.isFinishingAuth
    }

    /// On device we need a separate API token (from browser) for playlist scopes. On simulator we use PKCE for connect so we already have scopes.
    private var hasPlaylistAccess: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return spotifyManager.apiAccessToken != nil
        #endif
    }

    /// True when authenticated and running on a physical device (so we show "Link Spotify app").
    private var isAuthenticatedOnDevice: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return isAuthenticated
        #endif
    }

    /// Show "Link Spotify app" only after playback failed (e.g. connection refused), so re-linking is available when needed.
    /// Hidden on fresh launch so the bar doesn’t appear until they try to play and hit an error.
    private var shouldShowLinkSpotifyAppBar: Bool {
        isAuthenticatedOnDevice && !spotifyManager.isConnected && spotifyManager.playbackError != nil
    }
    
    private var shouldShowNowPlayingRibbon: Bool {
        spotifyManager.playbackError != nil || spotifyManager.isConnected || !spotifyManager.currentTrackName.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            if spotifyManager.isFinishingAuth {
                finishingAuthView
            } else if !isAuthenticated {
                connectToSpotifyPrompt
            } else if shouldShowLinkSpotifyAppBar {
                linkSpotifyAppBar
            }

            // Create playlist
            if isAuthenticated {
                createPlaylistSection
            }

            // My playlists (browse & edit)
            if isAuthenticated && hasPlaylistAccess {
                myPlaylistsSection
            }

            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search songs...", text: $viewModel.searchQuery)
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
            
            // States
            if spotifyManager.isFinishingAuth || !isAuthenticated {
                Spacer()
            } else if viewModel.selectedPlaylistForEditing != nil {
                // Playlist editor: add-songs search + playlist tracks
                VStack(alignment: .leading, spacing: 0) {
                    addSongsSection
                    playlistEditContent
                }
            } else if viewModel.isLoading {
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
                // Search results (not a playlist)
                if !viewModel.tracks.isEmpty {
                    Text("Search results")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                }
                List(viewModel.tracks) { track in
                    if viewModel.currentPlaylist != nil {
                        Button {
                            Task { await viewModel.addTrackToCurrentPlaylist(track) }
                        } label: {
                            HStack {
                                TrackRowView(track: track)
                                Spacer()
                                if viewModel.isAddingTrack && viewModel.lastAddedTrackName == track.name {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                } else {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            spotifyManager.play(trackUri: track.uri)
                            onTrackSelected(track)
                        } label: {
                            TrackRowView(track: track)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.plain)
            }

            if viewModel.currentPlaylist != nil, let name = viewModel.lastAddedTrackName, !viewModel.isAddingTrack {
                Text("Added \"\(name)\"")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }

        }
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
        .onChange(of: scenePhase) { phase in
            #if !targetEnvironment(simulator)
            if phase == .active {
                spotifyManager.connectAppRemoteIfNeeded()
            } else if phase == .background {
                spotifyManager.disconnect()
            }
            #endif
        }
        .navigationTitle("Spotify")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.selectedPlaylistForEditing != nil {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
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
                .foregroundStyle(.green)
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
                    let started = spotifyManager.connect()
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
            .tint(.green)
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
        .background(Color(UIColor.secondarySystemBackground))
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
                    }
                    .font(.subheadline.weight(.medium))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(8)
            } else if !hasPlaylistAccess {
                VStack(alignment: .leading, spacing: 8) {
                    Text("To use playlists, allow access in the browser.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button {
                        spotifyManager.grantPlaylistAccess()
                    } label: {
                        Label("Allow using playlists", systemImage: "link")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(8)
            } else {
                HStack(spacing: 8) {
                    TextField("Playlist name", text: $viewModel.newPlaylistName)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                    Button {
                        Task { await viewModel.createPlaylist() }
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
                    .tint(.green)
                    .disabled(viewModel.isCreatingPlaylist || viewModel.newPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(8)
                .onAppear { viewModel.createPlaylistError = nil }
            }
            if let error = viewModel.createPlaylistError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 12)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 4)
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
                    .tint(.green)
                    Button("Done") {
                        viewModel.closePlaylistEditor()
                    }
                    .font(.subheadline.weight(.medium))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(8)
            } else {
                HStack {
                    Text("My playlists")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        Task { await viewModel.loadMyPlaylists() }
                    } label: {
                        if viewModel.isLoadingPlaylists {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Text("Load")
                        }
                    }
                    .font(.subheadline)
                    .disabled(viewModel.isLoadingPlaylists)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(8)
                if !viewModel.myPlaylists.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(viewModel.myPlaylists, id: \.id) { playlist in
                                Button {
                                    Task { await viewModel.selectPlaylistForEditing(playlist) }
                                } label: {
                                    Text(playlist.name)
                                        .lineLimit(1)
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color(UIColor.tertiarySystemFill))
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
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
            Text("Add songs from Spotify")
                .font(.subheadline)
                .foregroundStyle(.secondary)
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
                    Button {
                        Task { await viewModel.addTrackToPlaylistBeingEdited(track) }
                    } label: {
                        HStack {
                            TrackRowView(track: track)
                            Spacer()
                            if viewModel.isAddingTrack && viewModel.lastAddedTrackName == track.name {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
                .frame(maxHeight: 280)
            }
        }
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var playlistEditContent: some View {
        if viewModel.isLoadingPlaylistTracks {
            Spacer()
            ProgressView("Loading playlist...")
            Spacer()
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
            .padding()
            Spacer()
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
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
