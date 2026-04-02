//
//  SavedSectionsListView.swift
//  Cue
//

import FirebaseAuth
import SwiftUI

struct SavedSectionsListView: View {
    @StateObject private var vm = SavedSectionsViewModel()
    @State private var deleteArmedSectionId: String? = nil
    @State private var deleteArmResetTask: Task<Void, Never>? = nil
    @State private var expandedSectionIds: Set<String> = []
    @State private var sectionToEdit: SavedSection? = nil
    @State private var showCreateSheet = false

    private struct SectionGroup: Identifiable {
        let id: String
        let type: WorkoutSection
        let items: [SavedSection]
    }

    private var grouped: [SectionGroup] {
        let order: [WorkoutSection] = [.warmUp, .main, .coolDown]
        return order.compactMap { type in
            let items = vm.sections(for: type)
            guard !items.isEmpty else { return nil }
            return SectionGroup(id: type.rawValue, type: type, items: items)
        }
    }

    private func label(for type: WorkoutSection) -> String {
        switch type {
        case .warmUp: return "Warm-Up"
        case .main: return "Main"
        case .coolDown: return "Cool-Down"
        }
    }

    var body: some View {
        Group {
            if vm.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.sections.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "tray")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("No saved sections yet.")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                    Text("Create a reusable section or save one while building a workout.")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    Button { showCreateSheet = true } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Create Section")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(grouped) { group in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(label(for: group.type))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .kerning(1.0)
                                    .textCase(.uppercase)

                                ForEach(group.items) { section in
                                    sectionRow(section)
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
        }
        .background(Color.white)
        .navigationTitle("Saved Sections")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showCreateSheet = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.black)
                }
            }
        }
        .task { await vm.fetchSections() }
        .sheet(isPresented: $showCreateSheet) {
            CreateSectionSheet { section in
                Task { await vm.saveSection(section) }
            }
        }
        .sheet(item: $sectionToEdit) { section in
            EditSavedSectionSheet(section: section) { updatedSection in
                Task {
                    await vm.saveSection(updatedSection)
                    sectionToEdit = nil
                }
            }
        }
    }

    private func sectionRow(_ section: SavedSection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 6) {
                Text(section.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)
                    .lineLimit(1)

                HStack(alignment: .center, spacing: 6) {
                    Button {
                        toggleExpanded(section.id)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.black)
                                .frame(width: 22, height: 22)
                            Text("\(section.movements.count)")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                    .buttonStyle(.plain)

                    Button {
                        toggleExpanded(section.id)
                    } label: {
                        Image(systemName: expandedSectionIds.contains(section.id) ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 22, height: 22)
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 0)

                Button {
                    sectionToEdit = section
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(.systemGray3))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)

                Button {
                    armOrDelete(section)
                } label: {
                    Image(systemName: deleteArmedSectionId == section.id ? "trash.fill" : "trash")
                        .font(.system(size: 13))
                        .foregroundStyle(deleteArmedSectionId == section.id ? Color.red : Color(.systemGray3))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
            }

            if expandedSectionIds.contains(section.id) {
                VStack(alignment: .leading, spacing: 3) {
                    let shown = min(section.movements.count, 8)
                    ForEach(section.movements.prefix(shown)) { movement in
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
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if section.movements.count > shown {
                        Text("+\(section.movements.count - shown) more")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .padding(.leading, 10)
                    }
                }
                .padding(.top, 2)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.black, lineWidth: 0.5)
        )
    }

    private func toggleExpanded(_ id: String) {
        if expandedSectionIds.contains(id) {
            expandedSectionIds.remove(id)
        } else {
            expandedSectionIds.insert(id)
        }
    }

    private func armOrDelete(_ section: SavedSection) {
        if deleteArmedSectionId == section.id {
            deleteArmedSectionId = nil
            deleteArmResetTask?.cancel()
            Task { await vm.deleteSection(id: section.id) }
            return
        }

        deleteArmResetTask?.cancel()
        deleteArmedSectionId = section.id
        deleteArmResetTask = Task {
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            await MainActor.run {
                if deleteArmedSectionId == section.id {
                    deleteArmedSectionId = nil
                }
            }
        }
    }
}

#if false
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

#endif

