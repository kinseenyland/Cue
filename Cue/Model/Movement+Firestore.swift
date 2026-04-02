//
//  Movement+Firestore.swift
//  Cue
//

import Foundation

extension Movement {
    /// Decodes a movement from Firestore / plan document fields (matches `CueViewModel.movementToDict`).
    init?(firestoreDictionary data: [String: Any]) {
        guard
            let name = data["name"] as? String,
            let goalTypeRaw = data["goalType"] as? String,
            let goalType = GoalType(rawValue: goalTypeRaw)
        else { return nil }

        let section = WorkoutSection(rawValue: data["section"] as? String ?? "") ?? .main

        self.init(
            id: data["id"] as? String ?? UUID().uuidString,
            name: name,
            notes: data["notes"] as? String,
            goalType: goalType,
            seconds: data["seconds"] as? Int,
            reps: data["reps"] as? Int,
            section: section,
            sectionName: data["sectionName"] as? String,
            sectionDurationMinutes: data["sectionDurationMinutes"] as? Int
        )
    }
}
