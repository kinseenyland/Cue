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
}

struct MainTabView: View {
    @State private var selection: MainTab = .plans

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
        }
    }
}

#Preview {
    MainTabView()
}
