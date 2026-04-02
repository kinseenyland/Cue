//
//  MovementComposerView.swift
//  Cue
//

import SwiftUI

/// Collapsed-to-expanded movement composer with segmented goal selection.
/// Defaults to `defaultGoalType` when provided, but users can switch modes.
struct MovementComposerView: View {
    let defaultGoalType: GoalType?
    var showGoalOption: Bool = true
    @Binding var movements: [Movement]
    @Binding var editingMovementId: String?

    @State private var isExpanded = false
    @State private var newName = ""
    @State private var selectedGoalType: GoalType = .reps
    @State private var repsValue = "10"
    @State private var secondsValue = "30"
    @State private var showGoalInput = false
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
                    editingMovementId = nil
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded = true
                        showGoalInput = defaultGoalType != nil
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
        .onChange(of: editingMovementId) { _, newId in
            guard let newId, let movement = movements.first(where: { $0.id == newId }) else { return }
            hydrateFromMovement(movement)
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                nameFieldFocused = true
            }
        }
    }

    private var expandedComposer: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Movement name", text: $newName)
                .font(.system(size: 16))
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .cueFormFieldOutline()
                .focused($nameFieldFocused)

            if showGoalOption || editingMovementId != nil {
                if showGoalInput {
                    HStack(alignment: .center, spacing: 10) {
                        WheelValueInput(
                            value: valueBinding,
                            mode: selectedGoalType,
                            onOpen: { nameFieldFocused = false }
                        )

                        goalTypeToggle

                        Spacer()

                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showGoalInput = false
                            }
                            repsValue = ""
                            secondsValue = ""
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .zIndex(10)
                } else {
                    Button {
                        nameFieldFocused = false
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showGoalInput = true
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "timer")
                                .font(.system(size: 12))
                            Text("Assign reps / time")
                                .font(.system(size: 13))
                        }
                        .foregroundStyle(.secondary)
                        .underline()
                    }
                    .buttonStyle(.plain)
                }
            }

            if showNoteField {
                TextField("e.g. 5lb weight, use a band", text: $newNote)
                    .font(.system(size: 14))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .cueFormFieldOutline(color: Color(.systemGray3))
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

            HStack(spacing: 12) {
                Button {
                    submitMovement()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: editingMovementId != nil ? "checkmark.circle.fill" : "plus.circle.fill")
                            .font(.system(size: 18))
                        Text(editingMovementId != nil ? "Save" : "Add")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(canSubmit ? Color.white : Color(.systemGray4))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(canSubmit ? Color.black : Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit)

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
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray6))
        )
    }

    private var goalTypeToggle: some View {
        HStack(spacing: 0) {
            goalTypeButton("Reps", type: .reps)
            goalTypeButton("Seconds", type: .timed)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemGray4), lineWidth: 1))
    }

    private func goalTypeButton(_ label: String, type: GoalType) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedGoalType = type
            }
        } label: {
            Text(label)
                .font(.system(size: 13, weight: selectedGoalType == type ? .semibold : .regular))
                .foregroundStyle(selectedGoalType == type ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(selectedGoalType == type ? Color.black : Color.clear)
        }
        .buttonStyle(.plain)
    }

    private var canSubmit: Bool {
        !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func hydrateFromMovement(_ movement: Movement) {
        newName = movement.name
        newNote = movement.notes ?? ""
        showNoteField = !(movement.notes?.isEmpty ?? true)
        if let gt = movement.goalType {
            showGoalInput = true
            selectedGoalType = gt
            if gt == .reps {
                repsValue = movement.reps.map(String.init) ?? ""
            } else {
                secondsValue = movement.seconds.map(String.init) ?? ""
            }
        } else {
            showGoalInput = false
            repsValue = "10"
            secondsValue = "30"
        }
    }

    private func submitMovement() {
        let note = newNote.trimmingCharacters(in: .whitespacesAndNewlines)
        let goalType = showGoalInput ? selectedGoalType : nil
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)

        if let editId = editingMovementId, let idx = movements.firstIndex(where: { $0.id == editId }) {
            var updated = movements[idx]
            updated.name = trimmedName
            updated.notes = note.isEmpty ? nil : note
            updated.goalType = goalType
            updated.seconds = goalType == .timed ? Int(secondsValue) : nil
            updated.reps = goalType == .reps ? Int(repsValue) : nil
            movements[idx] = updated
        } else {
            let movement = Movement(
                name: trimmedName,
                notes: note.isEmpty ? nil : note,
                goalType: goalType,
                seconds: goalType == .timed ? Int(secondsValue) : nil,
                reps: goalType == .reps ? Int(repsValue) : nil
            )
            movements.append(movement)
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            isExpanded = false
        }
        clearComposerInputs()
    }

    private func clearComposerInputs() {
        editingMovementId = nil
        newName = ""
        repsValue = "10"
        secondsValue = "30"
        showGoalInput = defaultGoalType != nil
        showNoteField = false
        newNote = ""
        selectedGoalType = defaultGoalType ?? .reps
        nameFieldFocused = false
    }
}
