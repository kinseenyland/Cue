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
    @Published var elapsedSeconds: Int = 0
    @Published var totalElapsedSeconds: Int = 0

    let defaultMoveSeconds = 30

    var currentMove: Movement? {
        guard currentIndex < movements.count else { return nil }
        return movements[currentIndex]
    }

    var onDeckMove: Movement? {
        guard canGoNext else { return nil }
        return movements[currentIndex + 1]
    }

    var currentSectionLabel: String {
        guard let move = currentMove else { return "" }
        if let name = move.sectionName, !name.isEmpty { return name }
        switch move.section {
        case .warmUp: return "Warm-Up"
        case .main: return "Main"
        case .coolDown: return "Cool-Down"
        }
    }

    var upNextSectionLabel: String? {
        guard let next = onDeckMove else { return nil }
        if next.section != currentMove?.section || next.sectionName != currentMove?.sectionName {
            if let name = next.sectionName, !name.isEmpty { return name }
            switch next.section {
            case .warmUp: return "Warm-Up"
            case .main: return "Main"
            case .coolDown: return "Cool-Down"
            }
        }
        return nil
    }

    var upNextDurationMinutes: Int? {
        guard let next = onDeckMove else { return nil }
        if next.section != currentMove?.section || next.sectionName != currentMove?.sectionName {
            let targetSection = next.section
            let targetName = next.sectionName
            let sectionMoves = movements.filter { $0.section == targetSection && $0.sectionName == targetName }
            let totalSecs = sectionMoves.reduce(0) { $0 + ($1.seconds ?? defaultMoveSeconds) }
            return max(1, totalSecs / 60)
        }
        return nil
    }

    var progressValue: Double {
        guard !movements.isEmpty else { return 0 }
        return Double(currentIndex + 1) / Double(movements.count)
    }

    var canGoNext: Bool {
        guard !movements.isEmpty else { return false }
        return currentIndex < movements.count - 1
    }

    var canGoPrevious: Bool {
        return currentIndex > 0
    }

    var totalTimerFormatted: String {
        formatTime(totalElapsedSeconds)
    }

    var moveTimerFormatted: String {
        formatTime(elapsedSeconds)
    }

    func load(plan: WorkoutPlan) {
        planTitle = plan.title
        movements = plan.movements
        currentIndex = 0
        elapsedSeconds = 0
        totalElapsedSeconds = 0
        isRunning = false
    }

    func toggleRunning() {
        isRunning.toggle()
    }

    func pause() {
        isRunning = false
    }

    func nextMove() {
        guard canGoNext else { return }
        currentIndex += 1
        elapsedSeconds = 0
    }

    func previousMove() {
        guard canGoPrevious else { return }
        currentIndex -= 1
        elapsedSeconds = 0
    }

    func tick() {
        guard isRunning else { return }
        totalElapsedSeconds += 1
        elapsedSeconds += 1
    }

    func reset() {
        planTitle = "Workout"
        movements = []
        currentIndex = 0
        isRunning = false
        elapsedSeconds = 0
        totalElapsedSeconds = 0
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
