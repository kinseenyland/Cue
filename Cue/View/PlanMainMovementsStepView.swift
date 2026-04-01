//
//  PlanMainMovementsStepView.swift
//  Cue
//

import FirebaseAuth
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
                    SectionMovementBlock(
                        section: $section,
                        defaultGoalType: vm.draft.goalType
                    )
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
    let defaultGoalType: GoalType?

    @State private var assigningGoal = false
    @State private var newName = ""
    @State private var newGoalType: GoalType = .reps
    @State private var newReps = ""
    @State private var newSeconds = ""
    @State private var showNoteField = false
    @State private var newNote = ""
    @FocusState private var nameFieldFocused: Bool

    @StateObject private var savedSectionsVM = SavedSectionsViewModel()
    @State private var showSaveSheet = false
    @State private var showLoadSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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

            sectionAddForm
                .padding(.horizontal, 24)

            HStack(spacing: 10) {
                if !section.movements.isEmpty {
                    Button { showSaveSheet = true } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "bookmark")
                                .font(.system(size: 12, weight: .medium))
                            Text("Save Section")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .overlay(Capsule().stroke(Color.black, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }

                Button { showLoadSheet = true } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 12, weight: .medium))
                        Text("Load Saved")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .overlay(Capsule().stroke(Color.black, lineWidth: 1))
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, 24)

            Divider()
                .padding(.top, 8)
        }
        .onAppear {
            newGoalType = defaultGoalType ?? .reps
            assigningGoal = defaultGoalType != nil
        }
        .sheet(isPresented: $showSaveSheet) {
            SaveSectionSheet(
                sectionType: .main,
                movements: section.movements,
                durationMinutes: section.durationMinutes,
                defaultName: section.name
            ) { name in
                guard let uid = Auth.auth().currentUser?.uid else { return }
                let saved = SavedSection(
                    ownerId: uid, name: name, sectionType: .main,
                    durationMinutes: section.durationMinutes, movements: section.movements
                )
                Task { await savedSectionsVM.saveSection(saved) }
            }
        }
        .sheet(isPresented: $showLoadSheet) {
            SavedSectionPickerView(sectionType: .main) { saved in
                let fresh = saved.movements.map { m in
                    Movement(
                        name: m.name, notes: m.notes, goalType: m.goalType,
                        seconds: m.seconds, reps: m.reps, section: m.section,
                        sectionName: m.sectionName, sectionDurationMinutes: m.sectionDurationMinutes
                    )
                }
                section.movements.append(contentsOf: fresh)
                section.durationMinutes = saved.durationMinutes
                if section.name.isEmpty { section.name = saved.name }
            }
        }
    }

    private var sectionAddForm: some View {
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
        section.movements.append(m)
        newName = ""
        newReps = ""
        newSeconds = ""
        assigningGoal = false
        showNoteField = false
        newNote = ""
        nameFieldFocused = true
    }
}
