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

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }

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
                VStack(spacing: 0) {
                    HStack {
                        Text("Home")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.black)
                        Spacer()
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                    Text("Welcome, \(displayName)!")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 12)

                    // Upcoming Classes
                    sectionHeader("Upcoming Classes")
                        .padding(.top, 8)

                    VStack(spacing: 8) {
                        if upcomingItems.isEmpty {
                            Button {
                                selectedTab = .schedule
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "calendar.badge.plus")
                                        .font(.system(size: 20))
                                        .foregroundStyle(.black)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("You're free!")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(.black)
                                        Text("Add a class to your schedule.")
                                            .font(.system(size: 12, weight: .thin))
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
                            .buttonStyle(.plain)
                        } else {
                            ForEach(upcomingItems) { item in
                                Button {
                                    navigationPath.append(item)
                                } label: {
                                    HomeScheduleCard(item: item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.top, 8)

                    // Favorite Plans
                    sectionHeader("Favorite Plans")
                        .padding(.top, 28)

                    VStack(spacing: 8) {
                        ForEach(favoritePlans) { plan in
                            Button {
                                navigationPath.append(plan)
                            } label: {
                                HomePlanCard(plan: plan)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 8)

                    Color.clear
                        .frame(height: 45)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 34)
            }
            .background(Color.white)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: ScheduleItem.self) { item in
                ScheduleDetailView(
                    item: item,
                    plans: plansVM.plans,
                    onUpdate: { draft in
                        Task { await scheduleVM.updateSchedule(id: item.id, from: draft) }
                    },
                    onDelete: {
                        Task {
                            await scheduleVM.deleteSchedule(id: item.id)
                            navigationPath.removeLast()
                        }
                    },
                    onGoToPlan: { plan in
                        navigationPath.append(plan)
                    }
                )
            }
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
                    onDuplicate: { name in
                        Task { await plansVM.duplicatePlan(plan, newName: name) }
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

    private static let dayNameFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()

    private static let dateLabelFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        f.amSymbol = "AM"
        f.pmSymbol = "PM"
        return f
    }()

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 2) {
                Text(Self.dayNameFormatter.string(from: item.startDate).uppercased())
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.black)
                Text(Self.dateLabelFormatter.string(from: item.startDate))
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 48)
            .multilineTextAlignment(.center)

            Rectangle()
                .fill(Color.black)
                .frame(width: 1, height: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                    Text(Self.timeFormatter.string(from: item.startDate))
                        .font(.system(size: 12, weight: .regular))
                    if !item.location.isEmpty {
                        Text("·")
                        Image(systemName: "mappin")
                            .font(.system(size: 11))
                        Text(item.location)
                            .font(.system(size: 12, weight: .regular))
                            .lineLimit(1)
                    }
                }
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

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
