//
//  MainTabView.swift
//  Cue
//
//  Created by Kinsee Nyland on 2/10/26.
//

import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            PlansView()
                .tabItem {
                    Label("Plans", systemImage: "doc.text")
                }

            PlayerView()
                .tabItem {
                    Label("Workout", systemImage: "figure.core.training")
                }

            ScheduleView()
                .tabItem {
                    Label("Schedule", systemImage: "calendar")
                }
        }
    }
}

#Preview {
    MainTabView()
}
