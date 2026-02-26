//
//  PlanMainMovementsStepView.swift
//  Cue
//

import SwiftUI

struct PlanMainMovementsStepView: View {
    @EnvironmentObject var vm: PlanCreationViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                Text("Add movements to\neach section.")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 24)

                ForEach($vm.draft.mainSections) { $section in
                    SectionMovementBlock(section: $section, defaultGoalType: vm.draft.goalType)
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SectionMovementBlock: View {
    @Binding var section: WorkoutSubSection
    let defaultGoalType: GoalType

    @State private var showAddForm = false
    @State private var newName = ""
    @State private var newGoalType: GoalType = .reps
    @State private var newReps = ""
    @State private var newSeconds = ""
    @FocusState private var nameFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header: name label + editable duration badge
            HStack(alignment: .center) {
                Text(section.name.isEmpty ? "Unnamed Section" : section.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .kerning(1.0)
                    .textCase(.uppercase)
                Spacer()
                EditableDurationBadge(minutes: $section.durationMinutes)
            }
            .padding(.horizontal, 24)

            if !section.movements.isEmpty {
                VStack(spacing: 0) {
                    ForEach(section.movements) { movement in
                        MovementRow(movement: movement) {
                            section.movements.removeAll { $0.id == movement.id }
                        }
                        if movement.id != section.movements.last?.id {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                }
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 24)
            }

            if showAddForm {
                sectionAddForm
                    .padding(.horizontal, 24)
            } else {
                Button {
                    newGoalType = defaultGoalType
                    showAddForm = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Add Movement")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .overlay(Capsule().stroke(Color.black, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
            }

            Divider()
                .padding(.top, 8)
        }
        .onChange(of: showAddForm) { _, isShowing in
            if isShowing { nameFieldFocused = true }
        }
    }

    private var sectionAddForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Movement name", text: $newName)
                .font(.system(size: 16))
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .overlay(Rectangle().stroke(Color.black, lineWidth: 1))
                .focused($nameFieldFocused)

            HStack(alignment: .center, spacing: 10) {
                TextField("0", text: newGoalType == .reps ? $newReps : $newSeconds)
                    .keyboardType(.numberPad)
                    .font(.system(size: 20, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .frame(width: 64)
                    .padding(.vertical, 10)
                    .overlay(Rectangle().stroke(Color.black, lineWidth: 1))

                VStack(alignment: .leading, spacing: 3) {
                    Text(newGoalType == .reps ? "reps" : "seconds")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.black)

                    Button {
                        newGoalType = newGoalType == .reps ? .timed : .reps
                        newReps = ""
                        newSeconds = ""
                    } label: {
                        Text("switch to \(newGoalType == .reps ? "timed" : "reps")")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .underline()
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }

            Button {
                submitMovement()
            } label: {
                Text("+ Add")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(canSubmit ? .white : Color(.systemGray3))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(canSubmit ? Color.black : Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit)

            Button("done with section") {
                closeForm()
            }
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var canSubmit: Bool {
        !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (newGoalType == .reps ? !newReps.isEmpty : !newSeconds.isEmpty)
    }

    private func submitMovement() {
        let m = Movement(
            name: newName.trimmingCharacters(in: .whitespacesAndNewlines),
            goalType: newGoalType,
            seconds: newGoalType == .timed ? Int(newSeconds) : nil,
            reps: newGoalType == .reps ? Int(newReps) : nil
        )
        section.movements.append(m)
        newName = ""
        newReps = ""
        newSeconds = ""
        nameFieldFocused = true
    }

    private func closeForm() {
        newName = ""
        newGoalType = defaultGoalType
        newReps = ""
        newSeconds = ""
        showAddForm = false
    }
}
