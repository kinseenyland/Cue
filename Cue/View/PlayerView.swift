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

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        if sessionVM.isComplete {
            completionView
        } else if sessionVM.movements.isEmpty {
            planSelectionView
        } else {
            workoutPlayerView
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
                                        Text("\(plan.type.rawValue.capitalized) · \(plan.difficulty.rawValue.capitalized) · \(plan.durationMinutes) min")
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
            // Back button
            HStack {
                Button {
                    sessionVM.reset()
                    selectedTab = .plans
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.black)
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // Plan title
            Text(sessionVM.planTitle)
                .font(.system(size: 17))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top, 4)

            // Section name + total timer
            HStack(alignment: .firstTextBaseline) {
                Text(sessionVM.currentSectionLabel)
                    .font(.system(size: 32, weight: .bold))
                Spacer()
                Text(sessionVM.sectionTimerFormatted)
                    .font(.system(size: 48, weight: .bold))
                    .monospacedDigit()
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // Current movement card
            if let move = sessionVM.currentMove {
                movementCard(move)
                    .padding(.horizontal)
                    .padding(.top, 12)
            }

            // Up Next
            if let nextMove = sessionVM.onDeckMove {
                upNextSection(nextMove)
                    .padding(.horizontal)
                    .padding(.top, 16)
            }

            Spacer()

            // Spotify now playing bar
            spotifyBar
                .padding(.horizontal)
                .padding(.bottom, 8)
        }
        .onReceive(timer) { _ in
            sessionVM.tick()
        }
    }

    // MARK: - Movement Card

    private func movementCard(_ move: Movement) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Text(move.name)
                    .font(.system(size: 24, weight: .medium))
                Spacer()
                if move.goalType == .timed {
                    Text(sessionVM.moveTimerFormatted)
                        .font(.system(size: 20, weight: .bold))
                        .monospacedDigit()
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.black, lineWidth: 2)
                        )
                } else if let reps = move.reps {
                    Text("\(reps) reps")
                        .font(.system(size: 20, weight: .bold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.black, lineWidth: 2)
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

            HStack(spacing: 16) {
                Button {
                    sessionVM.previousMove()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 50, height: 50)
                        .background(Circle().fill(Color.black))
                }
                .disabled(!sessionVM.canGoPrevious)
                .opacity(sessionVM.canGoPrevious ? 1.0 : 0.3)

                Spacer()

                Button {
                    sessionVM.nextMove()
                } label: {
                    if sessionVM.canGoNext {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 50, height: 50)
                            .background(Circle().fill(Color.black))
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 50, height: 50)
                            .background(Circle().fill(Color.black))
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }

    // MARK: - Up Next

    private func upNextSection(_ nextMove: Movement) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Up Next:")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(nextMove.name)
                        .font(.body)
                        .fontWeight(.semibold)
                    if nextMove.goalType == .timed, let seconds = nextMove.seconds {
                        HStack(spacing: 4) {
                            Image(systemName: "timer")
                                .font(.caption)
                            Text("\(seconds)s")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    } else if let reps = nextMove.reps {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.caption)
                            Text("\(reps) reps")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
        }
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

#Preview {
    PlayerView(selectedTab: .constant(.workout))
        .environmentObject(WorkoutSessionViewModel())
}
