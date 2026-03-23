//
//  HomeView.swift
//  Cue
//

import FirebaseAuth
import SwiftUI

struct HomeView: View {
    @Binding var selectedTab: MainTab
    @EnvironmentObject private var authVM: AuthViewModel
    @StateObject private var scheduleVM = ScheduleViewModel()
    @StateObject private var plansVM = CueViewModel()
    @StateObject private var profileVM = ProfileViewModel()
    @State private var navigationPath = NavigationPath()

    private var availableTypes: [WorkoutType] {
        profileVM.preferredClassTypes.isEmpty ? WorkoutType.allCases : profileVM.preferredClassTypes
    }

    private var displayName: String {
        authVM.user?.displayName?.isEmpty == false
            ? (authVM.user?.displayName ?? "there")
            : "there"
    }

    private var upcomingItems: [ScheduleItem] {
        Array(scheduleVM.items.filter { $0.startDate >= Date() }.prefix(2))
    }

    private var favoritePlans: [WorkoutPlan] {
        plansVM.plans.filter { $0.isFavorited }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: 8) {
                    // Page header
                    HStack {
                        Text("Home")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.black)
                        Spacer()
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 8)

                    // Welcome message
                    Text("Welcome \(displayName)!")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)

                    // Upcoming Classes section
                    Text("Upcoming Classes")
                        .font(.system(size: 13, weight: .light))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)

                    ForEach(upcomingItems) { item in
                        Button {
                            if let planId = item.planId,
                               let plan = plansVM.plans.first(where: { $0.id == planId }) {
                                navigationPath.append(plan)
                            }
                        } label: {
                            HomeScheduleCard(item: item)
                        }
                        .buttonStyle(.plain)
                        .disabled(item.planId == nil)
                    }

                    // Favorite Plans section
                    Text("Favorite Plans")
                        .font(.system(size: 13, weight: .light))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 16)

                    ForEach(favoritePlans) { plan in
                        Button {
                            navigationPath.append(plan)
                        } label: {
                            HomePlanCard(plan: plan)
                        }
                        .buttonStyle(.plain)
                    }

                    // Bottom spacer for nav bar
                    Color.clear
                        .frame(height: 45)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 34)
            }
            .background(Color.white)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: WorkoutPlan.self) { plan in
                PlanDetailView(
                    plan: plan,
                    selectedTab: $selectedTab,
                    onUpdate: { draft in Task { await plansVM.updatePlan(id: plan.id, from: draft) } },
                    onDelete: {
                        Task {
                            await plansVM.deletePlan(id: plan.id)
                            navigationPath.removeLast()
                        }
                    },
                    availableTypes: availableTypes
                )
            }
        }
        .task {
            await scheduleVM.fetchSchedules()
            await plansVM.fetchPlans()
            if let uid = authVM.user?.uid { profileVM.load(uid: uid) }
        }
    }
}

// MARK: - Home Schedule Card (Figma design)

private struct HomeScheduleCard: View {
    let item: ScheduleItem

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f
    }()

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "ha"
        f.amSymbol = "am"
        f.pmSymbol = "pm"
        return f
    }()

    var body: some View {
        HStack(spacing: 14) {
            // Date
            VStack(spacing: 5) {
                Text(Self.monthFormatter.string(from: item.startDate).uppercased())
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.black)
                Text(Self.dayFormatter.string(from: item.startDate))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.black)
            }
            .frame(width: 41)
            .multilineTextAlignment(.center)

            // Vertical line
            Rectangle()
                .fill(Color.black)
                .frame(width: 1)
                .frame(height: 40)

            // Class info
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)
                if !item.location.isEmpty {
                    Text(item.location)
                        .font(.system(size: 10, weight: .thin))
                        .foregroundStyle(.black)
                }
                Text(Self.timeFormatter.string(from: item.startDate))
                    .font(.system(size: 10, weight: .thin))
                    .foregroundStyle(.black)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.black)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(height: 70)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.black, lineWidth: 1)
        )
    }
}

// MARK: - Home Plan Card (Figma design)

private struct HomePlanCard: View {
    let plan: WorkoutPlan

    private var difficultyLabel: String {
        switch plan.difficulty {
        case .easy: return "Low"
        case .medium: return "Medium"
        case .hard: return "High"
        }
    }

    var body: some View {
        HStack(spacing: 22) {
            VStack(alignment: .leading, spacing: 4) {
                Text(plan.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)

                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(.system(size: 15))
                    Text("\(plan.durationMinutes) min")
                        .font(.system(size: 12, weight: .thin))

                    Image(systemName: "flame")
                        .font(.system(size: 15))
                    Text(difficultyLabel)
                        .font(.system(size: 12, weight: .thin))
                }
                .foregroundStyle(.black)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.black)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(height: 76)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.black, lineWidth: 1)
        )
    }
}

#Preview {
    HomeView(selectedTab: .constant(.home))
        .environmentObject(AuthViewModel())
}
