//
//  EditPlanView.swift
//  Cue
//

import SwiftUI

struct EditPlanView: View {
    @StateObject private var vm: PlanCreationViewModel
    let onUpdate: (WorkoutPlanDraft) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showDiscardConfirmation = false

    init(
        plan: WorkoutPlan,
        availableTypes: [WorkoutType] = WorkoutType.allCases,
        onUpdate: @escaping (WorkoutPlanDraft) -> Void
    ) {
        _vm = StateObject(wrappedValue: PlanCreationViewModel(
            editingPlan: plan,
            availableTypes: availableTypes
        ))
        self.onUpdate = onUpdate
    }

    private var canSave: Bool {
        !vm.draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && vm.draft.type != nil
            && vm.draft.difficulty != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    nameSection
                    typePillsSection
                    durationSection
                    warmUpSection
                    mainSectionsBlock
                    coolDownSection
                }
                .padding(.top, 8)
                .padding(.bottom, 40)
            }

            saveButton
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
        }
        .background(Color.white.ignoresSafeArea())
        .environmentObject(vm)
        .onChange(of: vm.draft.durationMinutes) { _ in vm.redistributeMainSectionTime() }
        .onChange(of: vm.draft.warmUpDurationMinutes) { _ in vm.redistributeMainSectionTime() }
        .onChange(of: vm.draft.coolDownDurationMinutes) { _ in vm.redistributeMainSectionTime() }
        .onChange(of: vm.draft.mainSections.count) { _ in vm.redistributeMainSectionTime() }
        .interactiveDismissDisabled(true)
        .overlay {
            if showDiscardConfirmation {
                discardOverlay
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showDiscardConfirmation)
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            HStack {
                Button("Cancel") { showDiscardConfirmation = true }
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Text("Edit Plan")
                .font(.system(size: 17, weight: .semibold))
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Name

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PLAN NAME")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .kerning(1.2)

            TextField("e.g. Morning Flow", text: $vm.draft.name)
                .font(.system(size: 16))
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .overlay(Rectangle().stroke(Color.black, lineWidth: 1))
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Type, Intensity, Format pills

    private var typePillsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("TYPE")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .kerning(1.2)
                    .padding(.horizontal, 24)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(vm.availableTypes, id: \.self) { type in
                            PlanPillButton(
                                label: type.displayName,
                                isSelected: vm.draft.type == type
                            ) { vm.draft.type = type }
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("INTENSITY")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .kerning(1.2)
                    .padding(.horizontal, 24)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Difficulty.allCases, id: \.self) { difficulty in
                            PlanPillButton(
                                label: difficulty.rawValue.capitalized,
                                isSelected: vm.draft.difficulty == difficulty
                            ) { vm.draft.difficulty = difficulty }
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text("FORMAT")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .kerning(1.2)
                    Text("\u{00B7} Optional")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)

                HStack(spacing: 8) {
                    ForEach(GoalType.allCases, id: \.self) { goalType in
                        PlanPillButton(
                            label: goalType == .reps ? "Reps" : "Timed",
                            isSelected: vm.draft.goalType == goalType
                        ) {
                            vm.draft.goalType = vm.draft.goalType == goalType ? nil : goalType
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }

    // MARK: - Duration

    private var durationSection: some View {
        HStack {
            Text("DURATION")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .kerning(1.2)
            Spacer()
            EditableDurationBadge(minutes: $vm.draft.durationMinutes)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Warm-Up

    private var warmUpSection: some View {
        EditPlanSectionView(
            title: "WARM-UP",
            defaultGoalType: vm.draft.goalType,
            durationMinutes: $vm.draft.warmUpDurationMinutes,
            movements: $vm.draft.warmUpMovements,
            playlistId: $vm.draft.warmUpPlaylistId
        )
    }

    // MARK: - Main Sections

    private var mainSectionsBlock: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach($vm.draft.mainSections) { $section in
                EditPlanMainSubSection(
                    section: $section,
                    defaultGoalType: vm.draft.goalType,
                    canDelete: vm.draft.mainSections.count > 1,
                    onDelete: {
                        vm.draft.mainSections.removeAll { $0.id == section.id }
                    }
                )
            }
            .onMove { from, to in
                vm.draft.mainSections.move(fromOffsets: from, toOffset: to)
            }

            HStack {
                Button {
                    vm.draft.mainSections.append(WorkoutSubSection())
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Add Section")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .overlay(Capsule().stroke(Color.black, lineWidth: 1))
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, 24)

            PlanSectionPlaylistPicker(
                title: "Main workout playlist",
                selectedPlaylistId: $vm.draft.mainPlaylistId
            )
        }
    }

    // MARK: - Cool-Down

    private var coolDownSection: some View {
        EditPlanSectionView(
            title: "COOL-DOWN",
            defaultGoalType: vm.draft.goalType,
            durationMinutes: $vm.draft.coolDownDurationMinutes,
            movements: $vm.draft.coolDownMovements,
            playlistId: $vm.draft.coolDownPlaylistId
        )
    }

    // MARK: - Save

    private var saveButton: some View {
        Button {
            onUpdate(vm.toWorkoutPlanDraft())
            dismiss()
        } label: {
            Text("Save Changes")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(canSave ? Color.black : Color(.systemGray4))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(!canSave)
    }

    // MARK: - Discard overlay

    private var discardOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { showDiscardConfirmation = false }

            VStack(spacing: 16) {
                HStack {
                    Spacer()
                    Button { showDiscardConfirmation = false } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 30, height: 30)
                            .background(Color(.systemGray5))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }

                Text("Discard changes?")
                    .font(.system(size: 18, weight: .bold))

                Text("Your unsaved edits will be lost.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                VStack(spacing: 10) {
                    Button {
                        showDiscardConfirmation = false
                    } label: {
                        Text("Keep Editing")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)

                    Button {
                        showDiscardConfirmation = false
                        dismiss()
                    } label: {
                        Text("Discard Changes")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color.red)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
            .padding(.horizontal, 40)
        }
    }
}

// MARK: - Edit Plan Section (warm-up / cool-down)

private struct EditPlanSectionView: View {
    let title: String
    let defaultGoalType: GoalType?
    @Binding var durationMinutes: Int
    @Binding var movements: [Movement]
    @Binding var playlistId: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .kerning(1.0)
                Spacer()
                EditableDurationBadge(minutes: $durationMinutes)
            }
            .padding(.horizontal, 24)

            if !movements.isEmpty {
                ReorderableMovementList(movements: $movements)
                    .padding(.horizontal, 24)
            }

            MovementAddFormView(
                defaultGoalType: defaultGoalType,
                movements: $movements
            )
            .padding(.horizontal, 24)

            PlanSectionPlaylistPicker(
                title: "\(title.capitalized) playlist",
                selectedPlaylistId: $playlistId
            )

            Divider()
                .padding(.horizontal, 24)
        }
    }
}

// MARK: - Edit Plan Main Sub-Section

private struct EditPlanMainSubSection: View {
    @Binding var section: WorkoutSubSection
    let defaultGoalType: GoalType?
    let canDelete: Bool
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                TextField("Section name", text: $section.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .kerning(1.0)
                    .textCase(.uppercase)

                Spacer()

                EditableDurationBadge(minutes: $section.durationMinutes)

                if canDelete {
                    Button(action: onDelete) {
                        Image(systemName: "minus.circle")
                            .font(.system(size: 18))
                            .foregroundStyle(Color(.systemGray3))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)

            if !section.movements.isEmpty {
                ReorderableMovementList(movements: $section.movements)
                    .padding(.horizontal, 24)
            }

            MovementAddFormView(
                defaultGoalType: defaultGoalType,
                movements: $section.movements
            )
            .padding(.horizontal, 24)

            Divider()
                .padding(.horizontal, 24)
        }
    }
}

// MARK: - Reorderable Movement List

/// A non-scrolling List that shows movement rows with always-on drag-to-reorder handles.
private struct ReorderableMovementList: View {
    @Binding var movements: [Movement]

    private static let rowHeight: CGFloat = 52

    var body: some View {
        List {
            ForEach($movements) { $movement in
                MovementRow(movement: movement) {
                    movements.removeAll { $0.id == movement.id }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color(.systemGray6))
                .listRowSeparator(.hidden)
            }
            .onMove { from, to in
                movements.move(fromOffsets: from, toOffset: to)
            }
        }
        .environment(\.editMode, .constant(.active))
        .scrollDisabled(true)
        .listStyle(.plain)
        .frame(height: CGFloat(movements.count) * Self.rowHeight)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
