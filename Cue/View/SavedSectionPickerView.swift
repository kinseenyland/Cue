//
//  SavedSectionPickerView.swift
//  Cue
//

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
                    Text("\(section.durationMinutes) min")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
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
    let movements: [Movement]
    let durationMinutes: Int
    let defaultName: String
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String

    init(
        sectionType: WorkoutSection,
        movements: [Movement],
        durationMinutes: Int,
        defaultName: String = "",
        onSave: @escaping (String) -> Void
    ) {
        self.sectionType = sectionType
        self.movements = movements
        self.durationMinutes = durationMinutes
        self.defaultName = defaultName
        self.onSave = onSave
        _name = State(initialValue: defaultName)
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
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Save this \(sectionLabel.lowercased()) section so you can reuse it in future workouts.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)

                    TextField("Section name (e.g. My Leg Day Warmup)", text: $name)
                        .font(.system(size: 16))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .overlay(Rectangle().stroke(Color.black, lineWidth: 1))
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("\(movements.count) movement\(movements.count == 1 ? "" : "s")")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(durationMinutes) min")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.black)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(movements) { m in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color.black)
                                    .frame(width: 4, height: 4)
                                Text(m.name)
                                    .font(.system(size: 13))
                            }
                        }
                    }
                }
                .padding(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(.systemGray3), lineWidth: 0.5)
                )

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
                        onSave(name.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
