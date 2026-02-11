//
//  WorkoutPlanFormView.swift
//  Cue
//
//  Created by Kinsee Nyland on 2/10/26.
//

import SwiftUI

struct DraftPlan: Identifiable {
    let id = UUID()
    var title: String
    var type: PlanType
    var difficulty: PlanDifficulty
    var durationMinutes: Int
    var movements: [String]

    var summaryLine: String {
        "Type: \(type.rawValue) • Difficulty: \(difficulty.rawValue) • Time: \(durationMinutes) mins"
    }
}

enum PlanType: String, CaseIterable, Identifiable {
    case pilates = "Pilates"
    case yoga = "Yoga"
    case strength = "Strength"
    case cardio = "Cardio"

    var id: String { rawValue }
}

enum PlanDifficulty: String, CaseIterable, Identifiable {
    case beginner = "Beginner"
    case medium = "Medium"
    case advanced = "Advanced"

    var id: String { rawValue }
}

struct WorkoutPlanFormView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var type: PlanType = .pilates
    @State private var difficulty: PlanDifficulty = .medium
    @State private var durationMinutes = 45
    @State private var movements: [String] = []
    @State private var newMovement = ""

    let onSave: (DraftPlan) -> Void

    var body: some View {
        Form {
            Section("Plan Details") {
                TextField("Plan title", text: $title)

                Picker("Type", selection: $type) {
                    ForEach(PlanType.allCases) { planType in
                        Text(planType.rawValue).tag(planType)
                    }
                }

                Picker("Difficulty", selection: $difficulty) {
                    ForEach(PlanDifficulty.allCases) { level in
                        Text(level.rawValue).tag(level)
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
        let plan = DraftPlan(
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
