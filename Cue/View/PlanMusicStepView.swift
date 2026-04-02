//
//  PlanMusicStepView.swift
//  Cue
//

import SwiftUI

// MARK: - Music Approach Choice Step

struct MusicApproachChoiceStepView: View {
    @EnvironmentObject private var vm: PlanCreationViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("How do you\napproach music?")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 24)

                VStack(spacing: 12) {
                    choiceCard(
                        title: "Music First",
                        subtitle: "Pick your playlists, then build movements",
                        value: .musicFirst
                    )
                    choiceCard(
                        title: "Movements First",
                        subtitle: "Build your workout, then add music",
                        value: .workoutFirst
                    )
                }
                .padding(.horizontal, 24)
            }
            .padding(.top, 4)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func choiceCard(title: String, subtitle: String, value: MusicApproach) -> some View {
        let isSelected = vm.musicFlowChoice == value
        return Button {
            vm.musicFlowChoice = value
        } label: {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : .black)
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.white)
                }
            }
            .padding(20)
            .background(isSelected ? Color.black : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.black, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Pick Music Step

struct PlanPickMusicStepView: View {
    @EnvironmentObject private var vm: PlanCreationViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("Pick Your Music")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 24)

                VStack(alignment: .leading, spacing: 24) {
                    MusicFirstSectionRow(
                        title: "WARM-UP",
                        selectedPlaylistId: $vm.draft.warmUpPlaylistId
                    )
                    Divider().padding(.horizontal, 24)
                    MusicFirstSectionRow(
                        title: "MAIN WORKOUT",
                        selectedPlaylistId: $vm.draft.mainPlaylistId
                    )
                    Divider().padding(.horizontal, 24)
                    MusicFirstSectionRow(
                        title: "COOL-DOWN",
                        selectedPlaylistId: $vm.draft.coolDownPlaylistId
                    )
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            Task { await vm.loadSpotifyPlaylistsIfNeeded() }
        }
    }
}

// MARK: - Per-section row with chip picker + inline preview

private struct MusicFirstSectionRow: View {
    let title: String
    @Binding var selectedPlaylistId: String?
    @EnvironmentObject private var vm: PlanCreationViewModel
    @StateObject private var previewVM = SpotifySearchViewModel()
    @State private var refreshKey = 0
    @State private var showPlaylistEditor = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .kerning(1.2)
                .padding(.horizontal, 24)

            // Chip picker
            if vm.spotifyPlaylists.isEmpty {
                HStack {
                    if vm.isLoadingPlaylists {
                        ProgressView().scaleEffect(0.8)
                        Text("Loading…")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    } else {
                        Button {
                            Task { await vm.loadSpotifyPlaylistsIfNeeded() }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "music.note.list")
                                Text("Load Spotify playlists")
                            }
                            .font(.system(size: 13, weight: .medium))
                        }
                        .buttonStyle(.borderless)
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // None chip
                        Button {
                            selectedPlaylistId = nil
                            previewVM.closePlaylistEditor()
                        } label: {
                            Text("None")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(selectedPlaylistId == nil ? .white : .black)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(RoundedRectangle(cornerRadius: 8).fill(selectedPlaylistId == nil ? Color.black : Color.clear))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black.opacity(0.2), lineWidth: 1))
                        }
                        .buttonStyle(.plain)

                        ForEach(vm.spotifyPlaylists, id: \.uri) { playlist in
                            Button {
                                selectedPlaylistId = playlist.uri
                                refreshKey += 1
                            } label: {
                                Text(playlist.name)
                                    .lineLimit(1)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(selectedPlaylistId == playlist.uri ? .white : .black)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(selectedPlaylistId == playlist.uri ? Color.black : Color.clear))
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black.opacity(0.2), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 4)
                }
            }

            // Inline preview when a playlist is selected
            if let id = selectedPlaylistId {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Text(previewVM.selectedPlaylistForEditing?.name
                             ?? (previewVM.isLoadingPlaylists ? "Loading..." : "Playlist"))
                            .font(.system(size: 14, weight: .medium))
                            .lineLimit(1)
                        Spacer()
                        Button {
                            showPlaylistEditor = true
                        } label: {
                            Text("Edit")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .overlay(Capsule().stroke(Color.black, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        Button {
                            selectedPlaylistId = nil
                            previewVM.closePlaylistEditor()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 24, height: 24)
                                .background(Color(.systemGray5))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }

                    if !previewVM.isLoadingPlaylistTracks && !previewVM.playlistTracks.isEmpty {
                        let totalSecs = previewVM.playlistTracks.reduce(0) { $0 + $1.track.durationSeconds }
                        let h = totalSecs / 3600
                        let m = (totalSecs % 3600) / 60
                        Text("\(previewVM.playlistTracks.count) tracks · \(h > 0 ? "\(h)h \(m)m" : "\(m)m")")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    if previewVM.isLoadingPlaylistTracks {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    } else if !previewVM.playlistTracks.isEmpty {
                        InlineReorderableTrackList(viewModel: previewVM)
                    }
                }
                .padding(.horizontal, 24)
                .task(id: "\(id)-\(refreshKey)") {
                    await previewVM.loadMyPlaylists()
                    if let playlist = previewVM.myPlaylists.first(where: { $0.uri == id }) {
                        await previewVM.selectPlaylistForEditing(playlist)
                    }
                }
                .sheet(isPresented: $showPlaylistEditor) {
                    SectionPlaylistEditor(selectedPlaylistId: $selectedPlaylistId)
                        .presentationDetents([.medium, .large])
                }
                .onChange(of: showPlaylistEditor) { _, isShowing in
                    if !isShowing { refreshKey += 1 }
                }
            }
        }
    }
}

// MARK: - Assigned Playlist Label

struct AssignedPlaylistLabel: View {
    let name: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "music.note.list")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Text(name)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}
