//
//  PlansView.swift
//  Cue
//
//  Created by Kinsee Nyland on 2/10/26.
//

import SwiftUI

struct PlansView: View {
    @Binding var selectedTab: MainTab
    @State private var isPresentingCreateForm = false
    @State private var editingPlan: WorkoutPlan? = nil
    @State private var isShowingAlert = false
    @State private var alertMessage = ""
    @StateObject private var vm = CueViewModel()
    @EnvironmentObject private var sessionVM: WorkoutSessionViewModel

    var body: some View {
        NavigationStack {
            List {
                if let status = vm.statusMessage {
                    Text(status)
                        .foregroundStyle(.green)
                }

                if let error = vm.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                }

                ForEach(vm.plans) { plan in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(plan.title)
                            .font(.headline)
                        Text("Type: \(plan.type.rawValue.capitalized) • Difficulty: \(plan.difficulty.rawValue.capitalized) • Time: \(plan.durationMinutes) mins")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if !plan.movements.isEmpty {
                            Text(plan.movements.map { $0.name }.joined(separator: ", "))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
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
                        .tint(.blue)
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
            .navigationTitle("Create + Share Plans")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        isPresentingCreateForm = true
                    } label: {
                        Image(systemName: "plus")
                    }

                    Button {
                        alertMessage = "Share plan coming soon."
                        isShowingAlert = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .task {
            await vm.fetchPlans()
        }
        .sheet(isPresented: $isPresentingCreateForm) {
            NavigationStack {
                WorkoutPlanFormView { newPlan in
                    Task { await vm.createPlan(from: newPlan) }
                }
            }
        }
        .sheet(item: $editingPlan) { plan in
            NavigationStack {
                WorkoutPlanFormView(draft: draft(from: plan)) { updated in
                    Task { await vm.updatePlan(id: plan.id, from: updated) }
                }
            }
        }
        .alert("Cue", isPresented: $isShowingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    private func draft(from plan: WorkoutPlan) -> WorkoutPlanDraft {
        WorkoutPlanDraft(
            title: plan.title,
            type: plan.type,
            difficulty: plan.difficulty,
            durationMinutes: plan.durationMinutes,
            movements: plan.movements
        )
    }
}

#Preview {
    PlansView(selectedTab: .constant(.plans))
}
