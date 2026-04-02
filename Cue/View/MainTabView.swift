//
//  MainTabView.swift
//  Cue
//
//  Created by Kinsee Nyland on 2/10/26.
//

import Combine
import SwiftUI

/// Drives chrome (e.g. bottom tab bar) from child screens such as Spotify search.
final class MainTabChrome: ObservableObject {
    @Published var hideBottomBar: Bool = false
}

enum MainTab: Hashable {
    case home
    case schedule
    case plans
    case profile
    case workout  // used internally by PlansView/PlanDetailView to start a workout
}

struct MainTabView: View {
    @EnvironmentObject private var spotifyManager: SpotifyManager
    @State private var selection: MainTab = .home
    @State private var scheduleViewId = UUID()
    @StateObject private var sessionVM = WorkoutSessionViewModel()
    @StateObject private var mainTabChrome = MainTabChrome()

    var body: some View {
        ZStack {
            switch selection {
            case .home:
                HomeView(selectedTab: $selection)
            case .schedule:
                ScheduleView(selectedTab: $selection)
                    .id(scheduleViewId)
            case .plans:
                PlansView(selectedTab: $selection)
            case .profile:
                ProfileView()
                    .environmentObject(spotifyManager)
            case .workout:
                PlayerView(selectedTab: $selection)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .tint(.black)
        .environmentObject(mainTabChrome)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !mainTabChrome.hideBottomBar {
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
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.22), value: mainTabChrome.hideBottomBar)
        .onChange(of: selection) { newSelection in
            if newSelection == .schedule {
                scheduleViewId = UUID()
            }
        }
        .environmentObject(sessionVM)
    }
}

extension MainTab {
    static let visibleTabs: [MainTab] = [.home, .schedule, .plans, .profile]

    var label: String {
        switch self {
        case .home:     return "Home"
        case .schedule: return "Schedule"
        case .plans:    return "Plans"
        case .profile:  return "Profile"
        case .workout:  return "Workout"
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(SpotifyManager.shared)
}
