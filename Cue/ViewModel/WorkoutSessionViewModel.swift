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
    @Published var sectionRemainingSeconds: Int = 0
    @Published var moveRemainingSeconds: Int = 0
    @Published var isComplete: Bool = false

    var warmUpPlaylistId: String?
    var mainPlaylistId: String?
    var coolDownPlaylistId: String?

    let defaultMoveSeconds = 30

    var currentMove: Movement? {
        guard currentIndex < movements.count else { return nil }
        return movements[currentIndex]
    }

    var onDeckMove: Movement? {
        guard canGoNext else { return nil }
        return movements[currentIndex + 1]
    }

    /// Next upcoming movements (up to 4), spanning across all sections.
    var upcomingMoves: [(index: Int, movement: Movement)] {
        guard currentIndex < movements.count else { return [] }
        var result: [(index: Int, movement: Movement)] = []
        for i in (currentIndex + 1)..<movements.count {
            if result.count >= 4 { break }
            result.append((i, movements[i]))
        }
        return result
    }

    /// The next section's label, start index, and movements (first group after the current section).
    var nextSectionInfo: (label: String, startIndex: Int, movements: [Movement])? {
        guard let move = currentMove else { return nil }
        guard let startIdx = ((currentIndex + 1)..<movements.count).first(where: { i in
            let m = movements[i]
            return m.section != move.section || m.sectionName != move.sectionName
        }) else { return nil }

        let firstNext = movements[startIdx]
        let label: String = {
            if let name = firstNext.sectionName, !name.isEmpty { return name }
            switch firstNext.section {
            case .warmUp: return "Warm-Up"
            case .main: return "Main"
            case .coolDown: return "Cool-Down"
            }
        }()

        var sectionMoves: [Movement] = []
        for i in startIdx..<movements.count {
            let m = movements[i]
            if m.section == firstNext.section && m.sectionName == firstNext.sectionName {
                sectionMoves.append(m)
            } else {
                break
            }
        }
        return (label, startIdx, sectionMoves)
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
            if let mins = next.sectionDurationMinutes { return mins }
            let totalSecs = sectionTotalSeconds(for: next)
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

    var sectionTimerFormatted: String {
        formatTime(sectionRemainingSeconds)
    }

    var moveTimerFormatted: String {
        formatTime(moveRemainingSeconds)
    }

    func load(plan: WorkoutPlan) {
        planTitle = plan.title
        movements = plan.movements
        currentIndex = 0
        isRunning = true
        warmUpPlaylistId = plan.warmUpPlaylistId
        mainPlaylistId = plan.mainPlaylistId
        coolDownPlaylistId = plan.coolDownPlaylistId
        resetSectionTimer()
        resetMoveTimer()
        startPlaylistForCurrentSectionIfAny()
    }

    func toggleRunning() {
        isRunning.toggle()
    }

    func pause() {
        isRunning = false
    }

    func nextMove() {
        guard canGoNext else {
            completeWorkout()
            return
        }
        let oldMove = currentMove
        currentIndex += 1
        let newMove = currentMove
        if oldMove?.section != newMove?.section || oldMove?.sectionName != newMove?.sectionName {
            resetSectionTimer()
            // Only change playlist when moving between warm-up / main / cool-down,
            // not when changing subsections within main.
            if oldMove?.section != newMove?.section {
                startPlaylistForCurrentSectionIfAny()
            }
        }
        resetMoveTimer()
    }

    func completeWorkout() {
        isRunning = false
        isComplete = true
    }

    func jumpToMove(at index: Int) {
        guard index >= 0, index < movements.count else { return }
        let oldMove = currentMove
        currentIndex = index
        let newMove = currentMove
        if oldMove?.section != newMove?.section || oldMove?.sectionName != newMove?.sectionName {
            resetSectionTimer()
            if oldMove?.section != newMove?.section {
                startPlaylistForCurrentSectionIfAny()
            }
        }
        resetMoveTimer()
    }

    func previousMove() {
        guard canGoPrevious else { return }
        let oldMove = currentMove
        currentIndex -= 1
        let newMove = currentMove
        if oldMove?.section != newMove?.section || oldMove?.sectionName != newMove?.sectionName {
            resetSectionTimer()
            if oldMove?.section != newMove?.section {
                startPlaylistForCurrentSectionIfAny()
            }
        }
        resetMoveTimer()
    }

    func tick() {
        guard isRunning else { return }
        if sectionRemainingSeconds > 0 {
            sectionRemainingSeconds -= 1
        }
        guard let move = currentMove, move.goalType == .timed else { return }
        if moveRemainingSeconds > 0 {
            moveRemainingSeconds -= 1
        } else if !canGoNext {
            completeWorkout()
        }
    }

    func reset() {
        planTitle = "Workout"
        movements = []
        currentIndex = 0
        isRunning = false
        isComplete = false
        sectionRemainingSeconds = 0
        moveRemainingSeconds = 0
    }

    // MARK: - Helpers

    private func resetSectionTimer() {
        guard let move = currentMove else { sectionRemainingSeconds = 0; return }
        if let mins = move.sectionDurationMinutes {
            sectionRemainingSeconds = mins * 60
        } else {
            sectionRemainingSeconds = sectionTotalSeconds(for: move)
        }
    }

    private func resetMoveTimer() {
        guard let move = currentMove, move.goalType == .timed else {
            moveRemainingSeconds = 0
            return
        }
        moveRemainingSeconds = move.seconds ?? defaultMoveSeconds
    }

    private func sectionTotalSeconds(for move: Movement) -> Int {
        let sectionMoves = movements.filter {
            $0.section == move.section && $0.sectionName == move.sectionName
        }
        return sectionMoves.reduce(0) { total, m in
            total + (m.seconds ?? defaultMoveSeconds)
        }
    }

    private func startPlaylistForCurrentSectionIfAny() {
        guard let move = currentMove else { return }
        let playlistId: String?
        switch move.section {
        case .warmUp:
            playlistId = warmUpPlaylistId
        case .main:
            playlistId = mainPlaylistId
        case .coolDown:
            playlistId = coolDownPlaylistId
        }
        guard let pid = playlistId, !pid.isEmpty else { return }
        SpotifyManager.shared.playPlaylistFromStart(playlistUri: pid)
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
