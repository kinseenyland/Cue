//
//  PlayerView.swift
//  Cue
//
//  Created by Kinsee Nyland on 2/10/26.
//

import Combine
import SwiftUI

struct PlayerView: View {
    @Binding var selectedTab: MainTab
    @EnvironmentObject private var sessionVM: WorkoutSessionViewModel
    @EnvironmentObject private var spotifyManager: SpotifyManager
    @StateObject private var vm = CueViewModel()
    @State private var showExitConfirmation = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if sessionVM.isComplete {
                completionView
            } else if sessionVM.movements.isEmpty {
                planSelectionView
            } else {
                workoutPlayerView
            }
        }
        .onChange(of: sessionVM.isComplete) { complete in
            if complete, let planId = sessionVM.planId {
                Task { await vm.markPlanAsRun(id: planId) }
            }
        }
    }

    // MARK: - Plan Selection

    private var planSelectionView: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if vm.plans.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "figure.run")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                            Text("No workout plans yet")
                                .font(.headline)
                            Text("Create one in the Plans tab to get started.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    } else {
                        ForEach(vm.plans) { plan in
                            Button {
                                sessionVM.load(plan: plan)
                            } label: {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(plan.title)
                                            .font(.body)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.primary)
                                        Text("\(plan.type.displayName) · \(plan.difficulty.rawValue.capitalized) · \(plan.durationMinutes) min")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "play.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(.black)
                                }
                                .padding(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(.systemGray4), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.top, 8)
            }
            .navigationTitle("Workout")
            .task {
                await vm.fetchPlans()
            }
        }
    }

    // MARK: - Workout Player

    private var workoutPlayerView: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    showExitConfirmation = true
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.black)
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)

            ScrollView {
                VStack(spacing: 0) {
                    Text(sessionVM.planTitle)
                        .font(.system(size: 17))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 4)

                    Text(sessionVM.currentSectionLabel)
                        .font(.system(size: 32, weight: .bold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 8)

                    if let move = sessionVM.currentMove {
                        movementCard(move)
                            .padding(.horizontal)
                            .padding(.top, 12)
                    }

                    upcomingMovesList
                        .padding(.horizontal)
                        .padding(.top, 12)

                    upcomingSectionsView
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 16)
                }
            }

            spotifyBar
                .padding(.horizontal)
                .padding(.bottom, 8)
        }
        .onReceive(timer) { _ in
            sessionVM.tick()
        }
        .alert("End Workout?", isPresented: $showExitConfirmation) {
            Button("Keep Going", role: .cancel) { }
            Button("End Workout", role: .destructive) {
                sessionVM.reset()
                selectedTab = .plans
            }
        } message: {
            Text("Are you sure you want to end this workout? Your progress will be lost.")
        }
    }

    // MARK: - Movement Card

    private func movementCard(_ move: Movement) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Text(move.name)
                    .font(.system(size: 30, weight: .bold))
                Spacer()
                if move.goalType == .timed, let seconds = move.seconds {
                    Text("\(seconds)s")
                        .font(.system(size: 15, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.black, lineWidth: 1.5)
                        )
                } else if let reps = move.reps {
                    Text("\(reps) reps")
                        .font(.system(size: 15, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.black, lineWidth: 1.5)
                        )
                }
            }

            if let notes = move.notes, !notes.isEmpty {
                let lines = notes.components(separatedBy: "\n").filter { !$0.isEmpty }
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(lines, id: \.self) { line in
                        HStack(alignment: .top, spacing: 10) {
                            Circle()
                                .fill(Color.black)
                                .frame(width: 6, height: 6)
                                .padding(.top, 6)
                            Text(line)
                                .font(.system(size: 15))
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }

            HStack {
                Button {
                    sessionVM.previousMove()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.black))
                }
                .disabled(!sessionVM.canGoPrevious)
                .opacity(sessionVM.canGoPrevious ? 1.0 : 0.3)

                Spacer()

                Button {
                    sessionVM.nextMove()
                } label: {
                    Image(systemName: sessionVM.canGoNext ? "chevron.right" : "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.black))
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }

    // MARK: - Upcoming Moves List

    private var upcomingMovesList: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !sessionVM.upcomingMovesInSection.isEmpty {
                Text("Up Next")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(sessionVM.upcomingMovesInSection, id: \.movement.id) { item in
                moveRow(item.movement)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        sessionVM.jumpToMove(at: item.index)
                    }
            }
        }
    }

    // MARK: - Upcoming Sections

    private var upcomingSectionsView: some View {
        Group {
            if let section = sessionVM.upcomingSections.first {
                VStack(alignment: .leading, spacing: 8) {
                    if sessionVM.upcomingMovesInSection.isEmpty {
                        Text("Up Next")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    SectionDropdown(
                        label: section.label,
                        movements: section.movements,
                        onTapLabel: {
                            sessionVM.jumpToMove(at: section.startIndex)
                        }
                    )
                    .id(sessionVM.currentIndex)
                }
            }
        }
    }

    // MARK: - Move Row

    private func moveRow(_ move: Movement) -> some View {
        HStack {
            Text(move.name)
                .font(.body)
                .foregroundStyle(.primary)
            Spacer()
            if move.goalType == .timed, let seconds = move.seconds {
                Text("\(seconds)s")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if let reps = move.reps {
                Text("\(reps) reps")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }

    // MARK: - Completion

    private var completionView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.black)

            Text("Workout Complete!")
                .font(.system(size: 28, weight: .bold))

            Text(sessionVM.planTitle)
                .font(.title3)
                .foregroundStyle(.secondary)

            Text("\(sessionVM.movements.count) movements finished")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                sessionVM.reset()
                selectedTab = .plans
            } label: {
                Text("Done")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.black)
                    )
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Music Card (placeholder for coworker)

    private var spotifyBar: some View {
        HStack(spacing: 12) {
            if let art = spotifyManager.currentArtwork {
                Image(uiImage: art)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.systemGray4))
                    .frame(width: 48, height: 48)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(spotifyManager.currentTrackName.isEmpty ? "No song playing" : spotifyManager.currentTrackName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(spotifyManager.currentArtistName.isEmpty ? "" : spotifyManager.currentArtistName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 16) {
                Button {
                    spotifyManager.previousTrack()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.title3)
                        .foregroundStyle(.black)
                }
                .buttonStyle(.plain)

                Button {
                    spotifyManager.togglePlayPause()
                } label: {
                    Image(systemName: spotifyManager.isPaused ? "play.fill" : "pause.fill")
                        .font(.title3)
                        .foregroundStyle(.black)
                }
                .buttonStyle(.plain)

                Button {
                    spotifyManager.nextTrack()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.title3)
                        .foregroundStyle(.black)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
}

// MARK: - Section Dropdown

private struct SectionDropdown: View {
    let label: String
    let movements: [Movement]
    let onTapLabel: () -> Void
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text(label)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { onTapLabel() }

                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .padding(8)
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, 14)
            .padding(.trailing, 6)
            .padding(.vertical, 6)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )

            if isExpanded {
                Text(movements.map(\.name).joined(separator: ", "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

#Preview {
    PlayerView(selectedTab: .constant(.workout))
        .environmentObject(WorkoutSessionViewModel())
}
