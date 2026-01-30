//
//  CueApp.swift
//  Cue
//
//  Created by Kinsee Nyland on 1/29/26.
//

import SwiftUI
import FirebaseCore
import FirebaseAuth

@main
struct CueApp: App {

    init() {
        FirebaseApp.configure()
        ensureSignedIn()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    private func ensureSignedIn() {
        if Auth.auth().currentUser == nil {
            Auth.auth().signInAnonymously { result, error in
                if let error {
                    print("❌ Anonymous sign-in failed:", error.localizedDescription)
                } else {
                    print("✅ Signed in anonymously as:", result?.user.uid ?? "nil")
                }
            }
        } else {
            print("✅ Already signed in as:", Auth.auth().currentUser?.uid ?? "nil")
        }
    }
}
