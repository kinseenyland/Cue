//
//  SavedSection.swift
//  Cue
//

import Foundation

struct SavedSection: Identifiable, Codable, Hashable {
    var id: String
    var ownerId: String
    var name: String
    var sectionType: WorkoutSection
    var durationMinutes: Int
    var movements: [Movement]
    var createdAt: Double

    init(
        id: String = UUID().uuidString,
        ownerId: String,
        name: String,
        sectionType: WorkoutSection,
        durationMinutes: Int,
        movements: [Movement],
        createdAt: Double = Date().timeIntervalSince1970
    ) {
        self.id = id
        self.ownerId = ownerId
        self.name = name
        self.sectionType = sectionType
        self.durationMinutes = durationMinutes
        self.movements = movements
        self.createdAt = createdAt
    }
}
