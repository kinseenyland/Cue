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
                // Results
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

            // Now playing bar
            if !spotifyManager.currentTrackName.isEmpty || spotifyManager.playbackError != nil {
                nowPlayingBar
            }
        }
        .navigationTitle("Spotify")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
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
                    Text("To create playlists, allow access in the browser.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button {
                        spotifyManager.grantPlaylistAccess()
                    } label: {
                        Label("Allow creating playlists", systemImage: "link")
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

    private var nowPlayingBar: some View {
        VStack(spacing: 4) {
            if let error = spotifyManager.playbackError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(1)
            }
            if !spotifyManager.currentTrackName.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "music.note")
                        .foregroundStyle(.green)
                    Text(spotifyManager.currentTrackName)
                        .font(.subheadline)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(UIColor.secondarySystemBackground))
            }
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
