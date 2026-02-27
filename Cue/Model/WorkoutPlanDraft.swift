//
//  WorkoutPlanDraft.swift
//  Cue
//
//  Created by Kinsee Nyland on 2/10/26.
//

import Foundation

struct WorkoutPlanDraft: Identifiable, Hashable {
    let id = UUID()
    var title: String
    var type: WorkoutType
    var difficulty: Difficulty
    var durationMinutes: Int
    var movements: [Movement]
    var warmUpPlaylistId: String?
    var mainPlaylistId: String?
    var coolDownPlaylistId: String?

    var summaryLine: String {
        "Type: \(type.rawValue.capitalized) • Difficulty: \(difficulty.rawValue.capitalized) • Time: \(durationMinutes) mins"
    }
}
