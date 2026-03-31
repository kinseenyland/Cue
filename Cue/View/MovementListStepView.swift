//
//  MovementListStepView.swift
//  Cue
//

import SwiftUI

struct MovementListStepView: View {
    let headline: String
    let defaultGoalType: GoalType?
    @Binding var durationMinutes: Int
    @Binding var movements: [Movement]

    @State private var assigningGoal = false
    @State private var newName = ""
    @State private var newGoalType: GoalType = .reps
    @State private var newReps = ""
    @State private var newSeconds = ""
    @State private var showNoteField = false
    @State private var newNote = ""
    @FocusState private var nameFieldFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
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

                addForm
                    .padding(.horizontal, 24)
            }
            .padding(.top, 4)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            newGoalType = defaultGoalType ?? .reps
            assigningGoal = defaultGoalType != nil
            nameFieldFocused = true
        }
    }

    private var addForm: some View {
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

            if assigningGoal {
                HStack(alignment: .center, spacing: 10) {
                    WheelValueInput(
                        value: newGoalType == .reps ? $newReps : $newSeconds,
                        mode: newGoalType
                    )

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
            } else {
                Button {
                    assigningGoal = true
                    newGoalType = .reps
                } label: {
                    Text("Assign reps/time")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .underline()
                }
                .buttonStyle(.plain)
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
        }
    }

    private var canSubmit: Bool {
        !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submitMovement() {
        let note = newNote.trimmingCharacters(in: .whitespacesAndNewlines)
        let m = Movement(
            name: newName.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: note.isEmpty ? nil : note,
            goalType: newGoalType,
            seconds: assigningGoal && newGoalType == .timed ? Int(newSeconds) : nil,
            reps: assigningGoal && newGoalType == .reps ? Int(newReps) : nil
        )
        movements.append(m)
        newName = ""
        newReps = ""
        newSeconds = ""
        assigningGoal = false
        showNoteField = false
        newNote = ""
        nameFieldFocused = true
    }
}

// MARK: - Movement Add Form

struct MovementAddFormView: View {
    let defaultGoalType: GoalType?
    @Binding var movements: [Movement]

    @State private var assigningGoal = false
    @State private var newName = ""
    @State private var newGoalType: GoalType = .reps
    @State private var newReps = ""
    @State private var newSeconds = ""
    @State private var showNoteField = false
    @State private var newNote = ""
    @FocusState private var nameFieldFocused: Bool

    var body: some View {
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

            if assigningGoal {
                HStack(alignment: .center, spacing: 10) {
                    WheelValueInput(
                        value: newGoalType == .reps ? $newReps : $newSeconds,
                        mode: newGoalType
                    )

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
            } else {
                Button {
                    assigningGoal = true
                    newGoalType = .reps
                } label: {
                    Text("Assign reps/time")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .underline()
                }
                .buttonStyle(.plain)
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
        }
        .onAppear {
            newGoalType = defaultGoalType ?? .reps
            assigningGoal = defaultGoalType != nil
        }
    }

    private var canSubmit: Bool {
        !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submitMovement() {
        let note = newNote.trimmingCharacters(in: .whitespacesAndNewlines)
        let m = Movement(
            name: newName.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: note.isEmpty ? nil : note,
            goalType: newGoalType,
            seconds: assigningGoal && newGoalType == .timed ? Int(newSeconds) : nil,
            reps: assigningGoal && newGoalType == .reps ? Int(newReps) : nil
        )
        movements.append(m)
        newName = ""
        newReps = ""
        newSeconds = ""
        assigningGoal = false
        showNoteField = false
        newNote = ""
        nameFieldFocused = true
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
                if let note = movement.notes, !note.isEmpty {
                    Text(note)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .italic()
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
    var dismissTrigger: Bool = false
    @State private var showPicker = false

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                showPicker.toggle()
            }
        } label: {
            HStack(spacing: 4) {
                Text("\(minutes) min")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .rotationEffect(.degrees(showPicker ? 180 : 0))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topTrailing) {
            if showPicker {
                WheelPickerPopup(
                    selection: $minutes,
                    values: Array(1...120),
                    label: { "\($0) min" },
                    onDone: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showPicker = false
                        }
                    }
                )
                .offset(x: -8, y: 34)
                .zIndex(2)
            }
        }
        .zIndex(showPicker ? 50 : 0)
        .onChange(of: dismissTrigger) { _, _ in
            if showPicker {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showPicker = false
                }
            }
        }
    }
}
