//
//  CueApp.swift
//  Cue
//
//  Created by Kinsee Nyland on 1/29/26.
//

import SwiftUI
import FirebaseCore

@main
struct CueApp: App {
    @StateObject private var authVM = AuthViewModel()

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authVM)
        }
    }
}
