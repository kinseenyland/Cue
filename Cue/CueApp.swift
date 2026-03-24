//
//  CueApp.swift
//  Cue
//
//  Created by Kinsee Nyland on 1/29/26.
//

import SwiftUI
import FirebaseCore
import SpotifyiOS

@main
struct CueApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authVM = AuthViewModel()
    @StateObject private var spotifyManager = SpotifyManager.shared
    @Environment(\.scenePhase) var scenePhase
    
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(.black)
                .environmentObject(authVM)
                .environmentObject(spotifyManager)
                .onOpenURL { url in
                    spotifyManager.handleURL(url)
                }
        }
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .active:
                break
                // App Remote connects only when user taps Play (avoids connection spam when Spotify app isn't running)
            case .inactive:
                spotifyManager.disconnect()
            default:
                break
            }
        }
    }
}
