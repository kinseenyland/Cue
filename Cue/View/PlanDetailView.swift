//
//  PlanDetailView.swift
//  Cue
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

    /// Local copy updated immediately when edits are saved, so the view reflects changes without waiting for a Firestore round-trip.
    @State private var currentPlan: WorkoutPlan
    @State private var isShowingEdit = false
    @State private var isShowingDeleteConfirmation = false
    @State private var isShowingDuplicatePrompt = false
    @State private var isShowingSpotifyHandoff = false
    @State private var duplicateName = ""
    @State private var playlists: [SpotifySearchService.SpotifyPlaylist] = []
    @State private var isLoadingPlaylists = false
    @State private var exportedPDFURL: URL? = nil
    @State private var isShowingShareSheet = false

    private var planHasPlaylist: Bool {
        currentPlan.warmUpPlaylistId != nil ||
        currentPlan.mainPlaylistId != nil ||
        currentPlan.coolDownPlaylistId != nil
    }

    init(
        plan: WorkoutPlan,
        selectedTab: Binding<MainTab>,
        onUpdate: @escaping (WorkoutPlanDraft) -> Void,
        onDelete: @escaping () -> Void,
        onDuplicate: @escaping (String) -> Void,
        availableTypes: [WorkoutType] = WorkoutType.allCases
    ) {
        self.plan = plan
        self._selectedTab = selectedTab
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        self.onDuplicate = onDuplicate
        self.availableTypes = availableTypes
        self._currentPlan = State(initialValue: plan)
    }

    // MARK: - Computed groupings

    private var warmUpMovements: [Movement] {
        currentPlan.movements.filter { $0.section == .warmUp }
    }

    private var coolDownMovements: [Movement] {
        currentPlan.movements.filter { $0.section == .coolDown }
    }

    private var mainSections: [(name: String, movements: [Movement])] {
        var result: [(name: String, movements: [Movement])] = []
        var nameToIndex: [String: Int] = [:]
        for m in currentPlan.movements where m.section == .main {
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
        switch currentPlan.difficulty {
        case .easy: return "Low"
        case .medium: return "Medium"
        case .hard: return "High"
        }
    }

    private var typeIcon: String {
        switch currentPlan.type {
        case .matPilates, .reformerPilates: return "figure.pilates"
        case .yoga: return "figure.yoga"
        case .cycle: return "bicycle"
        case .strength: return "dumbbell.fill"
        case .cardio: return "heart.fill"
        }
    }

    private func playlistName(for id: String?) -> String? {
        guard let id else { return nil }
        return playlists.first(where: { $0.uri == id })?.name
    }

    // MARK: - Body

    var body: some View {
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
                Text(currentPlan.title)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer()

                Menu {
                    Button { isShowingEdit = true } label: {
                        Label("Edit Plan", systemImage: "pencil")
                    }
                    Button {
                        duplicateName = "\(currentPlan.title) (Copy)"
                        isShowingDuplicatePrompt = true
                    } label: {
                        Label("Duplicate Plan", systemImage: "doc.on.doc")
                    }
                    Button {
                        if let url = PlanPDFRenderer.render(plan: currentPlan) {
                            exportedPDFURL = url
                            isShowingShareSheet = true
                        }
                    } label: {
                        Label("Export as PDF", systemImage: "square.and.arrow.up")
                    }
                    Button(role: .destructive) {
                        isShowingDeleteConfirmation = true
                    } label: {
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
                PlanDetailCard(icon: typeIcon, label: "Type", value: currentPlan.type.displayName)
                PlanDetailCard(icon: "timer", label: "Time", value: "\(currentPlan.durationMinutes) min")
                PlanDetailCard(icon: "flame.fill", label: "Intensity", value: difficultyLabel)
                Spacer()
            }
            .padding(.horizontal, 10)

            // Movement list (read-only)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if hasSectionStructure {
                        if !warmUpMovements.isEmpty {
                            movementSectionBlock(
                                title: "WARM-UP",
                                movements: warmUpMovements,
                                playlistId: currentPlan.warmUpPlaylistId
                            )
                        }
                        if !mainSections.isEmpty {
                            mainWorkoutBlock
                        }
                        if !coolDownMovements.isEmpty {
                            movementSectionBlock(
                                title: "COOL-DOWN",
                                movements: coolDownMovements,
                                playlistId: currentPlan.coolDownPlaylistId
                            )
                        }
                    } else {
                        VStack(spacing: 8) {
                            ForEach(currentPlan.movements) { movement in
                                MovementReadRow(movement: movement)
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
                    if planHasPlaylist && spotifyManager.isAuthenticated && !spotifyManager.isConnected {
                        isShowingSpotifyHandoff = true
                        Task {
                            try? await Task.sleep(nanoseconds: 800_000_000)
                            isShowingSpotifyHandoff = false
                            sessionVM.load(plan: currentPlan)
                            selectedTab = .workout
                            dismiss()
                        }
                    } else {
                        sessionVM.load(plan: currentPlan)
                        selectedTab = .workout
                        dismiss()
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
        .sheet(isPresented: $isShowingEdit) {
            PlanFormView(
                availableTypes: availableTypes,
                mode: .edit(
                    plan: currentPlan,
                    onSave: { updated in
                        // Apply changes locally for immediate UI refresh, then persist
                        var newPlan = currentPlan
                        newPlan.title = updated.title
                        newPlan.type = updated.type
                        newPlan.difficulty = updated.difficulty
                        newPlan.durationMinutes = updated.durationMinutes
                        newPlan.movements = updated.movements
                        newPlan.warmUpPlaylistId = updated.warmUpPlaylistId
                        newPlan.mainPlaylistId = updated.mainPlaylistId
                        newPlan.coolDownPlaylistId = updated.coolDownPlaylistId
                        currentPlan = newPlan
                        onUpdate(updated)
                        Task { await loadPlaylistsIfNeeded() }
                    }
                )
            )
        }
        .overlay(alignment: .bottom) {
            if isShowingSpotifyHandoff {
                HStack(spacing: 10) {
                    Image(systemName: "music.note")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Popping over to Spotify to kickstart your music!")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Color.black)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
                .padding(.bottom, 100)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isShowingSpotifyHandoff)
        .sheet(isPresented: $isShowingShareSheet) {
            if let url = exportedPDFURL {
                ActivityView(activityItems: [url])
                    .presentationDetents([.medium, .large])
            }
        }
        .overlay {
            if isShowingDeleteConfirmation {
                CustomAlertView(
                    title: "Delete \"\(currentPlan.title)\"?",
                    message: "This action cannot be undone.",
                    primaryLabel: "Cancel",
                    primaryAction: { isShowingDeleteConfirmation = false },
                    primaryStyle: .gray,
                    secondaryLabel: "Delete",
                    secondaryAction: {
                        isShowingDeleteConfirmation = false
                        onDelete()
                        dismiss()
                    },
                    secondaryStyle: .destructive,
                    onDismiss: { isShowingDeleteConfirmation = false }
                )
            }
        }
        .overlay {
            if isShowingDuplicatePrompt {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture { isShowingDuplicatePrompt = false }

                    VStack(spacing: 16) {
                        HStack {
                            Spacer()
                            Button { isShowingDuplicatePrompt = false } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 30, height: 30)
                                    .background(Color(.systemGray5))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }

                        Text("Duplicate Plan")
                            .font(.system(size: 18, weight: .bold))

                        Text("Enter a name for the duplicated plan.")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        TextField("Plan name", text: $duplicateName)
                            .font(.system(size: 15))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.black, lineWidth: 1)
                            )

                        VStack(spacing: 10) {
                            Button {
                                let name = duplicateName.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !name.isEmpty else { return }
                                isShowingDuplicatePrompt = false
                                onDuplicate(name)
                                dismiss()
                            } label: {
                                Text("Duplicate")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 13)
                                    .background(Color.black)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)

                            Button {
                                isShowingDuplicatePrompt = false
                            } label: {
                                Text("Cancel")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 13)
                                    .background(Color(.systemGray6))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(20)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
                    .padding(.horizontal, 40)
                }
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
                if let name = playlistName(for: playlistId) {
                    HStack(spacing: 4) {
                        Image(systemName: "music.note.list")
                        Text(name)
                            .font(.system(size: 11, weight: .regular))
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)

            ForEach(movements) { movement in
                MovementReadRow(movement: movement)
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
                if let name = playlistName(for: currentPlan.mainPlaylistId) {
                    HStack(spacing: 4) {
                        Image(systemName: "music.note.list")
                        Text(name)
                            .font(.system(size: 11, weight: .regular))
                    }
                    .foregroundStyle(.secondary)
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
                        MovementReadRow(movement: movement)
                            .padding(.horizontal, 20)
                    }
                }
            }
        }
    }

    // MARK: - Spotify Playlists (display-only)

    private func loadPlaylistsIfNeeded() async {
        guard spotifyManager.isAuthenticated,
              (currentPlan.warmUpPlaylistId != nil || currentPlan.mainPlaylistId != nil || currentPlan.coolDownPlaylistId != nil),
              !isLoadingPlaylists else { return }
        isLoadingPlaylists = true
        defer { isLoadingPlaylists = false }
        playlists = (try? await SpotifySearchService.shared.getMyPlaylists(limit: 50)) ?? []
    }
}

// MARK: - Movement Read Row

private struct MovementReadRow: View {
    let movement: Movement

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
                if movement.reps != nil || movement.seconds != nil {
                    HStack(spacing: 6) {
                        Image(systemName: movement.goalType == .timed ? "timer" : "arrow.2.circlepath")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                        Text(goalText)
                            .font(.system(size: 12, weight: .thin))
                            .foregroundStyle(.black)
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.black, lineWidth: 1)
        )
    }
}

// MARK: - Plan Detail Card

struct PlanDetailCard: View {
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

// MARK: - Share Sheet

private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
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
        .environmentObject(SpotifyManager.shared)
    }
}
