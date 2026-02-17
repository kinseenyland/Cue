//
//  PlayerView.swift
//  Cue
//
//  Created by Kinsee Nyland on 2/10/26.
//

import Combine
import SwiftUI

struct PlayerView: View {
    @EnvironmentObject private var sessionVM: WorkoutSessionViewModel
    @StateObject private var vm = CueViewModel()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            if sessionVM.movements.isEmpty {
                // Show plan selection list when no plan is loaded
                planSelectionView
            } else {
                // Show workout player when a plan is loaded
                workoutPlayerView
            }
        }
        .task {
            await vm.fetchPlans()
        }
        .onReceive(timer) { _ in
            sessionVM.tick()
        }
    }
    
    private var planSelectionView: some View {
        List {
            if let status = vm.statusMessage {
                Text(status)
                    .foregroundStyle(.green)
            }

            if let error = vm.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
            }

            if vm.plans.isEmpty {
                Text("No workout plans yet. Create one in the Plans tab!")
                    .foregroundStyle(.secondary)
                    .padding()
            }

            ForEach(vm.plans) { plan in
                Button {
                    sessionVM.load(plan: plan)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(plan.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("Type: \(plan.type.rawValue.capitalized) • Difficulty: \(plan.difficulty.rawValue.capitalized) • Time: \(plan.durationMinutes) mins")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if !plan.movements.isEmpty {
                            Text(plan.movements.map { $0.name }.joined(separator: ", "))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Workout")
    }
    
    private var workoutPlayerView: some View {
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
            
            Button("Select Different Plan") {
                sessionVM.reset()
            }
            .buttonStyle(.bordered)
            .foregroundStyle(.secondary)
        }
        .padding()
        .navigationTitle("Workout")
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
