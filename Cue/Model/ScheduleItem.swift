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
    var startsAt: Double
    var durationMinutes: Int
    var planId: String?

    init(
        id: String = UUID().uuidString,
        ownerId: String,
        title: String,
        startsAt: Double,
        durationMinutes: Int,
        planId: String? = nil
    ) {
        self.id = id
        self.ownerId = ownerId
        self.title = title
        self.startsAt = startsAt
        self.durationMinutes = durationMinutes
        self.planId = planId
    }
}
