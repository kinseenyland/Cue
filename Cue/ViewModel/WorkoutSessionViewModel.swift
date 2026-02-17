//
//  WorkoutSessionViewModel.swift
//  Cue
//
//  Created by Kinsee Nyland on 2/10/26.
//

import Combine
import Foundation
import SwiftUI

@MainActor
final class WorkoutSessionViewModel: ObservableObject {
    @Published var planTitle: String = "Workout"
    @Published var movements: [Movement] = []
    @Published var currentIndex: Int = 0
    @Published var isRunning: Bool = false
    @Published var remainingSeconds: Int = 30

    let defaultMoveSeconds = 30

    var currentMove: Movement? {
        guard !movements.isEmpty else { return nil }
        return movements[currentIndex]
    }

    var progressValue: Double {
        guard !movements.isEmpty else { return 0 }
        return Double(currentIndex + 1) / Double(movements.count)
    }

    func load(plan: WorkoutPlan) {
        planTitle = plan.title
        movements = plan.movements
        currentIndex = 0
        if let first = movements.first, first.goalType == .timed {
            remainingSeconds = first.seconds ?? defaultMoveSeconds
        } else {
            remainingSeconds = 0
        }
        isRunning = false
    }

    func toggleRunning() {
        isRunning.toggle()
    }

    func pause() {
        isRunning = false
    }

    func nextMove() {
        guard !movements.isEmpty else { return }
        currentIndex = (currentIndex + 1) % movements.count
        let move = movements[currentIndex]
        if move.goalType == .timed {
            remainingSeconds = move.seconds ?? defaultMoveSeconds
        } else {
            remainingSeconds = 0
        }
    }

    func tick() {
        guard isRunning else { return }
        guard let move = currentMove, move.goalType == .timed else { return }
        if remainingSeconds > 0 {
            remainingSeconds -= 1
        } else {
            nextMove()
        }
    }
    
    func reset() {
        planTitle = "Workout"
        movements = []
        currentIndex = 0
        isRunning = false
        remainingSeconds = 30
    }
}
