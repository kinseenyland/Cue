//
//  UserProfile.swift
//  Cue
//
//  Created by Kinsee Nyland on 2/5/26.
//

import Foundation

struct UserProfile: Codable, Hashable, Identifiable {
    var id: String            // we will set this manually (documentID)
    var displayName: String
    var classesTaught: Int
    var topClassTypeRaw: String

    init(
        id: String = UUID().uuidString,
        displayName: String,
        classesTaught: Int = 0,
        topClassTypeRaw: String = "pilates"
    ) {
        self.id = id
        self.displayName = displayName
        self.classesTaught = classesTaught
        self.topClassTypeRaw = topClassTypeRaw
    }
}
