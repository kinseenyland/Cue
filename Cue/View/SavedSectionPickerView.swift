//
//  SavedSectionPickerView.swift
//  Cue
//

import FirebaseAuth
import SwiftUI

struct SavedSectionPickerView: View {
    let sectionType: WorkoutSection
    let onSelect: (SavedSection) -> Void

    @StateObject private var vm = SavedSectionsViewModel()
    @Environment(\.dismiss) private var dismiss

    private var filtered: [SavedSection] { vm.sections(for: sectionType) }

    private var sectionLabel: String {
        switch sectionType {
        case .warmUp: return "Warm-Up"
        case .main: return "Main"
        case .coolDown: return "Cool-Down"
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filtered.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary)
                        Text("No saved \(sectionLabel.lowercased()) sections yet.")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                        Text("Save a section from any workout to reuse it here.")
                            .font(.system(size: 13))
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(filtered) { section in
                                savedSectionCard(section)
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .background(Color.white)
            .navigationTitle("Saved \(sectionLabel) Sections")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.black)
                }
            }
        }
        .task { await vm.fetchSections() }
    }

    private func savedSectionCard(_ section: SavedSection) -> some View {
        Button {
            onSelect(section)
            dismiss()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(section.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.black)
                    Spacer()
                }

                if !section.movements.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(section.movements.prefix(5)) { movement in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color.black)
                                    .frame(width: 4, height: 4)
                                Text(movement.name)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.primary)
                                if let reps = movement.reps {
                                    Text("· \(reps) reps")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                } else if let secs = movement.seconds {
                                    Text("· \(secs)s")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        if section.movements.count > 5 {
                            Text("+\(section.movements.count - 5) more")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .padding(.leading, 10)
                        }
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.black, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Save Section Sheet

struct SaveSectionSheet: View {
    let sectionType: WorkoutSection
    let durationMinutes: Int
    let defaultName: String
    let defaultGoalType: GoalType?
    let showGoalOption: Bool
    let onSave: (String, [Movement]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var movements: [Movement]
    @State private var editingMovementId: String? = nil

    init(
        sectionType: WorkoutSection,
        movements: [Movement],
        durationMinutes: Int,
        defaultName: String = "",
        defaultGoalType: GoalType?,
        showGoalOption: Bool,
        onSave: @escaping (String, [Movement]) -> Void
    ) {
        self.sectionType = sectionType
        self.durationMinutes = durationMinutes
        self.defaultName = defaultName
        self.defaultGoalType = defaultGoalType
        self.showGoalOption = showGoalOption
        self.onSave = onSave
        _name = State(initialValue: defaultName)
        _movements = State(initialValue: movements)
    }

    private var sectionLabel: String {
        switch sectionType {
        case .warmUp: return "Warm-Up"
        case .main: return "Main"
        case .coolDown: return "Cool-Down"
        }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Save this \(sectionLabel.lowercased()) section so you can reuse it in future workouts.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)

                    TextField("Section name (e.g. My Go-To Warm Up)", text: $name)
                        .font(.system(size: 16))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 1))
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("MOVEMENTS")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .kerning(1.2)
                        .padding(.horizontal, 24)

                    if !movements.isEmpty {
                        ReorderableMovementList(
                            movements: $movements,
                            editingMovementId: $editingMovementId
                        )
                        .padding(.horizontal, 24)
                    }

                    MovementComposerView(
                        defaultGoalType: defaultGoalType,
                        showGoalOption: showGoalOption,
                        movements: $movements,
                        editingMovementId: $editingMovementId
                    )
                    .compositingGroup()
                    .zIndex(50)
                    .padding(.horizontal, 24)
                }
                .padding(.top, 2)

                Spacer()
            }
            .padding(20)
            .background(Color.white)
            .navigationTitle("Save Section")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.black)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(trimmed, movements)
                        dismiss()
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black)
                    .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !movements.isEmpty
    }
}

// MARK: - Saved Sections Components (no name collisions with dev movement UI)

private struct SavedEditableDurationBadge: View {
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

private struct SavedMovementRow: View {
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

            Button {
                onDelete()
            } label: {
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

private struct SavedMovementSummaryRow: View {
    let movement: Movement

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
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

private struct SavedMovementAddFormView: View {
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
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 1))
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
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 1))

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
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemGray3), lineWidth: 1))
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
            goalType: assigningGoal ? newGoalType : nil,
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

// MARK: - Create Section Sheet Helper (used by SavedSectionsListView)

struct CreateSectionSheet: View {
    let onSave: (SavedSection) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var sectionType: WorkoutSection = .warmUp
    @State private var movements: [Movement] = []
    @State private var editingMovementId: String? = nil

    // No duration UI: duration is set to the app's default for warm/cool sections.
    private let defaultDurationMinutes = 5

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !movements.isEmpty
    }

    private func sectionLabel(_ type: WorkoutSection) -> String {
        switch type {
        case .warmUp: return "Warm-Up"
        case .main: return "Main"
        case .coolDown: return "Cool-Down"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SECTION TYPE")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .kerning(1.2)

                        HStack(spacing: 8) {
                            ForEach(WorkoutSection.allCases, id: \.rawValue) { type in
                                Button { sectionType = type } label: {
                                    Text(sectionLabel(type))
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(sectionType == type ? .white : .black)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(sectionType == type ? Color.black : Color.clear)
                                        .clipShape(RoundedRectangle(cornerRadius: 20))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(Color.black, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                            Spacer()
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("SECTION NAME")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .kerning(1.2)

                        TextField("e.g. My Go-To Warm Up", text: $name)
                            .font(.system(size: 16))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.black, lineWidth: 1)
                            )
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("MOVEMENTS")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .kerning(1.2)
                            .padding(.horizontal, 12)

                        if !movements.isEmpty {
                            ReorderableMovementList(
                                movements: $movements,
                                editingMovementId: $editingMovementId
                            )
                            .padding(.horizontal, 12)
                        }

                        MovementComposerView(
                            defaultGoalType: nil,
                            showGoalOption: true,
                            movements: $movements,
                            editingMovementId: $editingMovementId
                        )
                        .compositingGroup()
                        .zIndex(50)
                        .padding(.horizontal, 12)
                    }
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.white)
            .navigationTitle("Create Section")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.black)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let uid = Auth.auth().currentUser?.uid else { return }
                        let section = SavedSection(
                            ownerId: uid,
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            sectionType: sectionType,
                            durationMinutes: defaultDurationMinutes,
                            movements: movements
                        )
                        onSave(section)
                        dismiss()
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(canSave ? .black : .gray)
                    .disabled(!canSave)
                }
            }
        }
    }
}

// MARK: - Edit Saved Section Sheet Helper (used by SavedSectionsListView)

struct EditSavedSectionSheet: View {
    let section: SavedSection
    let onSave: (SavedSection) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var movements: [Movement]
    @State private var editingMovementId: String? = nil

    init(section: SavedSection, onSave: @escaping (SavedSection) -> Void) {
        self.section = section
        self.onSave = onSave
        _name = State(initialValue: section.name)
        _movements = State(initialValue: section.movements)
    }

    private var canSave: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && !movements.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SECTION NAME")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .kerning(1.2)

                        TextField("Section name", text: $name)
                            .font(.system(size: 16))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.black, lineWidth: 1)
                            )
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("MOVEMENTS")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .kerning(1.2)
                            .padding(.horizontal, 12)

                        if !movements.isEmpty {
                            ReorderableMovementList(
                                movements: $movements,
                                editingMovementId: $editingMovementId
                            )
                            .padding(.horizontal, 12)
                        }

                        MovementComposerView(
                            defaultGoalType: nil,
                            showGoalOption: true,
                            movements: $movements,
                            editingMovementId: $editingMovementId
                        )
                        .compositingGroup()
                        .zIndex(50)
                        .padding(.horizontal, 12)
                    }
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.white)
            .navigationTitle("Edit Section")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.black)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        let updated = SavedSection(
                            id: section.id,
                            ownerId: section.ownerId,
                            name: trimmed,
                            sectionType: section.sectionType,
                            durationMinutes: section.durationMinutes,
                            movements: movements,
                            createdAt: section.createdAt
                        )
                        onSave(updated)
                        dismiss()
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(canSave ? .black : .gray)
                    .disabled(!canSave)
                }
            }
        }
    }
}

