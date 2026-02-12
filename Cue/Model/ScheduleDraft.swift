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
    var startsAt: Date
    var durationMinutes: Int
    var planId: String?
}
