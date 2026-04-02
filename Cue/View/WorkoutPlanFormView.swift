//
//  WorkoutPlanFormView.swift
//  Cue
//
//  Created by Kinsee Nyland on 2/10/26.
//

import SwiftUI

// MARK: - Movement Draft (local form state)

struct MovementDraft: Identifiable {
    let id = UUID()
    var name: String = ""
    var goalType: GoalType? = nil
    var amount: Int? = nil
    var notes: String = ""

    init() {}

    init(from movement: Movement) {
        self.name = movement.name
        self.goalType = movement.goalType
        self.amount = movement.goalType == .timed ? movement.seconds : movement.reps
        self.notes = movement.notes ?? ""
    }

    func toMovement() -> Movement? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let goalType else { return nil }
        return Movement(
            name: trimmed,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes,
            goalType: goalType,
            seconds: goalType == .timed ? (amount ?? 30) : nil,
            reps: goalType == .reps ? (amount ?? 10) : nil
        )
    }
}

// MARK: - Main Form View

struct WorkoutPlanFormView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var selectedType: WorkoutType?
    @State private var selectedDifficulty: Difficulty?
    @State private var durationMinutes: Int
    @State private var movements: [MovementDraft]

    let isEditing: Bool
    let availableTypes: [WorkoutType]
    let onSave: (WorkoutPlanDraft) -> Void

    init(draft: WorkoutPlanDraft? = nil, availableTypes: [WorkoutType] = WorkoutType.allCases, onSave: @escaping (WorkoutPlanDraft) -> Void) {
        self.availableTypes = availableTypes
        self.isEditing = draft != nil
        self.onSave = onSave
        _title = State(initialValue: draft?.title ?? "")
        _selectedType = State(initialValue: draft?.type)
        _selectedDifficulty = State(initialValue: draft?.difficulty)
        _durationMinutes = State(initialValue: draft?.durationMinutes ?? 45)
        let movs: [MovementDraft] = draft?.movements.isEmpty == false
            ? draft!.movements.map { MovementDraft(from: $0) }
            : [MovementDraft()]
        _movements = State(initialValue: movs)
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        selectedType != nil &&
        selectedDifficulty != nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {

                // Header
                HStack {
                    Button("Cancel") { dismiss() }
                        .font(.system(size: 14))
                        .foregroundStyle(.black)
                    Spacer()
                    Text(isEditing ? "Edit Plan" : "Create a Plan")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.black)
                    Spacer()
                    Button("Save") { savePlan() }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(canSave ? .black : Color(white: 0.647))
                        .disabled(!canSave)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 4)

                // Plan Name
                TextField("Plan Name", text: $title)
                    .font(.system(size: 12))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.black, lineWidth: 1)
                    )
                    .padding(.horizontal, 16)

                // Type + Difficulty
                HStack(spacing: 10) {
                    FormDropdown(
                        placeholder: "Select Type",
                        selected: selectedType?.displayName
                    ) {
                        ForEach(availableTypes, id: \.self) { type in
                            Button(type.displayName) { selectedType = type }
                        }
                    }

                    FormDropdown(
                        placeholder: "Select Intensity",
                        selected: selectedDifficulty?.rawValue.capitalized
                    ) {
                        ForEach(Difficulty.allCases, id: \.self) { diff in
                            Button(diff.rawValue.capitalized) { selectedDifficulty = diff }
                        }
                    }
                }
                .padding(.horizontal, 16)

                // Movement sections
                ForEach($movements) { $movement in
                    let index = movements.firstIndex(where: { $0.id == movement.id }) ?? 0
                    MovementSectionView(movement: $movement, sectionNumber: index + 1)
                        .padding(.horizontal, 16)
                }

                // Add movement button
                HStack {
                    Spacer()
                    Button {
                        movements.append(MovementDraft())
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(.black)
                    }
                    Spacer()
                }
                .padding(.vertical, 8)
            }
            .padding(.bottom, 34)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func savePlan() {
        guard let type = selectedType, let difficulty = selectedDifficulty else { return }
        let plan = WorkoutPlanDraft(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            type: type,
            difficulty: difficulty,
            durationMinutes: durationMinutes,
            movements: movements.compactMap { $0.toMovement() }
        )
        onSave(plan)
        dismiss()
    }
}

// MARK: - Movement Section

struct MovementSectionView: View {
    @Binding var movement: MovementDraft
    let sectionNumber: Int

    private var amountOptions: [Int] {
        switch movement.goalType {
        case .timed: return [10, 15, 20, 30, 45, 60, 90, 120, 180, 300]
        case .reps:  return [5, 8, 10, 12, 15, 20, 25, 30, 40, 50]
        case nil:    return []
        }
    }

    private var amountLabel: String {
        guard let amount = movement.amount, let goalType = movement.goalType else {
            return "Select Amount"
        }
        return goalType == .timed ? "\(amount)s" : "\(amount) reps"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Movement \(sectionNumber):")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.black)

            // Movement Name
            TextField("Movement Name", text: $movement.name)
                .font(.system(size: 12))
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.black, lineWidth: 1)
                )

            // Goal Type + Amount
            HStack(spacing: 10) {
                FormDropdown(
                    placeholder: "Time/Repetition",
                    selected: movement.goalType == .timed ? "Time" : movement.goalType == .reps ? "Reps" : nil
                ) {
                    Button("Time") {
                        movement.goalType = .timed
                        movement.amount = nil
                    }
                    Button("Reps") {
                        movement.goalType = .reps
                        movement.amount = nil
                    }
                }

                FormDropdown(
                    placeholder: "Select Amount",
                    selected: movement.amount != nil ? amountLabel : nil,
                    disabled: movement.goalType == nil
                ) {
                    ForEach(amountOptions, id: \.self) { option in
                        Button(movement.goalType == .timed ? "\(option)s" : "\(option) reps") {
                            movement.amount = option
                        }
                    }
                }
            }

            // Notes
            TextField("Movement Notes", text: $movement.notes, axis: .vertical)
                .font(.system(size: 12))
                .lineLimit(4...)
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .frame(minHeight: 76, alignment: .topLeading)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.black, lineWidth: 1)
                )
        }
    }
}

// MARK: - Reusable Dropdown

struct FormDropdown<Content: View>: View {
    let placeholder: String
    let selected: String?
    var disabled: Bool = false
    var onTap: (() -> Void)? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        Menu {
            if !disabled { content() }
        } label: {
            HStack {
                Text(selected ?? placeholder)
                    .font(.system(size: 12))
                    .foregroundStyle(selected == nil ? Color(white: 0.647) : .black)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 11))
                    .foregroundStyle(disabled ? Color(white: 0.647) : .black)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(disabled ? Color(white: 0.8) : Color.black, lineWidth: 1)
            )
        }
        .simultaneousGesture(TapGesture().onEnded {
            onTap?()
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        })
        .disabled(disabled)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        WorkoutPlanFormView { _ in }
    }
}
