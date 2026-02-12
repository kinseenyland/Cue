//
//  WorkoutPlanFormView.swift
//  Cue
//
//  Created by Kinsee Nyland on 2/10/26.
//

import SwiftUI

struct WorkoutPlanFormView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var type: WorkoutType
    @State private var difficulty: Difficulty
    @State private var durationMinutes: Int
    @State private var movements: [Movement]
    @State private var newMovement = ""
    @State private var newGoalType: GoalType = .timed
    @State private var newSeconds = 30
    @State private var newReps = 10

    let onSave: (WorkoutPlanDraft) -> Void

    init(draft: WorkoutPlanDraft? = nil, onSave: @escaping (WorkoutPlanDraft) -> Void) {
        let initial = draft ?? WorkoutPlanDraft(
            title: "",
            type: .pilates,
            difficulty: .medium,
            durationMinutes: 45,
            movements: []
        )
        _title = State(initialValue: initial.title)
        _type = State(initialValue: initial.type)
        _difficulty = State(initialValue: initial.difficulty)
        _durationMinutes = State(initialValue: initial.durationMinutes)
        _movements = State(initialValue: initial.movements)
        self.onSave = onSave
    }

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

                Picker("Goal", selection: $newGoalType) {
                    Text("Timed").tag(GoalType.timed)
                    Text("Reps").tag(GoalType.reps)
                }

                if newGoalType == .timed {
                    Stepper("Seconds: \(newSeconds)", value: $newSeconds, in: 10...600, step: 5)
                } else {
                    Stepper("Reps: \(newReps)", value: $newReps, in: 1...200, step: 1)
                }

                if movements.isEmpty {
                    Text("No movements yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(movements) { movement in
                        HStack {
                            Text(movement.name)
                            Spacer()
                            Text(goalText(for: movement))
                                .foregroundStyle(.secondary)
                        }
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
        let movement = Movement(
            name: trimmed,
            goalType: newGoalType,
            seconds: newGoalType == .timed ? newSeconds : nil,
            reps: newGoalType == .reps ? newReps : nil
        )
        movements.append(movement)
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

    private func goalText(for movement: Movement) -> String {
        switch movement.goalType {
        case .timed:
            return "\(movement.seconds ?? 0)s"
        case .reps:
            return "\(movement.reps ?? 0) reps"
        }
    }
}

#Preview {
    NavigationStack {
        WorkoutPlanFormView { _ in }
    }
}
