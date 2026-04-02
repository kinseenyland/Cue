//
//  PlanCreationView.swift
//  Cue
//

import SwiftUI

struct PlanCreationView: View {
    @StateObject private var vm: PlanCreationViewModel
    let onSave: (WorkoutPlanDraft) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showExitConfirmation = false

    init(
        availableTypes: [WorkoutType] = WorkoutType.allCases,
        workoutStructure: WorkoutStructurePreference? = nil,
        musicApproach: MusicApproach? = nil,
        onSave: @escaping (WorkoutPlanDraft) -> Void
    ) {
        _vm = StateObject(wrappedValue: PlanCreationViewModel(
            availableTypes: availableTypes,
            workoutStructure: workoutStructure,
            musicApproach: musicApproach
        ))
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            progressBar

            // Step content — each step's view will slot in here
            stepContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            continueButton
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
        }
        .background(Color.white.ignoresSafeArea())
        .environmentObject(vm)
        .overlay {
            if showExitConfirmation {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture { showExitConfirmation = false }

                VStack(spacing: 16) {
                    HStack {
                        Spacer()
                        Button { showExitConfirmation = false } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 30, height: 30)
                                .background(Color(.systemGray5))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }

                    Text("Are you sure?")
                        .font(.system(size: 18, weight: .bold))

                    Text("Your progress will be lost if you leave.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    VStack(spacing: 10) {
                        Button {
                            showExitConfirmation = false
                        } label: {
                            Text("Keep Editing")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)

                        Button {
                            showExitConfirmation = false
                            dismiss()
                        } label: {
                            Text("Discard Plan")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(Color.red)
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
        .animation(.easeInOut(duration: 0.2), value: showExitConfirmation)
        .interactiveDismissDisabled(true)
        .onChange(of: vm.draft.durationMinutes) { _, _ in vm.redistributeMainSectionTime() }
        .onChange(of: vm.draft.warmUpDurationMinutes) { _, _ in vm.redistributeMainOnly() }
        .onChange(of: vm.draft.coolDownDurationMinutes) { _, _ in vm.redistributeMainOnly() }
        .onChange(of: vm.draft.mainSections.count) { _, _ in vm.redistributeMainSectionTime() }
        .onChange(of: vm.totalMainMinutes) { _, _ in vm.redistributeWarmUpCoolDownFromMain() }
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            HStack {
                if !vm.isOnFirstStep {
                    Button {
                        vm.back()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.black)
                    }
                }
                Spacer()
                Button {
                    showExitConfirmation = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(vm.isOnFirstStep ? .gray : .black)
                }
            }

            Text(vm.step.title)
                .font(.system(size: 17, weight: .semibold))
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(height: 3)
                Rectangle()
                    .fill(Color.black)
                    .frame(width: geo.size.width * progress, height: 3)
                    .animation(.easeInOut(duration: 0.25), value: progress)
            }
        }
        .frame(height: 3)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        switch vm.step {
        case .name:
            PlanNameStepView()
        case .type:
            PlanTypeStepView()
        case .duration:
            PlanDurationStepView()
        case .musicApproachChoice:
            MusicApproachChoiceStepView()
        case .pickMusic:
            PlanPickMusicStepView()
        case .warmUpMovements:
            VStack(alignment: .leading, spacing: 12) {
                MovementListStepView(
                    headline: "Warm-Up Movements",
                    defaultGoalType: vm.draft.goalType,
                    showGoalOption: vm.showGoalOption,
                    durationMinutes: vm.draft.warmUpDurationMinutes,
                    movements: $vm.draft.warmUpMovements
                )
                if vm.showInlinePlaylistPickers {
                    PlanSectionPlaylistPicker(
                        title: "Warm-up playlist",
                        selectedPlaylistId: $vm.draft.warmUpPlaylistId
                    )
                } else if let name = vm.playlistName(for: vm.draft.warmUpPlaylistId) {
                    AssignedPlaylistLabel(name: name)
                        .padding(.horizontal, 24)
                }
            }
        case .mainSections:
            VStack(alignment: .leading, spacing: 12) {
                PlanMainSectionsStepView()
                if vm.showInlinePlaylistPickers {
                    PlanSectionPlaylistPicker(
                        title: "Main workout playlist",
                        selectedPlaylistId: $vm.draft.mainPlaylistId
                    )
                } else if let name = vm.playlistName(for: vm.draft.mainPlaylistId) {
                    AssignedPlaylistLabel(name: name)
                        .padding(.horizontal, 24)
                }
            }
        case .mainMovements:
            PlanMainMovementsStepView()
        case .coolDownMovements:
            VStack(alignment: .leading, spacing: 12) {
                MovementListStepView(
                    headline: "Cool-Down Movements",
                    defaultGoalType: vm.draft.goalType,
                    showGoalOption: vm.showGoalOption,
                    durationMinutes: vm.draft.coolDownDurationMinutes,
                    movements: $vm.draft.coolDownMovements
                )
                if vm.showInlinePlaylistPickers {
                    PlanSectionPlaylistPicker(
                        title: "Cool-down playlist",
                        selectedPlaylistId: $vm.draft.coolDownPlaylistId
                    )
                } else if let name = vm.playlistName(for: vm.draft.coolDownPlaylistId) {
                    AssignedPlaylistLabel(name: name)
                        .padding(.horizontal, 24)
                }
            }
        case .review:
            PlanReviewStepView()
        }
    }

    // MARK: - Continue / Save Button

    private var continueButton: some View {
        Button {
            if vm.isOnLastStep {
                onSave(vm.toWorkoutPlanDraft())
                dismiss()
            } else {
                vm.advance()
            }
        } label: {
            Text(vm.isOnLastStep ? "Save Plan" : "Continue")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(vm.canAdvance ? Color.black : Color(.systemGray4))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(!vm.canAdvance)
    }

    // MARK: - Helpers

    private var progress: Double { vm.progress }
}

// MARK: - Playlist picker per section

struct PlanSectionPlaylistPicker: View {
    let title: String
    @Binding var selectedPlaylistId: String?
    @EnvironmentObject private var vm: PlanCreationViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)

            if vm.spotifyPlaylists.isEmpty {
                HStack {
                    if vm.isLoadingPlaylists {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading Spotify playlists…")
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

                if let error = vm.playlistsError {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 24)
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // None chip
                        Button {
                            selectedPlaylistId = nil
                        } label: {
                            Text("None")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(selectedPlaylistId == nil ? Color.white : Color.black)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(selectedPlaylistId == nil ? Color.black : Color.clear)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.black.opacity(0.2), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)

                        ForEach(vm.spotifyPlaylists, id: \.uri) { playlist in
                            Button {
                                selectedPlaylistId = playlist.uri   // store full context_uri
                            } label: {
                                Text(playlist.name)
                                    .lineLimit(1)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(selectedPlaylistId == playlist.uri ? Color.white : Color.black)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(selectedPlaylistId == playlist.uri ? Color.black : Color.clear)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.black.opacity(0.2), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

#Preview {
    PlanCreationView { _ in }
}
