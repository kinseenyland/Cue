//
//  MainTabView.swift
//  Cue
//
//  Created by Kinsee Nyland on 2/10/26.
//

import SwiftUI

enum MainTab: Hashable {
    case plans
    case workout
    case schedule
    case spotify
}

struct MainTabView: View {
    @EnvironmentObject private var spotifyManager: SpotifyManager
    @State private var selection: MainTab = .plans
    @StateObject private var sessionVM = WorkoutSessionViewModel()

    private var isInActiveWorkout: Bool {
        selection == .workout && !sessionVM.movements.isEmpty
    }

    var body: some View {
        TabView(selection: $selection) {
            PlansView(selectedTab: $selection)
                .tabItem {
                    Label("Plans", systemImage: "doc.text")
                }
                .tag(MainTab.plans)

            PlayerView()
                .tabItem {
                    Label("Workout", systemImage: "figure.core.training")
                }
                .tag(MainTab.workout)

            ScheduleView()
                .tabItem {
                    Label("Schedule", systemImage: "calendar")
                }
                .tag(MainTab.schedule)

            NavigationStack {
                SpotifySearchView(onTrackSelected: { _ in })
                    .environmentObject(spotifyManager)
            }
            .tabItem {
                Label("Spotify", systemImage: "music.note")
            }
            .tag(MainTab.spotify)
        }
        .environmentObject(sessionVM)
        .toolbar {
            if isInActiveWorkout {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        sessionVM.reset()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(isInActiveWorkout)
    }
}

#Preview {
    MainTabView()
        .environmentObject(SpotifyManager.shared)
}
