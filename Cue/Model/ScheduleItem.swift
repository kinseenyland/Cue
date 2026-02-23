//
//  ScheduleItem.swift
//  Cue
//
//  Created by Kinsee Nyland on 2/10/26.
//

import Foundation

struct ScheduleItem: Identifiable, Codable, Hashable {
    var id: String
    var ownerId: String
    var title: String
    var location: String
    var workoutType: WorkoutType?
    var difficulty: Difficulty?
    var startsAt: Double
    var durationMinutes: Int
    var planId: String?

    init(
        id: String = UUID().uuidString,
        ownerId: String,
        title: String,
        location: String = "",
        workoutType: WorkoutType? = nil,
        difficulty: Difficulty? = nil,
        startsAt: Double,
        durationMinutes: Int,
        planId: String? = nil
    ) {
        self.id = id
        self.ownerId = ownerId
        self.title = title
        self.location = location
        self.workoutType = workoutType
        self.difficulty = difficulty
        self.startsAt = startsAt
        self.durationMinutes = durationMinutes
        self.planId = planId
    }

    var startDate: Date {
        Date(timeIntervalSince1970: startsAt)
    }
}
