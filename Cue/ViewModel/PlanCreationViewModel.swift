//
//  PlanCreationViewModel.swift
//  Cue
//

import Combine
import Foundation
import SwiftUI

enum PlanCreationStep: Int, CaseIterable {
    case name               = 0
    case type               = 1
    case duration           = 2
    case warmUpMovements    = 3
    case mainSections       = 4
    case mainMovements      = 5
    case coolDownMovements  = 6
    case review             = 7

    static let total = Self.allCases.count

    var title: String {
        switch self {
        case .name:             return "Name Your Plan"
        case .type:             return "Workout Type"
        case .duration:         return "Duration"
        case .warmUpMovements:  return "Warm-Up Movements"
        case .mainSections:     return "Main Workout"
        case .mainMovements:    return "Main Movements"
        case .coolDownMovements: return "Cool-Down Movements"
        case .review:           return "Review"
        }
    }
}

@MainActor
final class PlanCreationViewModel: ObservableObject {
    @Published var step: PlanCreationStep = .name
    @Published var draft = PlanCreationDraft()
    /// Set by movement step views; returns true if a pending movement was saved (don't advance).
    var flushPendingMovement: (() -> Bool)? = nil
    @Published var hasPendingMovement = false
    @Published var spotifyPlaylists: [SpotifySearchService.SpotifyPlaylist] = []
    @Published var isLoadingPlaylists = false
    @Published var playlistsError: String? = nil

    var canAdvance: Bool {
        switch step {
        case .name:
            return !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .type:
            return draft.type != nil && draft.difficulty != nil
        case .duration:
            return draft.durationMinutes > 0
        case .warmUpMovements:
            return !draft.warmUpMovements.isEmpty || hasPendingMovement
        case .mainSections:
            return !draft.mainSections.isEmpty &&
                draft.mainSections.allSatisfy { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        case .mainMovements:
            return draft.mainSections.allSatisfy { !$0.movements.isEmpty } || hasPendingMovement
        case .coolDownMovements:
            return !draft.coolDownMovements.isEmpty || hasPendingMovement
        case .review:
            return true
        }
    }

    var isOnFirstStep: Bool { step == .name }
    var isOnLastStep: Bool { step == .review }

    var suggestedMainMinutes: Int { max(0, draft.durationMinutes - 10) }

    func advance() {
        guard canAdvance else { return }
        if let flush = flushPendingMovement, flush() { return }
        guard let next = PlanCreationStep(rawValue: step.rawValue + 1) else { return }
        step = next
    }

    func back() {
        guard let prev = PlanCreationStep(rawValue: step.rawValue - 1) else { return }
        step = prev
    }

    /// Converts the finished draft into a WorkoutPlanDraft for persisting to Firestore.
    /// Movements are flattened: warm-up → main sections → cool-down, each tagged with section info.
    func toWorkoutPlanDraft() -> WorkoutPlanDraft {
        let warmUp = draft.warmUpMovements.map { m -> Movement in
            var copy = m; copy.section = .warmUp; copy.sectionName = nil
            copy.sectionDurationMinutes = draft.warmUpDurationMinutes; return copy
        }
        let main = draft.mainSections.flatMap { section -> [Movement] in
            section.movements.map { m -> Movement in
                var copy = m
                copy.section = .main
                copy.sectionName = section.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : section.name
                copy.sectionDurationMinutes = section.durationMinutes
                return copy
            }
        }
        let coolDown = draft.coolDownMovements.map { m -> Movement in
            var copy = m; copy.section = .coolDown; copy.sectionName = nil
            copy.sectionDurationMinutes = draft.coolDownDurationMinutes; return copy
        }

        return WorkoutPlanDraft(
            title: draft.name,
            type: draft.type ?? .strength,
            difficulty: draft.difficulty ?? .medium,
            durationMinutes: draft.durationMinutes,
            movements: warmUp + main + coolDown,
            warmUpPlaylistId: draft.warmUpPlaylistId,
            mainPlaylistId: draft.mainPlaylistId,
            coolDownPlaylistId: draft.coolDownPlaylistId
        )
    }

    func loadSpotifyPlaylistsIfNeeded() async {
        if !spotifyPlaylists.isEmpty || isLoadingPlaylists { return }
        isLoadingPlaylists = true
        playlistsError = nil
        defer { isLoadingPlaylists = false }
        do {
            spotifyPlaylists = try await SpotifySearchService.shared.getMyPlaylists(limit: 50)
        } catch SpotifySearchService.SpotifyError.apiError(let status, let message) {
            playlistsError = message ?? "Could not load playlists (\(status))."
        } catch SpotifySearchService.SpotifyError.notAuthenticated {
            playlistsError = "Connect to Spotify and allow playlists to choose a playlist."
        } catch SpotifySearchService.SpotifyError.tokenExpired {
            playlistsError = "Spotify session expired. Reconnect in the Spotify tab."
        } catch {
            playlistsError = "Could not load playlists. Try again."
        }
    }
}
