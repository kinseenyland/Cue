//
//  ScheduleDraft.swift
//  Cue
//
//  Created by Kinsee Nyland on 2/10/26.
//

import Foundation

struct ScheduleDraft: Identifiable, Hashable {
    let id = UUID()
    var title: String
    var location: String
    var workoutType: WorkoutType?
    var difficulty: Difficulty?
    var startsAt: Date
    var durationMinutes: Int
    var planId: String?
}
