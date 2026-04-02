//
//  PlansView.swift
//  Cue
//
//  Created by Kinsee Nyland on 2/10/26.
//

import FirebaseAuth
import SwiftUI

struct PlansView: View {
    @Binding var selectedTab: MainTab
    @State private var navigationPath = NavigationPath()
    @State private var isPresentingCreateChoice = false
    @State private var presentedCreationMode: PlanCreationMode? = nil
    @State private var editingPlan: WorkoutPlan? = nil
    @State private var isShowingAlert = false
    @State private var alertMessage = ""
    @State private var selectedType: WorkoutType? = nil
    @State private var searchText: String = ""
    @StateObject private var vm = CueViewModel()
    @StateObject private var profileVM = ProfileViewModel()
    @EnvironmentObject private var sessionVM: WorkoutSessionViewModel
    @EnvironmentObject private var authVM: AuthViewModel

    /// Class types to show in filter chips and plan creation. Falls back to all types if profile not loaded.
    private var availableTypes: [WorkoutType] {
        profileVM.preferredClassTypes.isEmpty ? WorkoutType.allCases : profileVM.preferredClassTypes
    }

    var filteredPlans: [WorkoutPlan] {
        var result = vm.plans
        if let type = selectedType {
            result = result.filter { $0.type == type }
        }
        if !searchText.isEmpty {
            result = result.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
        return result
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Plans")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.black)
                    Spacer()
                    Button {
                        if vm.plans.isEmpty {
                            presentedCreationMode = .guided
                        } else {
                            isPresentingCreateChoice = true
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 20))
                            .foregroundStyle(.black)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 8)

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                    TextField("Search plans", text: $searchText)
                        .font(.system(size: 15))
                        .autocorrectionDisabled()
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 16)
                .padding(.bottom, 4)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        PlanFilterChip(label: "All", isSelected: selectedType == nil) {
                            selectedType = nil
                        }
                        ForEach(availableTypes, id: \.self) { type in
                            PlanFilterChip(
                                label: type.displayName,
                                isSelected: selectedType == type
                            ) {
                                selectedType = type
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 8)

                if filteredPlans.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        if vm.plans.isEmpty {
                            Image(systemName: "doc.text")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                            Text("No plans yet")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.black)
                            Text("Tap + to create your first plan")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        } else {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                            Text("No matching plans")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.black)
                            Text("Try a different search or filter")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    Spacer()
                } else {
                List {
                    ForEach(filteredPlans) { plan in
                        PlanRowCard(plan: plan) {
                            navigationPath.append(plan)
                        } onToggleFavorite: {
                            Task { await vm.toggleFavorite(id: plan.id, isFavorited: !plan.isFavorited) }
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task { await vm.deletePlan(id: plan.id) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    editingPlan = plan
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.black)
                            }
                            .contextMenu {
                                Button("Start Workout") {
                                    sessionVM.load(plan: plan)
                                    selectedTab = .workout
                                }
                                Button("Edit") {
                                    editingPlan = plan
                                }
                                Button(role: .destructive) {
                                    Task { await vm.deletePlan(id: plan.id) }
                                } label: {
                                    Text("Delete")
                                }
                            }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: WorkoutPlan.self) { plan in
                PlanDetailView(
                    plan: plan,
                    selectedTab: $selectedTab,
                    onUpdate: { draft in Task { await vm.updatePlan(id: plan.id, from: draft) } },
                    onDelete: {
                        Task {
                            await vm.deletePlan(id: plan.id)
                            navigationPath.removeLast()
                        }
                    },
                    onDuplicate: { name in
                        Task { await vm.duplicatePlan(plan, newName: name) }
                    },
                    availableTypes: availableTypes
                )
            }
        }
        .task {
            await vm.fetchPlans()
            if let uid = authVM.user?.uid { profileVM.load(uid: uid) }
        }
        .sheet(isPresented: $isPresentingCreateChoice) {
            PlanCreationChoiceView { mode in
                presentedCreationMode = mode
            }
        }
        .sheet(item: $presentedCreationMode) { mode in
            switch mode {
            case .guided:
                PlanCreationView(
                    availableTypes: availableTypes,
                    workoutStructure: profileVM.workoutStructure,
                    musicApproach: profileVM.musicApproach
                ) { newPlan in
                    Task { await vm.createPlan(from: newPlan) }
                }
            case .quick:
                PlanFormView(
                    availableTypes: availableTypes,
                    mode: .create(
                        workoutStructure: profileVM.workoutStructure,
                        onSave: { newPlan in Task { await vm.createPlan(from: newPlan) } }
                    )
                )
            }
        }
        .sheet(item: $editingPlan) { plan in
            PlanFormView(
                availableTypes: availableTypes,
                mode: .edit(
                    plan: plan,
                    onSave: { updated in Task { await vm.updatePlan(id: plan.id, from: updated) } }
                )
            )
        }
        .overlay {
            if isShowingAlert {
                CustomAlertView(
                    title: "Cue",
                    message: alertMessage,
                    primaryLabel: "OK",
                    primaryAction: { isShowingAlert = false },
                    primaryStyle: .gray,
                    onDismiss: { isShowingAlert = false }
                )
            }
        }
    }

}

struct PlanFilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isSelected ? .white : Color(red: 0.286, green: 0.271, blue: 0.310))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.black : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(red: 0.792, green: 0.769, blue: 0.816), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

struct PlanRowCard: View {
    let plan: WorkoutPlan
    let onTap: () -> Void
    let onToggleFavorite: () -> Void

    private var difficultyLabel: String {
        switch plan.difficulty {
        case .easy: return "Low"
        case .medium: return "Medium"
        case .hard: return "High"
        }
    }

    private var lastRunLabel: String? {
        guard let lastRunAt = plan.lastRunAt else { return nil }
        let date = Date(timeIntervalSince1970: lastRunAt)
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "Last run: \(formatter.string(from: date))"
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(plan.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)

                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(.system(size: 12))
                    Text("\(plan.durationMinutes) min")
                        .font(.system(size: 12, weight: .thin))

                    Image(systemName: "flame")
                        .font(.system(size: 12))
                    Text(difficultyLabel)
                        .font(.system(size: 12, weight: .thin))
                }
                .foregroundStyle(.black)

                if let lastRun = lastRunLabel {
                    Text(lastRun)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                onToggleFavorite()
            } label: {
                Image(systemName: plan.isFavorited ? "star.fill" : "star")
                    .font(.system(size: 16))
                    .foregroundStyle(plan.isFavorited ? Color.yellow : Color.black)
            }
            .buttonStyle(.plain)

            Image(systemName: "chevron.right")
                .font(.system(size: 14))
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
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}

#Preview {
    PlansView(selectedTab: .constant(.plans))
        .environmentObject(WorkoutSessionViewModel())
}
