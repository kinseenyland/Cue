//
//  PlanCreationView.swift
//  Cue
//

import SwiftUI

struct PlanCreationView: View {
    @StateObject private var vm = PlanCreationViewModel()
    let onSave: (WorkoutPlanDraft) -> Void
    @Environment(\.dismiss) private var dismiss

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
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            HStack {
                if vm.isOnFirstStep {
                    Button("Cancel") { dismiss() }
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                } else {
                    Button {
                        vm.back()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.black)
                    }
                }
                Spacer()
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
        case .warmUpIntro:
            PlanSectionIntroStepView(
                headline: "Let's warm up.",
                subtext: "Suggested ~5 min · Add the movements you use to prepare your class.",
                bullets: [
                    "Dynamic stretches, mobility work, or light cardio",
                    "Movements that raise heart rate gradually",
                    "Prep for the main workout ahead"
                ]
            )
        case .warmUpMovements:
            VStack(alignment: .leading, spacing: 12) {
                MovementListStepView(
                    headline: "Warm-Up Movements",
                    defaultGoalType: vm.draft.goalType,
                    durationMinutes: $vm.draft.warmUpDurationMinutes,
                    movements: $vm.draft.warmUpMovements
                )
                PlanSectionPlaylistPicker(
                    title: "Warm-up playlist",
                    selectedPlaylistId: $vm.draft.warmUpPlaylistId
                )
            }
        case .mainSections:
            VStack(alignment: .leading, spacing: 12) {
                PlanMainSectionsStepView()
                PlanSectionPlaylistPicker(
                    title: "Main workout playlist",
                    selectedPlaylistId: $vm.draft.mainPlaylistId
                )
            }
        case .mainMovements:
            PlanMainMovementsStepView()
        case .coolDownIntro:
            PlanSectionIntroStepView(
                headline: "Wind it down.",
                subtext: "Suggested ~5 min · Add the movements you use to close out your class.",
                bullets: [
                    "Static stretches and breathing exercises",
                    "Movements that lower heart rate",
                    "Help your class recover and reflect"
                ]
            )
        case .coolDownMovements:
            VStack(alignment: .leading, spacing: 12) {
                MovementListStepView(
                    headline: "Cool-Down Movements",
                    defaultGoalType: vm.draft.goalType,
                    durationMinutes: $vm.draft.coolDownDurationMinutes,
                    movements: $vm.draft.coolDownMovements
                )
                PlanSectionPlaylistPicker(
                    title: "Cool-down playlist",
                    selectedPlaylistId: $vm.draft.coolDownPlaylistId
                )
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

    private var progress: Double {
        Double(vm.step.rawValue + 1) / Double(PlanCreationStep.total)
    }
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

                        ForEach(vm.spotifyPlaylists, id: \.id) { playlist in
                            Button {
                                selectedPlaylistId = playlist.id
                            } label: {
                                Text(playlist.name)
                                    .lineLimit(1)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(selectedPlaylistId == playlist.id ? Color.white : Color.black)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(selectedPlaylistId == playlist.id ? Color.black : Color.clear)
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
