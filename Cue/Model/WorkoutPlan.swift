//
//  Item.swift
//  Cue
//
//  Created by Kinsee Nyland on 1/29/26.
//

import Foundation

struct WorkoutPlan: Identifiable, Codable, Hashable {
    var id: String               // Firestore document ID (we manage it)
    var ownerId: String          // Auth UID
    var title: String
    var type: WorkoutType
    var difficulty: Difficulty
    var durationMinutes: Int
    var createdAt: Double        // store as TimeInterval since 1970
    var updatedAt: Double
    var isPublic: Bool
    var isFavorited: Bool
    var movements: [Movement]

    init(
        id: String = UUID().uuidString,
        ownerId: String,
        title: String,
        type: WorkoutType,
        difficulty: Difficulty,
        durationMinutes: Int = 45,
        createdAt: Double = Date().timeIntervalSince1970,
        updatedAt: Double = Date().timeIntervalSince1970,
        isPublic: Bool = false,
        isFavorited: Bool = false,
        movements: [Movement] = []
    ) {
        self.id = id
        self.ownerId = ownerId
        self.title = title
        self.type = type
        self.difficulty = difficulty
        self.durationMinutes = durationMinutes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isPublic = isPublic
        self.isFavorited = isFavorited
        self.movements = movements
    }
}
