//
//  Enums.swift
//  Cue
//
//  Created by Kinsee Nyland on 2/5/26.
//

import Foundation

enum WorkoutType: String, CaseIterable, Codable {
    case matPilates, reformerPilates, yoga, cycle, strength, cardio

    var displayName: String {
        switch self {
        case .matPilates: return "Mat Pilates"
        case .reformerPilates: return "Reformer Pilates"
        case .yoga: return "Yoga"
        case .cycle: return "Cycle"
        case .strength: return "Strength"
        case .cardio: return "Cardio"
        }
    }

    init?(legacy rawValue: String) {
        if rawValue == "pilates" {
            self = .matPilates
        } else {
            self.init(rawValue: rawValue)
        }
    }
}

enum Difficulty: String, CaseIterable, Codable {
    case easy, medium, hard
}

enum GoalType: String, CaseIterable, Codable {
    case timed, reps
}

enum WorkoutSection: String, CaseIterable, Codable {
    case warmUp = "warmUp"
    case main = "main"
    case coolDown = "coolDown"
}
