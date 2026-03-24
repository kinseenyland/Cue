//
//  PlanDetailView.swift
//  Cue
//
//  Created by Kinsee Nyland on 2/10/26.
//

import SwiftUI

struct PlanDetailView: View {
    let plan: WorkoutPlan
    @Binding var selectedTab: MainTab
    let onUpdate: (WorkoutPlanDraft) -> Void
    let onDelete: () -> Void
    let onDuplicate: (String) -> Void
    let availableTypes: [WorkoutType]
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sessionVM: WorkoutSessionViewModel
    @EnvironmentObject private var spotifyManager: SpotifyManager

    @State private var localTitle: String
    @State private var localType: WorkoutType
    @State private var localDifficulty: Difficulty
    @State private var localDuration: Int
    @State private var localMovements: [Movement]
    @State private var editingMovement: Movement? = nil
    @State private var isShowingDetailsEdit = false
    @State private var isShowingDeleteConfirmation = false
    @State private var isShowingDuplicatePrompt = false
    @State private var duplicateName = ""
    @State private var warmUpPlaylistIdLocal: String?
    @State private var mainPlaylistIdLocal: String?
    @State private var coolDownPlaylistIdLocal: String?
    @State private var playlists: [SpotifySearchService.SpotifyPlaylist] = []
    @State private var isLoadingPlaylists = false
    @State private var playlistsError: String? = nil
    @State private var isShowingSpotifyAlert = false

    init(plan: WorkoutPlan, selectedTab: Binding<MainTab>, onUpdate: @escaping (WorkoutPlanDraft) -> Void, onDelete: @escaping () -> Void, onDuplicate: @escaping (String) -> Void, availableTypes: [WorkoutType] = WorkoutType.allCases) {
        self.plan = plan
        self._selectedTab = selectedTab
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        self.onDuplicate = onDuplicate
        self.availableTypes = availableTypes
        self._localTitle = State(initialValue: plan.title)
        self._localType = State(initialValue: plan.type)
        self._localDifficulty = State(initialValue: plan.difficulty)
        self._localDuration = State(initialValue: plan.durationMinutes)
        self._localMovements = State(initialValue: plan.movements)
        self._warmUpPlaylistIdLocal = State(initialValue: plan.warmUpPlaylistId)
        self._mainPlaylistIdLocal = State(initialValue: plan.mainPlaylistId)
        self._coolDownPlaylistIdLocal = State(initialValue: plan.coolDownPlaylistId)
    }

    // MARK: - Computed groupings (use localMovements so edits reflect immediately)

    private var warmUpMovements: [Movement] {
        localMovements.filter { $0.section == .warmUp }
    }

    private var coolDownMovements: [Movement] {
        localMovements.filter { $0.section == .coolDown }
    }

    private var mainSections: [(name: String, movements: [Movement])] {
        var result: [(name: String, movements: [Movement])] = []
        var nameToIndex: [String: Int] = [:]
        for m in localMovements where m.section == .main {
            let key = m.sectionName ?? ""
            if let idx = nameToIndex[key] {
                result[idx].movements.append(m)
            } else {
                nameToIndex[key] = result.count
                result.append((name: key, movements: [m]))
            }
        }
        return result
    }

    private var hasSectionStructure: Bool {
        !warmUpMovements.isEmpty || !coolDownMovements.isEmpty ||
        mainSections.contains(where: { !$0.name.isEmpty })
    }

    private var difficultyLabel: String {
        switch localDifficulty {
        case .easy: return "Low"
        case .medium: return "Medium"
        case .hard: return "High"
        }
    }

    private var typeIcon: String {
        switch localType {
        case .matPilates, .reformerPilates: return "figure.pilates"
        case .yoga: return "figure.yoga"
        case .cycle: return "bicycle"
        case .strength: return "dumbbell.fill"
        case .cardio: return "heart.fill"
        }
    }

    // MARK: - Body

    var body: some View {
        let isSpotifyAuthenticated =
        (spotifyManager.accessToken != nil || spotifyManager.apiAccessToken != nil) &&
        !spotifyManager.isFinishingAuth

        VStack(alignment: .leading, spacing: 8) {
            // Back button row
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.black)
                        .frame(width: 33, height: 31)
                }
                Spacer()
            }
            .padding(.horizontal, 7)

            // Title + menu row
            HStack(alignment: .center, spacing: 10) {
                Text(localTitle)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer()

                Menu {
                    Button { isShowingDetailsEdit = true } label: {
                        Label("Edit Plan Details", systemImage: "pencil")
                    }
                    Button {
                        duplicateName = "\(plan.title) (Copy)"
                        isShowingDuplicatePrompt = true
                    } label: {
                        Label("Duplicate Plan", systemImage: "doc.on.doc")
                    }
                    Button(role: .destructive) { isShowingDeleteConfirmation = true } label: {
                        Label("Delete Plan", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .rotationEffect(.degrees(90))
                        .font(.system(size: 20))
                        .foregroundStyle(.black)
                        .frame(width: 24, height: 38)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)

            // Details Snapshot: Type, Time, Intensity
            HStack(spacing: 10) {
                Spacer()
                PlanDetailCard(icon: typeIcon, label: "Type", value: localType.displayName)
                PlanDetailCard(icon: "timer", label: "Time", value: "\(localDuration) min")
                PlanDetailCard(icon: "flame.fill", label: "Intensity", value: difficultyLabel)
                Spacer()
            }
            .padding(.horizontal, 10)

            // Movement list
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if hasSectionStructure {
                        if !warmUpMovements.isEmpty {
                            movementSectionBlock(
                                title: "WARM-UP",
                                movements: warmUpMovements,
                                playlistId: warmUpPlaylistIdLocal
                            )
                        }
                        if !mainSections.isEmpty {
                            mainWorkoutBlock
                        }
                        if !coolDownMovements.isEmpty {
                            movementSectionBlock(
                                title: "COOL-DOWN",
                                movements: coolDownMovements,
                                playlistId: coolDownPlaylistIdLocal
                            )
                        }
                    } else {
                        VStack(spacing: 8) {
                            ForEach(localMovements) { movement in
                                MovementDetailCard(
                                    movement: movement,
                                    onEdit: { editingMovement = movement },
                                    onDelete: { deleteMovement(movement) }
                                )
                                .padding(.horizontal, 20)
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .scrollIndicators(.hidden)

            // Start Lesson button
            HStack {
                Spacer()
                Button {
                    var updatedPlan = plan
                    updatedPlan.movements = localMovements
                    if spotifyManager.isConnected || !isSpotifyAuthenticated {
                        sessionVM.load(plan: updatedPlan)
                        selectedTab = .workout
                        dismiss()
                    } else {
                        isShowingSpotifyAlert = true
                    }
                } label: {
                    Text("Start Lesson")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(width: 158, height: 41)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.vertical, 13)
            .padding(.bottom, 34)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .navigationBarBackButtonHidden(true)
        .task {
            await loadPlaylistsIfNeeded()
        }
        .alert("Connect to Spotify", isPresented: $isShowingSpotifyAlert) {
            Button("Connect & Start") {
                _ = spotifyManager.connect()
                var updatedPlan = plan
                updatedPlan.movements = localMovements
                sessionVM.load(plan: updatedPlan)
                selectedTab = .workout
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Connect to Spotify so your workout music can start automatically.")
        }
        .alert("Delete \"\(plan.title)\"?", isPresented: $isShowingDeleteConfirmation) {
            Button("Delete", role: .destructive) { onDelete(); dismiss() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
        .alert("Duplicate Plan", isPresented: $isShowingDuplicatePrompt) {
            TextField("Plan name", text: $duplicateName)
            Button("Duplicate") {
                let name = duplicateName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return }
                onDuplicate(name)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter a name for the duplicated plan.")
        }
        .sheet(isPresented: $isShowingDetailsEdit) {
            PlanDetailsEditSheet(
                title: localTitle, type: localType, difficulty: localDifficulty,
                duration: localDuration, availableTypes: availableTypes
            ) { name, type, difficulty, duration in
                localTitle = name
                localType = type
                localDifficulty = difficulty
                localDuration = duration
                onUpdate(WorkoutPlanDraft(
                    title: name, type: type, difficulty: difficulty,
                    durationMinutes: duration, movements: localMovements,
                    warmUpPlaylistId: warmUpPlaylistIdLocal,
                    mainPlaylistId: mainPlaylistIdLocal,
                    coolDownPlaylistId: coolDownPlaylistIdLocal
                ))
            }
        }
        .sheet(item: $editingMovement) { movement in
            MovementEditSheet(movement: movement) { updated in
                updateMovement(updated)
            }
        }
    }

    // MARK: - Section Blocks

    @ViewBuilder
    private func movementSectionBlock(title: String, movements: [Movement], playlistId: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .kerning(1.2)
                if let playlistId, let name = playlistName(for: playlistId) {
                    Menu {
                        Button("None") {
                            updatePlaylist(for: title, to: nil)
                        }
                        ForEach(playlists, id: \.uri) { playlist in
                            Button(playlist.name) {
                                updatePlaylist(for: title, to: playlist.uri)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "music.note.list")
                            Text(name)
                                .font(.system(size: 11, weight: .regular))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                } else if !playlists.isEmpty {
                    Menu {
                        Button("None") {
                            updatePlaylist(for: title, to: nil)
                        }
                        ForEach(playlists, id: \.uri) { playlist in
                            Button(playlist.name) {
                                updatePlaylist(for: title, to: playlist.uri)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "music.note.list")
                            Text("None")
                                .font(.system(size: 11, weight: .regular))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            ForEach(movements) { movement in
                MovementDetailCard(
                    movement: movement,
                    onEdit: { editingMovement = movement },
                    onDelete: { deleteMovement(movement) }
                )
                .padding(.horizontal, 20)
            }
        }
    }

    private var mainWorkoutBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Text("MAIN WORKOUT")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .kerning(1.2)
                if let pid = mainPlaylistIdLocal, let name = playlistName(for: pid) {
                    Menu {
                        Button("None") {
                            updatePlaylist(for: "MAIN WORKOUT", to: nil)
                        }
                        ForEach(playlists, id: \.uri) { playlist in
                            Button(playlist.name) {
                                updatePlaylist(for: "MAIN WORKOUT", to: playlist.uri)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "music.note.list")
                            Text(name)
                                .font(.system(size: 11, weight: .regular))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                } else if !playlists.isEmpty {
                    Menu {
                        Button("None") {
                            updatePlaylist(for: "MAIN WORKOUT", to: nil)
                        }
                        ForEach(playlists, id: \.uri) { playlist in
                            Button(playlist.name) {
                                updatePlaylist(for: "MAIN WORKOUT", to: playlist.uri)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "music.note.list")
                            Text("None")
                                .font(.system(size: 11, weight: .regular))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)

            ForEach(mainSections.indices, id: \.self) { idx in
                let section = mainSections[idx]
                VStack(alignment: .leading, spacing: 8) {
                    if !section.name.isEmpty {
                        Text(section.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 20)
                    }
                    ForEach(section.movements) { movement in
                        MovementDetailCard(
                            movement: movement,
                            onEdit: { editingMovement = movement },
                            onDelete: { deleteMovement(movement) }
                        )
                        .padding(.horizontal, 20)
                    }
                }
            }
        }
    }

    // MARK: - Movement Mutations

    private func deleteMovement(_ movement: Movement) {
        localMovements.removeAll { $0.id == movement.id }
        saveMovements()
    }

    private func updateMovement(_ updated: Movement) {
        if let idx = localMovements.firstIndex(where: { $0.id == updated.id }) {
            localMovements[idx] = updated
        }
        saveMovements()
    }

    private func saveMovements() {
        onUpdate(WorkoutPlanDraft(
            title: localTitle, type: localType, difficulty: localDifficulty,
            durationMinutes: localDuration,
            movements: localMovements,
            warmUpPlaylistId: warmUpPlaylistIdLocal,
            mainPlaylistId: mainPlaylistIdLocal,
            coolDownPlaylistId: coolDownPlaylistIdLocal
        ))
    }

    private func playlistName(for id: String) -> String? {
        // We store the Spotify playlist URI (context_uri), so match on uri
        playlists.first(where: { $0.uri == id })?.name
    }

    private func updatePlaylist(for sectionTitle: String, to id: String?) {
        // Base off local state so repeated taps don't "revert" to the original plan values.
        var warm = warmUpPlaylistIdLocal
        var main = mainPlaylistIdLocal
        var cool = coolDownPlaylistIdLocal

        switch sectionTitle {
        case "WARM-UP":
            warm = id
        case "MAIN WORKOUT":
            main = id
        case "COOL-DOWN":
            cool = id
        default:
            break
        }

        // Update local state so UI reflects change immediately
        warmUpPlaylistIdLocal = warm
        mainPlaylistIdLocal = main
        coolDownPlaylistIdLocal = cool

        // Persist immediately on tap.
        onUpdate(WorkoutPlanDraft(
            title: plan.title,
            type: plan.type,
            difficulty: plan.difficulty,
            durationMinutes: plan.durationMinutes,
            movements: localMovements,
            warmUpPlaylistId: warm,
            mainPlaylistId: main,
            coolDownPlaylistId: cool
        ))
    }

    private func loadPlaylistsIfNeeded() async {
        if !playlists.isEmpty || isLoadingPlaylists { return }
        isLoadingPlaylists = true
        playlistsError = nil
        defer { isLoadingPlaylists = false }
        do {
            playlists = try await SpotifySearchService.shared.getMyPlaylists(limit: 50)
        } catch {
            playlistsError = "Could not load Spotify playlists."
        }
    }
}

// MARK: - Plan Details Edit Sheet

private struct PlanDetailsEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var type: WorkoutType
    @State private var difficulty: Difficulty
    @State private var duration: Int
    @State private var durationText: String
    @FocusState private var durationFocused: Bool
    @State private var isDurationEditing: Bool = false
    let availableTypes: [WorkoutType]
    let onSave: (String, WorkoutType, Difficulty, Int) -> Void

    init(title: String, type: WorkoutType, difficulty: Difficulty, duration: Int, availableTypes: [WorkoutType] = WorkoutType.allCases, onSave: @escaping (String, WorkoutType, Difficulty, Int) -> Void) {
        _name = State(initialValue: title)
        _type = State(initialValue: type)
        _difficulty = State(initialValue: difficulty)
        _duration = State(initialValue: duration)
        _durationText = State(initialValue: "\(duration)")
        self.availableTypes = availableTypes
        self.onSave = onSave
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func commitDuration() {
        if let val = Int(durationText), val > 0 { duration = val }
        durationText = "\(duration)"
        isDurationEditing = false
        durationFocused = false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Button("Cancel") { dismiss() }
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Edit Details")
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
                Button("Save") {
                    commitDuration()
                    onSave(name.trimmingCharacters(in: .whitespacesAndNewlines), type, difficulty, duration)
                    dismiss()
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(canSave ? .black : Color(.systemGray3))
                .disabled(!canSave)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 24)

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // Name

                    VStack(alignment: .leading, spacing: 8) {
                        Text("PLAN NAME")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .kerning(1.2)
                        TextField("Plan name", text: $name)
                            .font(.system(size: 16))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 13)
                            .overlay(Rectangle().stroke(Color.black, lineWidth: 1))
                    }

                    // Type
                    VStack(alignment: .leading, spacing: 12) {
                        Text("WORKOUT TYPE")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .kerning(1.2)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(availableTypes, id: \.self) { t in
                                    Button {
                                        type = t
                                    } label: {
                                        Text(t.displayName)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(type == t ? .white : .black)
                                            .lineLimit(1)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(type == t ? Color.black : Color.clear)
                                            .overlay(Capsule().stroke(Color.black, lineWidth: 1))
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // Difficulty
                    VStack(alignment: .leading, spacing: 12) {
                        Text("INTENSITY")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .kerning(1.2)
                        HStack(spacing: 8) {
                            ForEach(Difficulty.allCases, id: \.self) { d in
                                Button {
                                    difficulty = d
                                } label: {
                                    Text(d.rawValue.capitalized)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(difficulty == d ? .white : .black)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(difficulty == d ? Color.black : Color.clear)
                                        .overlay(Capsule().stroke(Color.black, lineWidth: 1))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Duration
                    VStack(alignment: .leading, spacing: 12) {
                        Text("DURATION")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .kerning(1.2)
                        HStack(spacing: 16) {
                            Button {
                                commitDuration()
                                if duration > 5 { duration -= 5 }
                                durationText = "\(duration)"
                            } label: {
                                Image(systemName: "minus")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(.black)
                                    .frame(width: 36, height: 36)
                                    .overlay(Circle().stroke(Color.black, lineWidth: 1))
                            }
                            .buttonStyle(.plain)

                            HStack(spacing: 4) {
                                TextField("", text: $durationText)
                                    .keyboardType(.numberPad)
                                    .font(.system(size: 18, weight: .semibold))
                                    .multilineTextAlignment(.center)
                                    .focused($durationFocused)
                                    .frame(width: 52)
                                    .padding(.vertical, 6)
                                    .overlay(Rectangle().stroke(Color.black, lineWidth: 1))
                                Text("min")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(.black)
                            }

                            Button {
                                commitDuration()
                                duration += 5
                                durationText = "\(duration)"
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(.black)
                                    .frame(width: 36, height: 36)
                                    .overlay(Circle().stroke(Color.black, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .background(Color.white.ignoresSafeArea())
        .scrollDismissesKeyboard(.immediately)
        .onChange(of: durationFocused) { _, focused in
            if !focused { commitDuration() }
        }
    }
}

// MARK: - Movement Edit Sheet

private struct MovementEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var goalType: GoalType
    @State private var reps: String
    @State private var seconds: String
    @State private var notes: String
    let movement: Movement
    let onSave: (Movement) -> Void

    init(movement: Movement, onSave: @escaping (Movement) -> Void) {
        self.movement = movement
        self.onSave = onSave
        _name = State(initialValue: movement.name)
        _goalType = State(initialValue: movement.goalType)
        _reps = State(initialValue: movement.reps.map { String($0) } ?? "")
        _seconds = State(initialValue: movement.seconds.map { String($0) } ?? "")
        _notes = State(initialValue: movement.notes ?? "")
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (goalType == .reps ? !reps.isEmpty : !seconds.isEmpty)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Button("Cancel") { dismiss() }
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Edit Movement")
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
                Button("Save") {
                    var updated = movement
                    updated.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    updated.goalType = goalType
                    updated.reps = goalType == .reps ? Int(reps) : nil
                    updated.seconds = goalType == .timed ? Int(seconds) : nil
                    let trimmedNote = notes.trimmingCharacters(in: .whitespacesAndNewlines)
                    updated.notes = trimmedNote.isEmpty ? nil : trimmedNote
                    onSave(updated)
                    dismiss()
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(canSave ? .black : Color(.systemGray3))
                .disabled(!canSave)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 24)

            VStack(alignment: .leading, spacing: 24) {
                // Name
                VStack(alignment: .leading, spacing: 8) {
                    Text("MOVEMENT NAME")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .kerning(1.2)
                    TextField("Movement name", text: $name)
                        .font(.system(size: 16))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 13)
                        .overlay(Rectangle().stroke(Color.black, lineWidth: 1))
                }

                // Goal
                VStack(alignment: .leading, spacing: 12) {
                    Text("GOAL")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .kerning(1.2)

                    HStack(alignment: .center, spacing: 10) {
                        TextField("0", text: goalType == .reps ? $reps : $seconds)
                            .keyboardType(.numberPad)
                            .font(.system(size: 20, weight: .semibold))
                            .multilineTextAlignment(.center)
                            .frame(width: 64)
                            .padding(.vertical, 10)
                            .overlay(Rectangle().stroke(Color.black, lineWidth: 1))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(goalType == .reps ? "reps" : "seconds")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.black)
                            Button {
                                goalType = goalType == .reps ? .timed : .reps
                                reps = ""
                                seconds = ""
                            } label: {
                                Text("switch to \(goalType == .reps ? "timed" : "reps")")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                    .underline()
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Notes
                VStack(alignment: .leading, spacing: 8) {
                    Text("NOTE")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .kerning(1.2)
                    TextField("e.g. 5lb weight, use a band", text: $notes)
                        .font(.system(size: 16))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 13)
                        .overlay(Rectangle().stroke(Color.black, lineWidth: 1))
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .background(Color.white.ignoresSafeArea())
    }
}

// MARK: - Plan Detail Card

private struct PlanDetailCard: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundStyle(.black)
                .frame(height: 30)
                .padding(.top, 17)

            Spacer()

            VStack(alignment: .leading, spacing: 5) {
                Text(label)
                    .font(.system(size: 12, weight: .thin))
                    .foregroundStyle(.black)
                Text(value)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.black)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6.5)
            .padding(.vertical, 5)
            .padding(.bottom, 5)
        }
        .frame(width: 100, height: 130)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(Color.black, lineWidth: 1)
        )
    }
}

// MARK: - Movement Detail Card

private struct MovementDetailCard: View {
    let movement: Movement
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var showDeleteConfirmation = false

    private var goalText: String {
        switch movement.goalType {
        case .timed: return movement.seconds.map { "\($0) sec" } ?? "—"
        case .reps:  return movement.reps.map { "\($0) reps" } ?? "—"
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(movement.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Image(systemName: "timer")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Text(goalText)
                        .font(.system(size: 12, weight: .thin))
                        .foregroundStyle(.black)
                }
            }
            Spacer()
            Button { showDeleteConfirmation = true } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(.systemGray3))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.black, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { onEdit() }
        .alert("Delete \"\(movement.name)\"?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) { onDelete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This movement will be removed from the plan.")
        }
    }
}

#Preview {
    NavigationStack {
        PlanDetailView(
            plan: WorkoutPlan(
                ownerId: "preview",
                title: "Hot Pilates - Core",
                type: .matPilates,
                difficulty: .hard,
                durationMinutes: 60,
                movements: [
                    Movement(name: "Mountain Climbers", goalType: .timed, seconds: 30),
                    Movement(name: "Plank Hold", goalType: .timed, seconds: 45),
                    Movement(name: "Burpees", goalType: .reps, reps: 10)
                ]
            ),
            selectedTab: .constant(.plans),
            onUpdate: { _ in },
            onDelete: {},
            onDuplicate: { _ in }
        )
        .environmentObject(WorkoutSessionViewModel())
    }
}
