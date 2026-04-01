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

enum WorkoutSection: String, CaseIterable, Codable, Identifiable {
    case warmUp = "warmUp"
    case main = "main"
    case coolDown = "coolDown"

    var id: String { rawValue }
}

enum WorkoutStructurePreference: String, CaseIterable, Codable {
    case freeform  = "freeform"
    case timeBased = "timeBased"
    case repBased  = "repBased"
    case flexible  = "flexible"

    var label: String {
        switch self {
        case .freeform:  return "Move list"
        case .timeBased: return "Time-based"
        case .repBased:  return "Rep-based"
        case .flexible:  return "It depends"
        }
    }

    var description: String {
        switch self {
        case .freeform:  return "I write out my movements without set timing or reps"
        case .timeBased: return "Each movement gets a set duration"
        case .repBased:  return "Each movement gets a set number of reps"
        case .flexible:  return "It varies depending on the class"
        }
    }
}

enum MusicApproach: String, CaseIterable, Codable {
    case musicFirst   = "musicFirst"
    case workoutFirst = "workoutFirst"
    case flexible     = "flexible"

    var label: String {
        switch self {
        case .musicFirst:   return "Music first"
        case .workoutFirst: return "Workout first"
        case .flexible:     return "It depends"
        }
    }

    var description: String {
        switch self {
        case .musicFirst:   return "I build my workout around the music"
        case .workoutFirst: return "I find music to match a workout I've already built"
        case .flexible:     return "It varies class to class"
        }
    }
}
