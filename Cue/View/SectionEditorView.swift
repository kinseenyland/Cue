//
//  SectionEditorView.swift
//  Cue
//

import SwiftUI

/// Full-screen editor for a single workout section (warm-up, main, or cool-down).
/// Presented as a sheet from PlanFormView's section summary cards.
struct SectionEditorView: View {
    let title: String
    @Binding var movements: [Movement]
    @Binding var durationMinutes: Int
    @Binding var playlistId: String?
    let defaultGoalType: GoalType?

    @Environment(\.dismiss) private var dismiss
    @State private var showPlaylistEditor = false
    @State private var playlistPreviewRefreshKey = 0
    @State private var dismissDurationPickersTrigger = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            ZStack {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                HStack {
                    Spacer()
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.black)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Duration
                    HStack {
                        Text("DURATION")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .kerning(1.2)
                            .padding(.trailing, 8)
                        EditableDurationBadge(
                            minutes: $durationMinutes,
                            dismissTrigger: dismissDurationPickersTrigger
                        )
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .compositingGroup()
                    .zIndex(100)

                    // Movements
                    VStack(alignment: .leading, spacing: 12) {
                        Text("MOVEMENTS")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .kerning(1.2)
                            .padding(.horizontal, 24)

                        if !movements.isEmpty {
                            ReorderableMovementList(movements: $movements)
                                .padding(.horizontal, 24)
                        }

                        MovementAddFormView(
                            defaultGoalType: defaultGoalType,
                            movements: $movements
                        )
                        .padding(.horizontal, 24)
                    }
                    .zIndex(0)

                    Divider().padding(.horizontal, 24)

                    // Playlist
                    playlistSection
                }
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                dismissDurationPickersTrigger.toggle()
            }
        }
        .background(Color.white.ignoresSafeArea())
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil, from: nil, for: nil
                    )
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.black)
            }
        }
        .sheet(isPresented: $showPlaylistEditor) {
            SectionPlaylistEditor(selectedPlaylistId: $playlistId)
                .presentationDetents([.medium, .large])
        }
        .onChange(of: showPlaylistEditor) { _, isShowing in
            if !isShowing {
                playlistPreviewRefreshKey += 1
            }
        }
    }

    // MARK: - Playlist Section

    private var playlistSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PLAYLIST")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .kerning(1.2)
                .padding(.horizontal, 24)

            if playlistId != nil {
                PlaylistPreviewCard(
                    playlistId: playlistId!,
                    refreshKey: playlistPreviewRefreshKey,
                    onEdit: { showPlaylistEditor = true },
                    onRemove: { playlistId = nil }
                )
                .padding(.horizontal, 24)
            } else {
                Button {
                    showPlaylistEditor = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 14))
                        Text("Add a playlist")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
            }
        }
    }
}

// MARK: - Main Section Editor

/// Editor for the main workout section, which contains named sub-sections.
struct MainSectionEditorView: View {
    @Binding var sections: [WorkoutSubSection]
    @Binding var playlistId: String?
    let totalDurationMinutes: Int
    let defaultGoalType: GoalType?

    @Environment(\.dismiss) private var dismiss
    @State private var showPlaylistEditor = false
    @State private var playlistPreviewRefreshKey = 0
    @State private var dismissDurationPickersTrigger = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            ZStack {
                Text("Main Workout")
                    .font(.system(size: 17, weight: .semibold))
                HStack {
                    Spacer()
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.black)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(Array(sections.indices), id: \.self) { index in
                        MainSubSectionBlock(
                            section: $sections[index],
                            defaultGoalType: defaultGoalType,
                            canDelete: sections.count > 1,
                            dismissPickersTrigger: dismissDurationPickersTrigger,
                            onDelete: {
                                guard sections.indices.contains(index), sections.count > 1 else { return }
                                sections.remove(at: index)
                            }
                        )
                    }

                    HStack {
                        Button {
                            sections.append(WorkoutSubSection())
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("Add Section")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundStyle(.black)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .overlay(Capsule().stroke(Color.black, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                    .padding(.horizontal, 24)

                    Divider().padding(.horizontal, 24)

                    // Playlist
                    VStack(alignment: .leading, spacing: 10) {
                        Text("PLAYLIST")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .kerning(1.2)
                            .padding(.horizontal, 24)

                        if playlistId != nil {
                            PlaylistPreviewCard(
                                playlistId: playlistId!,
                                refreshKey: playlistPreviewRefreshKey,
                                onEdit: { showPlaylistEditor = true },
                                onRemove: { playlistId = nil }
                            )
                            .padding(.horizontal, 24)
                        } else {
                            Button {
                                showPlaylistEditor = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "music.note.list")
                                        .font(.system(size: 14))
                                    Text("Add a playlist")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 24)
                        }
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                dismissDurationPickersTrigger.toggle()
            }
        }
        .background(Color.white.ignoresSafeArea())
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil, from: nil, for: nil
                    )
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.black)
            }
        }
        .sheet(isPresented: $showPlaylistEditor) {
            SectionPlaylistEditor(selectedPlaylistId: $playlistId)
                .presentationDetents([.medium, .large])
        }
        .onChange(of: showPlaylistEditor) { _, isShowing in
            if !isShowing {
                playlistPreviewRefreshKey += 1
            }
        }
    }
}

// MARK: - Main Sub-Section Block (inside MainSectionEditorView)

private struct MainSubSectionBlock: View {
    @Binding var section: WorkoutSubSection
    let defaultGoalType: GoalType?
    let canDelete: Bool
    let dismissPickersTrigger: Bool
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                TextField("Section name", text: $section.name)
                    .font(.system(size: 15))
                    .padding(.bottom, 4)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(Color(UIColor.systemGray3))
                            .frame(height: 1)
                    }

                Spacer()

                EditableDurationBadge(
                    minutes: $section.durationMinutes,
                    dismissTrigger: dismissPickersTrigger
                )

                if canDelete {
                    Button(action: onDelete) {
                        Image(systemName: "minus.circle")
                            .font(.system(size: 18))
                            .foregroundStyle(Color(UIColor.systemGray3))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .compositingGroup()
            .zIndex(100)

            if !section.movements.isEmpty {
                ReorderableMovementList(movements: $section.movements)
                    .padding(.horizontal, 24)
            }

            MovementAddFormView(
                defaultGoalType: defaultGoalType,
                movements: $section.movements
            )
            .padding(.horizontal, 24)

            Divider()
                .padding(.horizontal, 24)
        }
    }
}

// MARK: - Playlist Preview Card

struct PlaylistPreviewCard: View {
    let playlistId: String
    let refreshKey: Int
    let onEdit: () -> Void
    let onRemove: () -> Void

    @EnvironmentObject private var spotifyManager: SpotifyManager
    @State private var playlistName: String?
    @State private var tracks: [SpotifySearchService.PlaylistTrackItem] = []
    @State private var isLoading = false
    
    private var totalDurationLabel: String {
        let totalSeconds = tracks.reduce(0) { $0 + $1.track.durationSeconds }
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    private var spotifyId: String {
        // Convert URI (spotify:playlist:xxx) to plain ID
        if playlistId.hasPrefix("spotify:playlist:") {
            return String(playlistId.dropFirst("spotify:playlist:".count))
        }
        return playlistId
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Text(playlistName ?? "Loading...")
                            .font(.system(size: 14, weight: .medium))
                            .lineLimit(1)
                    }
                    if !isLoading && !tracks.isEmpty {
                        Text("\(tracks.count) tracks \u{00B7} \(totalDurationLabel)")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button {
                    onEdit()
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
                    onRemove()
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

            if isLoading {
                ProgressView()
                    .scaleEffect(0.8)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            } else if !tracks.isEmpty {
                VStack(spacing: 0) {
                    ForEach(tracks.prefix(3)) { item in
                        HStack(spacing: 10) {
                            AsyncImage(url: item.track.albumArtURL) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Color(UIColor.systemGray5)
                            }
                            .frame(width: 32, height: 32)
                            .cornerRadius(4)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.track.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .lineLimit(1)
                                Text(item.track.artistName)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Text(item.track.durationFormatted)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6)

                        if item.id != tracks.prefix(3).last?.id {
                            Divider()
                        }
                    }

                    if tracks.count > 3 {
                        Text("+ \(tracks.count - 3) more")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .padding(.top, 6)
                    }
                }
                .padding(10)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .task(id: "\(playlistId)-\(refreshKey)") {
            await loadPlaylistInfo()
        }
    }

    private func loadPlaylistInfo() async {
        guard spotifyManager.isAuthenticated else { return }
        isLoading = true
        defer { isLoading = false }

        // Load playlist name
        let playlists = (try? await SpotifySearchService.shared.getMyPlaylists(limit: 50)) ?? []
        playlistName = playlists.first(where: { $0.uri == playlistId })?.name ?? "Playlist"

        // Load tracks
        tracks = (try? await SpotifySearchService.shared.getPlaylistTracks(playlistId: spotifyId)) ?? []
    }
}

// MARK: - Reorderable Movement List (made internal for reuse)

struct ReorderableMovementList: View {
    @Binding var movements: [Movement]

    // Keep this aligned with MovementRow's visual height to avoid trailing empty space.
    private static let rowHeight: CGFloat = 44

    var body: some View {
        List {
            ForEach($movements) { $movement in
                MovementRow(movement: movement) {
                    movements.removeAll { $0.id == movement.id }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color(.systemGray6))
                .listRowSeparator(.hidden)
            }
            .onMove { from, to in
                movements.move(fromOffsets: from, toOffset: to)
            }
        }
        .environment(\.editMode, .constant(.active))
        .scrollDisabled(true)
        .listStyle(.plain)
        .frame(height: CGFloat(movements.count) * Self.rowHeight)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
