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

    enum EditorMode {
        case pickPlaylist
        case editTracks
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
        }
        .onAppear {
            // If a playlist is already selected, go straight to edit mode
            if let id = selectedPlaylistId,
               let playlist = viewModel.myPlaylists.first(where: { $0.uri == id }) {
                Task {
                    await viewModel.selectPlaylistForEditing(playlist)
                    mode = .editTracks
                }
            }
        }
        .onChange(of: viewModel.myPlaylists) { _, playlists in
            // Once playlists load, if one is already selected, open it
            if let id = selectedPlaylistId,
               let playlist = playlists.first(where: { $0.uri == id }),
               viewModel.selectedPlaylistForEditing == nil {
                Task {
                    await viewModel.selectPlaylistForEditing(playlist)
                    mode = .editTracks
                }
            }
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
                Text("\(viewModel.playlistTracks.count) track\(viewModel.playlistTracks.count == 1 ? "" : "s")")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 4)

                List {
                    ForEach(viewModel.playlistTracks) { item in
                        HStack(spacing: 12) {
                            TrackRowView(track: item.track)
                            Spacer()
                            Button {
                                Task { await viewModel.removeTrackFromPlaylist(item) }
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(Color(.systemGray3))
                                    .font(.system(size: 13))
                            }
                            .buttonStyle(.plain)
                        }
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
                .environment(\.editMode, .constant(.active))
                .listStyle(.plain)
            }
        }
    }
}
