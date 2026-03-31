//
//  MovementComposerView.swift
//  Cue
//

import SwiftUI

/// Collapsed-to-expanded movement composer with segmented goal selection.
/// Defaults to `defaultGoalType` when provided, but users can switch modes.
struct MovementComposerView: View {
    let defaultGoalType: GoalType?
    @Binding var movements: [Movement]

    @State private var isExpanded = false
    @State private var newName = ""
    @State private var selectedGoalType: GoalType = .reps
    @State private var repsValue = ""
    @State private var secondsValue = ""
    @State private var showNoteField = false
    @State private var newNote = ""
    @FocusState private var nameFieldFocused: Bool

    private var valueBinding: Binding<String> {
        selectedGoalType == .reps ? $repsValue : $secondsValue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if isExpanded {
                expandedComposer
            } else {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded = true
                    }
                    if defaultGoalType != nil {
                        selectedGoalType = defaultGoalType ?? .reps
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        nameFieldFocused = true
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Add movement")
                            .font(.system(size: 14, weight: .medium))
                        Spacer()
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .onAppear {
            selectedGoalType = defaultGoalType ?? .reps
        }
    }

    private var expandedComposer: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                TextField("Movement name", text: $newName)
                    .font(.system(size: 16))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .overlay(Rectangle().stroke(Color.black, lineWidth: 1))
                    .focused($nameFieldFocused)

                Button {
                    submitMovement()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(canSubmit ? Color.black : Color(.systemGray4))
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit)
            }

            HStack(alignment: .center, spacing: 10) {
                Picker("Goal Type", selection: $selectedGoalType) {
                    Text("Reps").tag(GoalType.reps)
                    Text("Seconds").tag(GoalType.timed)
                }
                .pickerStyle(.segmented)

                WheelValueInput(
                    value: valueBinding,
                    mode: selectedGoalType
                )
            }

            if showNoteField {
                TextField("e.g. 5lb weight, use a band", text: $newNote)
                    .font(.system(size: 14))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .overlay(Rectangle().stroke(Color(.systemGray3), lineWidth: 1))
            } else {
                Button {
                    showNoteField = true
                } label: {
                    Text("Add a note")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .underline()
                }
                .buttonStyle(.plain)
            }

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded = false
                }
                clearComposerInputs()
            } label: {
                Text("Cancel")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .underline()
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var canSubmit: Bool {
        !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submitMovement() {
        let note = newNote.trimmingCharacters(in: .whitespacesAndNewlines)
        let movement = Movement(
            name: newName.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: note.isEmpty ? nil : note,
            goalType: selectedGoalType,
            seconds: selectedGoalType == .timed ? Int(secondsValue) : nil,
            reps: selectedGoalType == .reps ? Int(repsValue) : nil
        )

        movements.append(movement)
        withAnimation(.easeInOut(duration: 0.2)) {
            isExpanded = false
        }
        clearComposerInputs()
    }

    private func clearComposerInputs() {
        newName = ""
        repsValue = ""
        secondsValue = ""
        showNoteField = false
        newNote = ""
        selectedGoalType = defaultGoalType ?? .reps
        nameFieldFocused = false
    }
}
