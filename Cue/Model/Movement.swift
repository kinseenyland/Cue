//
//  Movement.swift
//  Cue
//
//  Created by Kinsee Nyland on 2/5/26.
//

import Foundation

struct Movement: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var notes: String?
    var goalType: GoalType
    var seconds: Int?
    var reps: Int?
    var section: WorkoutSection
    var sectionName: String?
    var sectionDurationMinutes: Int?

    init(
        id: String = UUID().uuidString,
        name: String,
        notes: String? = nil,
        goalType: GoalType,
        seconds: Int? = nil,
        reps: Int? = nil,
        section: WorkoutSection = .main,
        sectionName: String? = nil,
        sectionDurationMinutes: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.goalType = goalType
        self.seconds = seconds
        self.reps = reps
        self.section = section
        self.sectionName = sectionName
        self.sectionDurationMinutes = sectionDurationMinutes
    }
}
