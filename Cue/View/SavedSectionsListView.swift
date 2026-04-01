//
//  SavedSectionsListView.swift
//  Cue
//

import FirebaseAuth
import SwiftUI

struct SavedSectionsListView: View {
    @StateObject private var vm = SavedSectionsViewModel()
    @State private var sectionToDelete: SavedSection? = nil
    @State private var showCreateSheet = false

    private var grouped: [(WorkoutSection, [SavedSection])] {
        let order: [WorkoutSection] = [.warmUp, .main, .coolDown]
        return order.compactMap { type in
            let items = vm.sections(for: type)
            return items.isEmpty ? nil : (type, items)
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
                        ForEach(grouped, id: \.0) { type, items in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(label(for: type))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .kerning(1.0)
                                    .textCase(.uppercase)

                                ForEach(items) { section in
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
                Task {
                    await vm.saveSection(section)
                }
            }
        }
        .overlay {
            if let section = sectionToDelete {
                deleteConfirmation(section)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: sectionToDelete != nil)
    }

    private func sectionRow(_ section: SavedSection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(section.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)
                Spacer()
                Text("\(section.durationMinutes) min")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 5))

                Button {
                    sectionToDelete = section
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(.systemGray3))
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 3) {
                ForEach(section.movements.prefix(4)) { m in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.black)
                            .frame(width: 4, height: 4)
                        Text(m.name)
                            .font(.system(size: 13))
                            .foregroundStyle(.primary)
                        if let reps = m.reps {
                            Text("· \(reps) reps")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        } else if let secs = m.seconds {
                            Text("· \(secs)s")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                if section.movements.count > 4 {
                    Text("+\(section.movements.count - 4) more")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 10)
                }
            }
        }
        .padding(12)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.black, lineWidth: 0.5)
        )
    }

    // MARK: - Delete Confirmation

    private func deleteConfirmation(_ section: SavedSection) -> some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { sectionToDelete = nil }

            VStack(spacing: 16) {
                HStack {
                    Spacer()
                    Button { sectionToDelete = nil } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 30, height: 30)
                            .background(Color(.systemGray5))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }

                Text("Delete \"\(section.name)\"?")
                    .font(.system(size: 18, weight: .bold))
                    .multilineTextAlignment(.center)

                Text("This saved section will be permanently removed.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                VStack(spacing: 10) {
                    Button { sectionToDelete = nil } label: {
                        Text("Keep")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)

                    Button {
                        Task { await vm.deleteSection(id: section.id) }
                        sectionToDelete = nil
                    } label: {
                        Text("Delete")
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

// MARK: - Create Section Sheet

private struct CreateSectionSheet: View {
    let onSave: (SavedSection) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var sectionType: WorkoutSection = .warmUp
    @State private var durationMinutes = 5
    @State private var movements: [Movement] = []
    @State private var isEditingDuration = false
    @State private var durationText = ""
    @FocusState private var durationFocused: Bool

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

                    // Section type picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SECTION TYPE")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .kerning(1.2)

                        HStack(spacing: 8) {
                            ForEach(WorkoutSection.allCases, id: \.self) { type in
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

                    // Name
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

                    // Duration
                    VStack(alignment: .leading, spacing: 8) {
                        Text("DURATION")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .kerning(1.2)

                        EditableDurationBadge(minutes: $durationMinutes)
                    }

                    // Movements
                    VStack(alignment: .leading, spacing: 12) {
                        Text("MOVEMENTS")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .kerning(1.2)

                        if !movements.isEmpty {
                            VStack(spacing: 0) {
                                ForEach(movements) { movement in
                                    MovementRow(movement: movement) {
                                        movements.removeAll { $0.id == movement.id }
                                    }
                                    if movement.id != movements.last?.id {
                                        Divider().padding(.leading, 16)
                                    }
                                }
                            }
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        MovementAddFormView(
                            defaultGoalType: nil,
                            movements: $movements
                        )
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
                            durationMinutes: durationMinutes,
                            movements: movements
                        )
                        onSave(section)
                        dismiss()
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(canSave ? .black : .gray)
                    .disabled(!canSave)
                }
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
        }
    }
}
