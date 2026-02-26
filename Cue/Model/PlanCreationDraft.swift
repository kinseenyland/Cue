//
//  PlanCreationDraft.swift
//  Cue
//

import Foundation

/// A named sub-section of the main workout block (e.g. "Circuit 1", "Strength Block").
struct WorkoutSubSection: Identifiable, Hashable {
    var id: String
    var name: String
    var durationMinutes: Int
    var movements: [Movement]

    init(id: String = UUID().uuidString, name: String = "", durationMinutes: Int = 5, movements: [Movement] = []) {
        self.id = id
        self.name = name
        self.durationMinutes = durationMinutes
        self.movements = movements
    }
}

/// Accumulated data written to during the multi-step plan creation flow.
struct PlanCreationDraft {
    var name: String = ""
    var type: WorkoutType? = nil
    var difficulty: Difficulty? = nil
    var goalType: GoalType = .reps
    var durationMinutes: Int = 45
    var warmUpDurationMinutes: Int = 5
    var coolDownDurationMinutes: Int = 5
    var warmUpMovements: [Movement] = []
    var mainSections: [WorkoutSubSection] = [WorkoutSubSection()]
    var coolDownMovements: [Movement] = []
}
