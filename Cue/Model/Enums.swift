//
//  Enums.swift
//  Cue
//
//  Created by Kinsee Nyland on 2/5/26.
//

import Foundation

enum WorkoutType: String, CaseIterable, Codable {
    case pilates, yoga, cycle, strength, cardio
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
