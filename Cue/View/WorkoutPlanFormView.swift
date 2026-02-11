//
//  WorkoutPlanFormView.swift
//  Cue
//
//  Created by Kinsee Nyland on 2/10/26.
//

import SwiftUI

struct WorkoutPlanFormView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var type: WorkoutType = .pilates
    @State private var difficulty: Difficulty = .medium
    @State private var durationMinutes = 45
    @State private var movements: [String] = []
    @State private var newMovement = ""

    let onSave: (WorkoutPlanDraft) -> Void

    var body: some View {
        Form {
            Section("Plan Details") {
                TextField("Plan title", text: $title)

                Picker("Type", selection: $type) {
                    ForEach(WorkoutType.allCases, id: \.self) { planType in
                        Text(planType.rawValue.capitalized).tag(planType)
                    }
                }

                Picker("Difficulty", selection: $difficulty) {
                    ForEach(Difficulty.allCases, id: \.self) { level in
                        Text(level.rawValue.capitalized).tag(level)
                    }
                }

                Stepper("Duration: \(durationMinutes) mins", value: $durationMinutes, in: 10...120, step: 5)
            }

            Section("Movements") {
                HStack {
                    TextField("Add movement", text: $newMovement)
                    Button("Add") {
                        addMovement()
                    }
                    .disabled(newMovement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if movements.isEmpty {
                    Text("No movements yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(movements, id: \.self) { movement in
                        Text(movement)
                    }
                    .onDelete(perform: deleteMovement)
                }
            }
        }
        .navigationTitle("New Workout Plan")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { savePlan() }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func addMovement() {
        let trimmed = newMovement.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        movements.append(trimmed)
        newMovement = ""
    }

    private func deleteMovement(at offsets: IndexSet) {
        movements.remove(atOffsets: offsets)
    }

    private func savePlan() {
        let plan = WorkoutPlanDraft(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            type: type,
            difficulty: difficulty,
            durationMinutes: durationMinutes,
            movements: movements
        )
        onSave(plan)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        WorkoutPlanFormView { _ in }
    }
}
