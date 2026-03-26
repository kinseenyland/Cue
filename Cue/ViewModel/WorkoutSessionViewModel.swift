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
    @Published var planId: String? = nil
    @Published var movements: [Movement] = []
    @Published var currentIndex: Int = 0
    @Published var isRunning: Bool = false
    @Published var sectionRemainingSeconds: Int = 0
    @Published var moveRemainingSeconds: Int = 0
    @Published var isComplete: Bool = false
    @Published var elapsedSeconds: Int = 0
    var planType: WorkoutType?
    var planDifficulty: Difficulty?
    var planDurationMinutes: Int = 0

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

    /// Remaining movements in the current section (excluding current move).
    var upcomingMovesInSection: [(index: Int, movement: Movement)] {
        guard let move = currentMove else { return [] }
        var result: [(index: Int, movement: Movement)] = []
        for i in (currentIndex + 1)..<movements.count {
            let m = movements[i]
            if m.section == move.section && m.sectionName == move.sectionName {
                result.append((i, m))
            } else {
                break
            }
        }
        return result
    }

    /// All upcoming sections after the current one.
    var upcomingSections: [(label: String, startIndex: Int, movements: [Movement])] {
        guard let move = currentMove else { return [] }
        var sections: [(label: String, startIndex: Int, movements: [Movement])] = []
        var i = currentIndex + 1

        // Skip past remaining moves in current section
        while i < movements.count {
            let m = movements[i]
            if m.section != move.section || m.sectionName != move.sectionName { break }
            i += 1
        }

        while i < movements.count {
            let first = movements[i]
            let label: String = {
                if let name = first.sectionName, !name.isEmpty { return name }
                switch first.section {
                case .warmUp: return "Warm-Up"
                case .main: return "Main"
                case .coolDown: return "Cool-Down"
                }
            }()
            let startIdx = i
            var sectionMoves: [Movement] = []
            while i < movements.count {
                let m = movements[i]
                if m.section == first.section && m.sectionName == first.sectionName {
                    sectionMoves.append(m)
                    i += 1
                } else {
                    break
                }
            }
            sections.append((label, startIdx, sectionMoves))
        }
        return sections
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
        planId = plan.id
        movements = plan.movements
        currentIndex = 0
        isRunning = true
        elapsedSeconds = 0
        planType = plan.type
        planDifficulty = plan.difficulty
        planDurationMinutes = plan.durationMinutes
        warmUpPlaylistId = plan.warmUpPlaylistId
        mainPlaylistId = plan.mainPlaylistId
        coolDownPlaylistId = plan.coolDownPlaylistId
        resetSectionTimer()
        resetMoveTimer()
        // Ensure App Remote is connected so UI receives live now-playing updates.
        _ = SpotifyManager.shared.connectAppRemoteIfNeeded()
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
        elapsedSeconds += 1
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
        SpotifyManager.shared.pausePlayback()
        planTitle = "Workout"
        planId = nil
        movements = []
        currentIndex = 0
        isRunning = false
        isComplete = false
        elapsedSeconds = 0
        planType = nil
        planDifficulty = nil
        planDurationMinutes = 0
        sectionRemainingSeconds = 0
        moveRemainingSeconds = 0
    }

    var elapsedTimeFormatted: String {
        formatTime(elapsedSeconds)
    }

    var remainingSeconds: Int {
        max(0, planDurationMinutes * 60 - elapsedSeconds)
    }

    var remainingTimeFormatted: String {
        formatTime(remainingSeconds)
    }

    var warmUpCount: Int { movements.filter { $0.section == .warmUp }.count }
    var mainCount: Int { movements.filter { $0.section == .main }.count }
    var coolDownCount: Int { movements.filter { $0.section == .coolDown }.count }

    var currentSectionPosition: (index: Int, total: Int) {
        guard let move = currentMove else { return (0, 0) }
        let sectionMoves = movements.filter {
            $0.section == move.section && $0.sectionName == move.sectionName
        }
        let posInSection = sectionMoves.firstIndex(where: { $0.id == move.id }) ?? 0
        return (posInSection + 1, sectionMoves.count)
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
        // Force now-playing/queue refresh on section playlist changes.
        SpotifyManager.shared.requestAppRemotePlayerStateNow()
        SpotifyManager.shared.refreshPlaybackStateNow()
        SpotifyManager.shared.refreshQueueWithBurst()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 800_000_000)
            SpotifyManager.shared.requestAppRemotePlayerStateNow()
            SpotifyManager.shared.refreshPlaybackStateNow()
            SpotifyManager.shared.refreshQueueWithBurst()
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
