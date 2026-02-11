//
//  PlayerView.swift
//  Cue
//
//  Created by Kinsee Nyland on 2/10/26.
//

import SwiftUI

struct PlayerView: View {
    @EnvironmentObject private var sessionVM: WorkoutSessionViewModel

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(sessionVM.planTitle)
                        .font(.title3).bold()

                    ProgressView(value: sessionVM.progressValue)
                        .tint(.orange)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(sessionVM.currentMove?.name ?? "No movement")
                            .font(.title2).bold()
                        Text(goalDetailText)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 4) {
                            Image(systemName: "timer")
                            Text(timerText)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(primaryValueText)
                        .font(.system(size: 44, weight: .bold))
                        .monospacedDigit()
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(16)

                Spacer()

                HStack(spacing: 12) {
                    Button("Next Move") {
                        sessionVM.nextMove()
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.bordered)

                    Button {
                        sessionVM.toggleRunning()
                    } label: {
                        Image(systemName: sessionVM.isRunning ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.orange)
                    }
                }
            }
            .padding()
            .navigationTitle("Workout")
        }
        .onReceive(timer) { _ in
            sessionVM.tick()
        }
    }

    private var goalDetailText: String {
        guard let move = sessionVM.currentMove else { return "Select a plan to begin." }
        switch move.goalType {
        case .timed:
            return "Timed movement"
        case .reps:
            return "Complete reps"
        }
    }

    private var timerText: String {
        guard let move = sessionVM.currentMove else { return "0s remaining" }
        switch move.goalType {
        case .timed:
            return "\(sessionVM.remainingSeconds)s remaining"
        case .reps:
            return "\(move.reps ?? 0) reps"
        }
    }

    private var primaryValueText: String {
        guard let move = sessionVM.currentMove else { return "0" }
        switch move.goalType {
        case .timed:
            return "\(sessionVM.remainingSeconds)"
        case .reps:
            return "\(move.reps ?? 0)"
        }
    }
}

#Preview {
    PlayerView()
}
