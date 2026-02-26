//
//  MovementListStepView.swift
//  Cue
//

import SwiftUI

struct MovementListStepView: View {
    let headline: String
    let defaultGoalType: GoalType
    @Binding var durationMinutes: Int
    @Binding var movements: [Movement]

    @State private var showAddForm = false
    @State private var newName = ""
    @State private var newGoalType: GoalType = .reps
    @State private var newReps = ""
    @State private var newSeconds = ""
    @FocusState private var nameFieldFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Headline + editable duration badge
                HStack(alignment: .top, spacing: 12) {
                    Text(headline)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.black)
                    Spacer()
                    EditableDurationBadge(minutes: $durationMinutes)
                        .padding(.top, 8)
                }
                .padding(.horizontal, 24)

                if !movements.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(movements) { movement in
                            MovementRow(movement: movement) {
                                movements.removeAll { $0.id == movement.id }
                            }
                            if movement.id != movements.last?.id {
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
                    addForm
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
            }
            .padding(.top, 4)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: showAddForm) { _, isShowing in
            if isShowing { nameFieldFocused = true }
        }
    }

    private var addForm: some View {
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
        movements.append(m)
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

// MARK: - Movement Row

struct MovementRow: View {
    let movement: Movement
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(movement.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.black)

                if let reps = movement.reps {
                    Text("\(reps) reps")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                } else if let secs = movement.seconds {
                    Text("\(secs)s")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(.systemGray3))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Editable Duration Badge

struct EditableDurationBadge: View {
    @Binding var minutes: Int
    @State private var isEditing = false
    @State private var editText = ""
    @FocusState private var focused: Bool

    var body: some View {
        Group {
            if isEditing {
                HStack(spacing: 4) {
                    TextField("", text: $editText)
                        .keyboardType(.numberPad)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 28)
                        .multilineTextAlignment(.center)
                        .focused($focused)
                        .onSubmit { commit() }
                    Text("min")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .onAppear { focused = true }
            } else {
                Button {
                    editText = "\(minutes)"
                    isEditing = true
                } label: {
                    Text("\(minutes) min")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
        .onChange(of: focused) { _, isFocused in
            if !isFocused && isEditing { commit() }
        }
    }

    private func commit() {
        if let val = Int(editText), val > 0 { minutes = val }
        isEditing = false
    }
}
