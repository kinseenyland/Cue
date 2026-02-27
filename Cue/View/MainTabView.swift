//
//  MainTabView.swift
//  Cue
//
//  Created by Kinsee Nyland on 2/10/26.
//

import SwiftUI

enum MainTab: Hashable {
    case home
    case schedule
    case plans
    case profile
    case spotify
    case workout  // used internally by PlansView/PlanDetailView to start a workout
}

struct MainTabView: View {
    @EnvironmentObject private var spotifyManager: SpotifyManager
    @State private var selection: MainTab = .home
    @StateObject private var sessionVM = WorkoutSessionViewModel()

    var body: some View {
        ZStack {
            switch selection {
            case .home:
                HomeView(selectedTab: $selection)
            case .schedule:
                ScheduleView()
            case .plans:
                PlansView(selectedTab: $selection)
            case .profile:
                ProfileView()
                    .environmentObject(spotifyManager)
            case .spotify:
                SpotifySearchView(onTrackSelected: { _ in })
                    .environmentObject(spotifyManager)
            case .workout:
                PlayerView(selectedTab: $selection)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom) {
            HStack(alignment: .center, spacing: 0) {
                ForEach(MainTab.visibleTabs, id: \.self) { tab in
                    Button {
                        selection = tab
                    } label: {
                        Text(tab.label)
                            .font(.system(size: 15, weight: selection == tab ? .bold : .regular))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.white)
        }
        .environmentObject(sessionVM)
    }
}

extension MainTab {
    static let visibleTabs: [MainTab] = [.home, .schedule, .plans, .profile, .spotify]

    var label: String {
        switch self {
        case .home:     return "Home"
        case .schedule: return "Schedule"
        case .plans:    return "Plans"
        case .profile:  return "Profile"
        case .spotify:  return "Spotify"
        case .workout:  return "Workout"
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(SpotifyManager.shared)
}
