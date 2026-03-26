//
//  PlanFormView.swift
//  Cue
//

import SwiftUI

struct PlanFormView: View {

    enum Mode {
        case create(
            workoutStructure: WorkoutStructurePreference? = nil,
            onSave: (WorkoutPlanDraft) -> Void
        )
        case edit(
            plan: WorkoutPlan,
            onSave: (WorkoutPlanDraft) -> Void
        )
    }

    enum FormSection: Hashable {
        case warmUp, main, coolDown
    }

    let availableTypes: [WorkoutType]
    let mode: Mode

    @StateObject private var vm: PlanCreationViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showDiscardConfirmation = false
    @State private var expandedSections: Set<FormSection>

    // MARK: - Init

    init(availableTypes: [WorkoutType] = WorkoutType.allCases, mode: Mode) {
        self.availableTypes = availableTypes
        self.mode = mode
        switch mode {
        case .create(let workoutStructure, _):
            _vm = StateObject(wrappedValue: PlanCreationViewModel(
                availableTypes: availableTypes,
                workoutStructure: workoutStructure
            ))
            _expandedSections = State(initialValue: [])
        case .edit(let plan, _):
            _vm = StateObject(wrappedValue: PlanCreationViewModel(
                editingPlan: plan,
                availableTypes: availableTypes
            ))
            _expandedSections = State(initialValue: [])
        }
    }

    // MARK: - Mode helpers

    private var isEditMode: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var headerTitle: String {
        isEditMode ? "Edit Plan" : "Quick Create"
    }

    private var saveButtonTitle: String {
        isEditMode ? "Save Changes" : "Save Plan"
    }

    private var discardTitle: String {
        isEditMode ? "Discard changes?" : "Discard plan?"
    }

    private var discardBody: String {
        isEditMode ? "Your unsaved edits will be lost." : "Your unsaved plan will be lost."
    }

    private var discardButtonLabel: String {
        isEditMode ? "Discard Changes" : "Discard"
    }

    private var onSaveCallback: (WorkoutPlanDraft) -> Void {
        switch mode {
        case .create(_, let onSave): return onSave
        case .edit(_, let onSave): return onSave
        }
    }

    private var canSave: Bool {
        let base = !vm.draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && vm.draft.type != nil
            && vm.draft.difficulty != nil
        if isEditMode { return base }
        return base && hasAtLeastOneMovement
    }

    private var hasAtLeastOneMovement: Bool {
        !vm.draft.warmUpMovements.isEmpty
            || vm.draft.mainSections.contains(where: { !$0.movements.isEmpty })
            || !vm.draft.coolDownMovements.isEmpty
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    nameSection
                    VStack(spacing: 16) {
                        metadataSection
                        durationSection
                    }
                    warmUpSection
                    mainSectionsBlock
                    coolDownSection
                }
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)

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
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil, from: nil, for: nil
                    )
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.black)
            }
        }
        .onChange(of: customDurationFocused) { _, focused in
            if !focused && isEditingCustomDuration {
                commitCustomDuration()
            }
        }
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
            Text(headerTitle)
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

    // MARK: - Type / Intensity

    private var metadataSection: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("TYPE")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .kerning(1.2)
                FormDropdown(
                    placeholder: "Select type",
                    selected: vm.draft.type?.displayName
                ) {
                    ForEach(availableTypes, id: \.self) { type in
                        Button(type.displayName) { vm.draft.type = type }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("INTENSITY")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .kerning(1.2)
                FormDropdown(
                    placeholder: "Select intensity",
                    selected: vm.draft.difficulty?.rawValue.capitalized
                ) {
                    ForEach(Difficulty.allCases, id: \.self) { difficulty in
                        Button(difficulty.rawValue.capitalized) { vm.draft.difficulty = difficulty }
                    }
                }
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Duration

    private let durationPresets = [30, 45, 60, 75]
    @State private var isEditingCustomDuration = false
    @State private var customDurationText = ""
    @FocusState private var customDurationFocused: Bool

    /// True when the current duration is a custom (non-preset) value.
    private var hasCustomDuration: Bool {
        !durationPresets.contains(vm.draft.durationMinutes)
    }

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text("DURATION")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .kerning(1.2)
                Text("(min)")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 24)

            HStack(spacing: 8) {
                ForEach(durationPresets, id: \.self) { mins in
                    Button {
                        vm.draft.durationMinutes = mins
                        isEditingCustomDuration = false
                        customDurationFocused = false
                        vm.redistributeMainSectionTime()
                    } label: {
                        Text("\(mins)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(
                                !hasCustomDuration && !isEditingCustomDuration && vm.draft.durationMinutes == mins ? .white : .black
                            )
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                !hasCustomDuration && !isEditingCustomDuration && vm.draft.durationMinutes == mins ? Color.black : Color.clear
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.black, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }

                if isEditingCustomDuration {
                    // Inline text field replacing the Other button
                    HStack(spacing: 4) {
                        TextField("", text: $customDurationText)
                            .keyboardType(.numberPad)
                            .font(.system(size: 13, weight: .medium))
                            .multilineTextAlignment(.center)
                            .frame(width: 40)
                            .focused($customDurationFocused)
                            .onSubmit { commitCustomDuration() }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.black, lineWidth: 1))
                    .foregroundStyle(.white)
                } else {
                    // Show "Other" or the custom value
                    Button {
                        customDurationText = hasCustomDuration ? "\(vm.draft.durationMinutes)" : ""
                        isEditingCustomDuration = true
                        customDurationFocused = true
                    } label: {
                        Text(hasCustomDuration ? "\(vm.draft.durationMinutes)" : "Other")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(hasCustomDuration ? .white : .black)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(hasCustomDuration ? Color.black : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.black, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, 24)
        }
    }

    private func commitCustomDuration() {
        if let mins = Int(customDurationText), mins > 0 {
            vm.draft.durationMinutes = mins
            vm.redistributeMainSectionTime()
        }
        isEditingCustomDuration = false
        customDurationFocused = false
    }

    // MARK: - Collapsible Section Header

    private func collapsibleHeader(
        title: String,
        section: FormSection,
        movementCount: Int,
        durationBinding: Binding<Int>
    ) -> some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(expandedSections.contains(section) ? 90 : 0))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .kerning(1.0)
                if !expandedSections.contains(section) && movementCount > 0 {
                    Text("\(movementCount)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(Color.black)
                        .clipShape(Circle())
                }
            }
            Spacer()
            EditableDurationBadge(minutes: durationBinding)
        }
        .padding(.horizontal, 24)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.25)) {
                if expandedSections.contains(section) {
                    expandedSections.remove(section)
                } else {
                    expandedSections.insert(section)
                }
            }
        }
    }

    // MARK: - Warm-Up

    private var warmUpSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            collapsibleHeader(
                title: "WARM-UP",
                section: .warmUp,
                movementCount: vm.draft.warmUpMovements.count,
                durationBinding: $vm.draft.warmUpDurationMinutes
            )

            if expandedSections.contains(.warmUp) {
                if !vm.draft.warmUpMovements.isEmpty {
                    ReorderableMovementList(movements: $vm.draft.warmUpMovements)
                        .padding(.horizontal, 24)
                }

                MovementAddFormView(
                    defaultGoalType: nil,
                    movements: $vm.draft.warmUpMovements
                )
                .padding(.horizontal, 24)

                PlanSectionPlaylistPicker(
                    title: "Warm-up playlist",
                    selectedPlaylistId: $vm.draft.warmUpPlaylistId
                )
            }

            Divider().padding(.horizontal, 24)
        }
    }

    // MARK: - Main Sections

    private var mainSectionsBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            let totalMainMovements = vm.draft.mainSections.reduce(0) { $0 + $1.movements.count }
            collapsibleHeader(
                title: "MAIN",
                section: .main,
                movementCount: totalMainMovements,
                durationBinding: .constant(vm.totalMainMinutes)
            )

            if expandedSections.contains(.main) {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach($vm.draft.mainSections) { $section in
                        PlanFormMainSubSection(
                            section: $section,
                            defaultGoalType: nil,
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

            Divider().padding(.horizontal, 24)
        }
    }

    // MARK: - Cool-Down

    private var coolDownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            collapsibleHeader(
                title: "COOL-DOWN",
                section: .coolDown,
                movementCount: vm.draft.coolDownMovements.count,
                durationBinding: $vm.draft.coolDownDurationMinutes
            )

            if expandedSections.contains(.coolDown) {
                if !vm.draft.coolDownMovements.isEmpty {
                    ReorderableMovementList(movements: $vm.draft.coolDownMovements)
                        .padding(.horizontal, 24)
                }

                MovementAddFormView(
                    defaultGoalType: nil,
                    movements: $vm.draft.coolDownMovements
                )
                .padding(.horizontal, 24)

                PlanSectionPlaylistPicker(
                    title: "Cool-down playlist",
                    selectedPlaylistId: $vm.draft.coolDownPlaylistId
                )
            }
        }
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            onSaveCallback(vm.toWorkoutPlanDraft())
            dismiss()
        } label: {
            Text(saveButtonTitle)
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

                Text(discardTitle)
                    .font(.system(size: 18, weight: .bold))

                Text(discardBody)
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
                        Text(discardButtonLabel)
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

// MARK: - Main Sub-Section

private struct PlanFormMainSubSection: View {
    @Binding var section: WorkoutSubSection
    let defaultGoalType: GoalType?
    let canDelete: Bool
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                TextField("Section name", text: $section.name)
                    .font(.system(size: 15))
                    .padding(.bottom, 4)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(Color(UIColor.systemGray3))
                            .frame(height: 1)
                    }

                Spacer()

                EditableDurationBadge(minutes: $section.durationMinutes)

                if canDelete {
                    Button(action: onDelete) {
                        Image(systemName: "minus.circle")
                            .font(.system(size: 18))
                            .foregroundStyle(Color(UIColor.systemGray3))
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
