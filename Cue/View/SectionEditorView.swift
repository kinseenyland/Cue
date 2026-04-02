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
    let durationMinutes: Int
    @Binding var playlistId: String?
    let defaultGoalType: GoalType?
    var showGoalOption: Bool = true
    var showPlaylist: Bool = true

    @Environment(\.dismiss) private var dismiss
    @State private var showPlaylistEditor = false
    @State private var playlistRefreshKey = 0
    @StateObject private var inlinePlaylistVM = SpotifySearchViewModel()

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
                    // Duration (read-only)
                    HStack {
                        Text("DURATION")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .kerning(1.2)
                            .padding(.trailing, 8)
                        Text("~\(durationMinutes) min")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.black)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        Spacer()
                    }
                    .padding(.horizontal, 24)

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

                        MovementComposerView(
                            defaultGoalType: defaultGoalType,
                            showGoalOption: showGoalOption,
                            movements: $movements
                        )
                        .compositingGroup()
                        .zIndex(50)
                        .padding(.horizontal, 24)
                    }
                    .zIndex(50)

                    if showPlaylist {
                        Divider().padding(.horizontal, 24)
                        playlistSection
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
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
            if showPlaylist {
                SectionPlaylistEditor(selectedPlaylistId: $playlistId)
                    .presentationDetents([.medium, .large])
            }
        }
        .onChange(of: showPlaylistEditor) { _, isShowing in
            if !isShowing {
                playlistRefreshKey += 1
            }
        }
        .task(id: "\(playlistId ?? "")-\(playlistRefreshKey)") {
            await loadInlinePlaylist()
        }
    }

    // MARK: - Playlist Loading

    private func loadInlinePlaylist() async {
        guard let id = playlistId else {
            inlinePlaylistVM.closePlaylistEditor()
            return
        }
        await inlinePlaylistVM.loadMyPlaylists()
        if let playlist = inlinePlaylistVM.myPlaylists.first(where: { $0.uri == id }) {
            await inlinePlaylistVM.selectPlaylistForEditing(playlist)
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
                VStack(alignment: .leading, spacing: 8) {
                    // Header row: name + Edit + Remove
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "music.note.list")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            Text(inlinePlaylistVM.selectedPlaylistForEditing?.name
                                 ?? (inlinePlaylistVM.isLoadingPlaylists ? "Loading..." : "Playlist"))
                                .font(.system(size: 14, weight: .medium))
                                .lineLimit(1)
                        }
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
                            playlistId = nil
                            inlinePlaylistVM.closePlaylistEditor()
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

                    // Track count + duration summary
                    if !inlinePlaylistVM.isLoadingPlaylistTracks && !inlinePlaylistVM.playlistTracks.isEmpty {
                        let totalSecs = inlinePlaylistVM.playlistTracks.reduce(0) { $0 + $1.track.durationSeconds }
                        let h = totalSecs / 3600
                        let m = (totalSecs % 3600) / 60
                        Text("\(inlinePlaylistVM.playlistTracks.count) tracks · \(h > 0 ? "\(h)h \(m)m" : "\(m)m")")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    // Inline track list
                    if inlinePlaylistVM.isLoadingPlaylistTracks {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    } else if !inlinePlaylistVM.playlistTracks.isEmpty {
                        InlineReorderableTrackList(viewModel: inlinePlaylistVM)
                    }
                }
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

/// Editor for the main workout section — shows section cards that drill down into individual editors.
struct MainSectionEditorView: View {
    @Binding var sections: [WorkoutSubSection]
    @Binding var playlistId: String?
    let totalDurationMinutes: Int
    let defaultGoalType: GoalType?
    var showGoalOption: Bool = true

    @Environment(\.dismiss) private var dismiss
    @State private var activeSheet: MainSectionSheet?
    @State private var playlistRefreshKey = 0
    @StateObject private var inlinePlaylistVM = SpotifySearchViewModel()

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
                VStack(alignment: .leading, spacing: 16) {
                    // Section cards
                    Text("SECTIONS")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .kerning(1.2)
                        .padding(.horizontal, 24)

                    VStack(spacing: 0) {
                        ForEach(Array(sections.indices), id: \.self) { index in
                            MainSectionCard(
                                section: sections[index],
                                canDelete: sections.count > 1,
                                onTap: { activeSheet = .editSection(index) },
                                onDelete: {
                                    guard sections.indices.contains(index), sections.count > 1 else { return }
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        sections.remove(at: index)
                                    }
                                }
                            )

                            if index < sections.count - 1 {
                                Divider().padding(.leading, 16)
                            }
                        }
                    }
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 24)

                    // Add section button
                    HStack {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                sections.append(WorkoutSubSection())
                            }
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

                    // Playlist section (inline editable)
                    playlistSection
                }
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
        .background(Color.white.ignoresSafeArea())
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .editSection(let index):
                if sections.indices.contains(index) {
                    SectionEditorView(
                        title: sections[index].name.isEmpty ? "Section \(index + 1)" : sections[index].name,
                        movements: $sections[index].movements,
                        durationMinutes: sections[index].durationMinutes,
                        playlistId: .constant(nil),
                        defaultGoalType: defaultGoalType,
                        showGoalOption: showGoalOption,
                        showPlaylist: false
                    )
                }
            case .editPlaylist:
                SectionPlaylistEditor(selectedPlaylistId: $playlistId)
                    .presentationDetents([.medium, .large])
            }
        }
        .onChange(of: activeSheet) { old, new in
            if let old, new == nil, case .editPlaylist = old {
                playlistRefreshKey += 1
            }
        }
        .task(id: "\(playlistId ?? "")-\(playlistRefreshKey)") {
            await loadInlinePlaylist()
        }
    }

    // MARK: - Playlist Loading

    private func loadInlinePlaylist() async {
        guard let id = playlistId else {
            inlinePlaylistVM.closePlaylistEditor()
            return
        }
        await inlinePlaylistVM.loadMyPlaylists()
        if let playlist = inlinePlaylistVM.myPlaylists.first(where: { $0.uri == id }) {
            await inlinePlaylistVM.selectPlaylistForEditing(playlist)
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
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "music.note.list")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            Text(inlinePlaylistVM.selectedPlaylistForEditing?.name
                                 ?? (inlinePlaylistVM.isLoadingPlaylists ? "Loading..." : "Playlist"))
                                .font(.system(size: 14, weight: .medium))
                                .lineLimit(1)
                        }
                        Spacer()
                        Button {
                            activeSheet = .editPlaylist
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
                            playlistId = nil
                            inlinePlaylistVM.closePlaylistEditor()
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

                    if !inlinePlaylistVM.isLoadingPlaylistTracks && !inlinePlaylistVM.playlistTracks.isEmpty {
                        let totalSecs = inlinePlaylistVM.playlistTracks.reduce(0) { $0 + $1.track.durationSeconds }
                        let h = totalSecs / 3600
                        let m = (totalSecs % 3600) / 60
                        Text("\(inlinePlaylistVM.playlistTracks.count) tracks · \(h > 0 ? "\(h)h \(m)m" : "\(m)m")")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    if inlinePlaylistVM.isLoadingPlaylistTracks {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    } else if !inlinePlaylistVM.playlistTracks.isEmpty {
                        InlineReorderableTrackList(viewModel: inlinePlaylistVM)
                    }
                }
                .padding(.horizontal, 24)
            } else {
                Button {
                    activeSheet = .editPlaylist
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

// MARK: - Main Section Sheet Discriminator

private enum MainSectionSheet: Identifiable, Equatable {
    case editSection(Int)
    case editPlaylist

    var id: String {
        switch self {
        case .editSection(let i): return "section-\(i)"
        case .editPlaylist: return "playlist"
        }
    }
}

// MARK: - Main Section Card

private struct MainSectionCard: View {
    let section: WorkoutSubSection
    let canDelete: Bool
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(section.name.isEmpty ? "Unnamed Section" : section.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.black)
                    Text("\(section.movements.count) movement\(section.movements.count == 1 ? "" : "s") · \(section.durationMinutes) min")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if canDelete {
                    Button(action: onDelete) {
                        Image(systemName: "minus.circle")
                            .font(.system(size: 16))
                            .foregroundStyle(Color(.systemGray3))
                    }
                    .buttonStyle(.plain)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(.systemGray3))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Inline Reorderable Track List

private struct InlineReorderableTrackList: View {
    @ObservedObject var viewModel: SpotifySearchViewModel
    @State private var confirmingDeleteId: String?
    @State private var resetTask: Task<Void, Never>?

    private let rowHeight: CGFloat = 50

    var body: some View {
        List {
            ForEach(viewModel.playlistTracks) { item in
                HStack(spacing: 10) {
                    Button {
                        handleDeleteTap(item: item)
                    } label: {
                        Image(systemName: confirmingDeleteId == item.id ? "trash.fill" : "trash")
                            .font(.system(size: 12))
                            .foregroundStyle(confirmingDeleteId == item.id ? .red : Color(.systemGray3))
                    }
                    .buttonStyle(.plain)

                    AsyncImage(url: item.track.albumArtURL) { img in
                        img.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color(.systemGray4)
                    }
                    .frame(width: 32, height: 32)
                    .cornerRadius(4)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.track.name)
                            .font(.system(size: 13, weight: .medium))
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
                .frame(height: rowHeight)
                .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
                .listRowBackground(Color(.systemGray6))
                .listRowSeparator(.hidden)
            }
            .onMove { from, to in
                guard let src = from.first else { return }
                Task { await viewModel.moveTrack(from: src, to: to) }
            }
        }
        .environment(\.editMode, .constant(.active))
        .scrollDisabled(true)
        .listStyle(.plain)
        .frame(height: CGFloat(viewModel.playlistTracks.count) * rowHeight)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func handleDeleteTap(item: SpotifySearchService.PlaylistTrackItem) {
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
    }
}

// MARK: - Reorderable Movement List (internal for reuse)

struct ReorderableMovementList: View {
    @Binding var movements: [Movement]
    @State private var confirmingDeleteId: String?
    @State private var resetTask: Task<Void, Never>?

    private var totalHeight: CGFloat {
        movements.reduce(0) { total, movement in
            let hasMetric = movement.reps != nil || movement.seconds != nil
            let hasNote = movement.notes.map { !$0.isEmpty } ?? false
            // Metric column (number + unit label stacked) ≈ 33pt, name alone ≈ 19pt, note ≈ 15pt.
            // Row height = max(left col, right col) + 24pt vertical padding.
            let h: CGFloat
            if hasNote {
                h = 61  // note side (19+3+15=37) > metric col (33); 37+24
            } else if hasMetric {
                h = 57  // metric col (33) > name alone (19); 33+24
            } else {
                h = 43  // no metric, no note: name only (19) + 24
            }
            return total + h
        }
    }

    var body: some View {
        List {
            ForEach($movements) { $movement in
                MovementRow(
                    movement: movement,
                    isConfirmingDelete: confirmingDeleteId == movement.id,
                    onDeleteTap: {
                        if confirmingDeleteId == movement.id {
                            resetTask?.cancel()
                            confirmingDeleteId = nil
                            withAnimation(.easeInOut(duration: 0.2)) {
                                movements.removeAll { $0.id == movement.id }
                            }
                        } else {
                            resetTask?.cancel()
                            withAnimation(.easeInOut(duration: 0.15)) {
                                confirmingDeleteId = movement.id
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
                    }
                )
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
        .frame(height: totalHeight)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
