//
//  QuickCreateView.swift
//  Cue
//

import SwiftUI

struct QuickCreateView: View {
    let availableTypes: [WorkoutType]
    let workoutStructure: WorkoutStructurePreference?
    let onSave: (WorkoutPlanDraft) -> Void

    @StateObject private var vm: PlanCreationViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showDiscardConfirmation = false

    init(
        availableTypes: [WorkoutType] = WorkoutType.allCases,
        workoutStructure: WorkoutStructurePreference? = nil,
        onSave: @escaping (WorkoutPlanDraft) -> Void
    ) {
        self.availableTypes = availableTypes
        self.workoutStructure = workoutStructure
        self.onSave = onSave
        _vm = StateObject(wrappedValue: PlanCreationViewModel(
            availableTypes: availableTypes,
            workoutStructure: workoutStructure
        ))
    }

    private var canSave: Bool {
        !vm.draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && vm.draft.type != nil
            && vm.draft.difficulty != nil
            && hasAtLeastOneMovement
    }

    private var hasAtLeastOneMovement: Bool {
        !vm.draft.warmUpMovements.isEmpty
            || vm.draft.mainSections.contains(where: { !$0.movements.isEmpty })
            || !vm.draft.coolDownMovements.isEmpty
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
        .overlay {
            if showDiscardConfirmation {
                discardOverlay
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showDiscardConfirmation)
        .interactiveDismissDisabled(true)
        .onChange(of: vm.draft.durationMinutes) { _, _ in vm.redistributeMainSectionTime() }
        .onChange(of: vm.draft.warmUpDurationMinutes) { _, _ in vm.redistributeMainSectionTime() }
        .onChange(of: vm.draft.coolDownDurationMinutes) { _, _ in vm.redistributeMainSectionTime() }
        .onChange(of: vm.draft.mainSections.count) { _, _ in vm.redistributeMainSectionTime() }
        .onChange(of: vm.totalMainMinutes) { _, _ in vm.redistributeWarmUpCoolDown() }
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
            Text("Quick Create")
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

    // MARK: - Type / Intensity / Format pills

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
                        ForEach(availableTypes, id: \.self) { type in
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("WARM-UP")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .kerning(1.0)
                Spacer()
                EditableDurationBadge(minutes: $vm.draft.warmUpDurationMinutes)
            }
            .padding(.horizontal, 24)

            if !vm.draft.warmUpMovements.isEmpty {
                VStack(spacing: 0) {
                    ForEach(vm.draft.warmUpMovements) { movement in
                        MovementRow(movement: movement) {
                            vm.draft.warmUpMovements.removeAll { $0.id == movement.id }
                        }
                        if movement.id != vm.draft.warmUpMovements.last?.id {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 24)
            }

            MovementAddFormView(
                defaultGoalType: vm.draft.goalType,
                movements: $vm.draft.warmUpMovements
            )
            .padding(.horizontal, 24)

            PlanSectionPlaylistPicker(
                title: "Warm-up playlist",
                selectedPlaylistId: $vm.draft.warmUpPlaylistId
            )

            Divider().padding(.horizontal, 24)
        }
    }

    // MARK: - Main Sections

    private var mainSectionsBlock: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach($vm.draft.mainSections) { $section in
                quickMainSubSection(section: $section)
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

    @ViewBuilder
    private func quickMainSubSection(section: Binding<WorkoutSubSection>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                TextField("Section name", text: section.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .kerning(1.0)
                    .textCase(.uppercase)
                Spacer()
                EditableDurationBadge(minutes: section.durationMinutes)
                if vm.draft.mainSections.count > 1 {
                    Button {
                        vm.draft.mainSections.removeAll { $0.id == section.wrappedValue.id }
                    } label: {
                        Image(systemName: "minus.circle")
                            .font(.system(size: 18))
                            .foregroundStyle(Color(.systemGray3))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)

            if !section.wrappedValue.movements.isEmpty {
                VStack(spacing: 0) {
                    ForEach(section.wrappedValue.movements) { movement in
                        MovementRow(movement: movement) {
                            section.movements.wrappedValue.removeAll { $0.id == movement.id }
                        }
                        if movement.id != section.wrappedValue.movements.last?.id {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 24)
            }

            MovementAddFormView(
                defaultGoalType: vm.draft.goalType,
                movements: section.movements
            )
            .padding(.horizontal, 24)

            Divider().padding(.horizontal, 24)
        }
    }

    // MARK: - Cool-Down

    private var coolDownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("COOL-DOWN")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .kerning(1.0)
                Spacer()
                EditableDurationBadge(minutes: $vm.draft.coolDownDurationMinutes)
            }
            .padding(.horizontal, 24)

            if !vm.draft.coolDownMovements.isEmpty {
                VStack(spacing: 0) {
                    ForEach(vm.draft.coolDownMovements) { movement in
                        MovementRow(movement: movement) {
                            vm.draft.coolDownMovements.removeAll { $0.id == movement.id }
                        }
                        if movement.id != vm.draft.coolDownMovements.last?.id {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 24)
            }

            MovementAddFormView(
                defaultGoalType: vm.draft.goalType,
                movements: $vm.draft.coolDownMovements
            )
            .padding(.horizontal, 24)

            PlanSectionPlaylistPicker(
                title: "Cool-down playlist",
                selectedPlaylistId: $vm.draft.coolDownPlaylistId
            )
        }
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            onSave(vm.toWorkoutPlanDraft())
            dismiss()
        } label: {
            Text("Save Plan")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(canSave ? Color.black : Color(.systemGray4))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(!canSave)
    }

    // MARK: - Discard Overlay

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

                Text("Discard plan?")
                    .font(.system(size: 18, weight: .bold))

                Text("Your unsaved plan will be lost.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                VStack(spacing: 10) {
                    Button { showDiscardConfirmation = false } label: {
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
                        Text("Discard")
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
