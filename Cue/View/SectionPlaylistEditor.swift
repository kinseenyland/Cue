//
//  SectionPlaylistEditor.swift
//  Cue
//

import SwiftUI

/// Half-sheet for picking a Spotify playlist and editing its tracks.
/// Presented from SectionEditorView.
struct SectionPlaylistEditor: View {
    @Binding var selectedPlaylistId: String?

    @StateObject private var viewModel = SpotifySearchViewModel()
    @EnvironmentObject private var spotifyManager: SpotifyManager
    @Environment(\.dismiss) private var dismiss

    @State private var mode: EditorMode = .pickPlaylist
    @State private var confirmingDeleteId: String?
    @State private var resetTask: Task<Void, Never>?

    enum EditorMode {
        case pickPlaylist
        case editTracks
    }
    
    private var totalDurationLabel: String {
        let totalSeconds = viewModel.playlistTracks.reduce(0) { $0 + $1.track.durationSeconds }
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                switch mode {
                case .pickPlaylist:
                    playlistPickerContent
                case .editTracks:
                    trackEditorContent
                }
            }
            .background(Color.white)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(mode == .pickPlaylist ? "Choose Playlist" : (viewModel.selectedPlaylistForEditing?.name ?? "Edit Tracks"))
                        .font(.system(size: 17, weight: .semibold))
                }
                ToolbarItem(placement: .topBarLeading) {
                    if mode == .editTracks {
                        Button {
                            viewModel.closePlaylistEditor()
                            mode = .pickPlaylist
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.black)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.black)
                }
            }
        }
        .task {
            await viewModel.loadMyPlaylists()
            // If a playlist is already selected, jump straight to track editing
            if let id = selectedPlaylistId,
               let playlist = viewModel.myPlaylists.first(where: { $0.uri == id }) {
                await viewModel.selectPlaylistForEditing(playlist)
                mode = .editTracks
            }
        }
        .onDisappear {
            resetTask?.cancel()
        }
    }

    // MARK: - Playlist Picker

    private var playlistPickerContent: some View {
        VStack(spacing: 0) {
            if viewModel.isLoadingPlaylists {
                VStack(spacing: 10) {
                    ProgressView()
                    Text("Loading playlists...")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.myPlaylists.isEmpty {
                VStack(spacing: 8) {
                    Text("No playlists found")
                        .font(.system(size: 14, weight: .medium))
                    Text("Connect to Spotify to see your playlists.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // "None" option
                if selectedPlaylistId != nil {
                    Button {
                        selectedPlaylistId = nil
                        dismiss()
                    } label: {
                        HStack {
                            Text("Remove playlist")
                                .font(.system(size: 15))
                                .foregroundStyle(.red)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)

                    Divider().padding(.horizontal, 20)
                }

                List(viewModel.myPlaylists, id: \.id) { playlist in
                    Button {
                        selectedPlaylistId = playlist.uri
                        Task {
                            await viewModel.selectPlaylistForEditing(playlist)
                            mode = .editTracks
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(playlist.name)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.black)
                            }
                            Spacer()
                            if playlist.uri == selectedPlaylistId {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.black)
                            }
                        }
                    }
                    .listRowBackground(Color.white)
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Track Editor

    private var trackEditorContent: some View {
        VStack(spacing: 0) {
            // Search bar for adding tracks
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                TextField("Search songs to add...", text: $viewModel.searchQuery)
                    .font(.system(size: 15))
                if !viewModel.searchQuery.isEmpty {
                    Button {
                        viewModel.searchQuery = ""
                        viewModel.tracks = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 20)
            .padding(.vertical, 8)

            if !viewModel.searchQuery.isEmpty {
                // Search results
                searchResultsContent
            } else {
                // Current playlist tracks
                currentTracksContent
            }
        }
    }

    private var searchResultsContent: some View {
        Group {
            if viewModel.isLoading {
                VStack(spacing: 10) {
                    ProgressView()
                    Text("Searching...")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.tracks.isEmpty && !viewModel.searchQuery.isEmpty {
                Text("No results found")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.tracks) { track in
                    let alreadyAdded = viewModel.playlistTracks.contains(where: { $0.track.id == track.id })
                    Button {
                        Task { await viewModel.addTrackToPlaylistBeingEdited(track) }
                    } label: {
                        HStack {
                            TrackRowView(track: track)
                            Spacer()
                            if alreadyAdded {
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
                    .listRowBackground(Color.white)
                }
                .listStyle(.plain)
            }
        }
    }

    private var currentTracksContent: some View {
        Group {
            if viewModel.isLoadingPlaylistTracks {
                VStack(spacing: 10) {
                    ProgressView()
                    Text("Loading tracks...")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.playlistTracks.isEmpty {
                VStack(spacing: 8) {
                    Text("No tracks yet")
                        .font(.system(size: 14, weight: .medium))
                    Text("Search above to add songs.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("\(viewModel.playlistTracks.count) track\(viewModel.playlistTracks.count == 1 ? "" : "s") \u{00B7} \(totalDurationLabel)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 4)

                List {
                    ForEach(viewModel.playlistTracks) { item in
                        HStack(spacing: 12) {
                            TrackRowView(track: item.track, showDuration: false)

                            Text(item.track.durationFormatted)
                                .font(.caption)
                                .foregroundColor(.gray)

                            Button {
                                if confirmingDeleteId == item.id {
                                    resetTask?.cancel()
                                    confirmingDeleteId = nil
                                    Task { await viewModel.removeTrackFromPlaylist(item) }
                                } else {
                                    resetTask?.cancel()
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        confirmingDeleteId = item.id
                                    }
                                    resetTask = Task {
                                        try? await Task.sleep(nanoseconds: 2_500_000_000)
                                        guard !Task.isCancelled else { return }
                                        await MainActor.run {
                                            withAnimation(.easeInOut(duration: 0.15)) {
                                                confirmingDeleteId = nil
                                            }
                                        }
                                    }
                                }
                            } label: {
                                Image(systemName: confirmingDeleteId == item.id ? "trash.fill" : "trash")
                                    .foregroundStyle(confirmingDeleteId == item.id ? .red : Color(.systemGray3))
                                    .font(.system(size: 13))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .onMove { source, destination in
                        guard let src = source.first, src != destination else { return }
                        Task { await viewModel.moveTrack(from: src, to: destination) }
                    }
                }
                .environment(\.editMode, .constant(.active))
                .listStyle(.plain)
            }
        }
    }
}
