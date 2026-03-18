//
//  PlanReviewStepView.swift
//  Cue
//

import SwiftUI

struct PlanReviewStepView: View {
    @EnvironmentObject var vm: PlanCreationViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Looking good.")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.black)
                    Text("Review your plan before saving.")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }

                // Name, type, difficulty, duration chips
                VStack(alignment: .leading, spacing: 12) {
                    ReviewSectionHeader(title: "OVERVIEW")

                    Text(vm.draft.name.isEmpty ? "Unnamed Plan" : vm.draft.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.black)

                    HStack(spacing: 8) {
                        if let type = vm.draft.type {
                            ReviewChip(label: type.displayName)
                        }
                        if let difficulty = vm.draft.difficulty {
                            ReviewChip(label: difficulty.rawValue.capitalized)
                        }
                        ReviewChip(label: "\(vm.draft.durationMinutes) min")
                    }
                }

                Divider()

                // Warm-up
                if !vm.draft.warmUpMovements.isEmpty {
                    ReviewMovementSection(
                        title: "WARM-UP",
                        movements: vm.draft.warmUpMovements
                    )
                    Divider()
                }

                // Main sections
                if !vm.draft.mainSections.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        ReviewSectionHeader(title: "MAIN WORKOUT")
                        ForEach(vm.draft.mainSections) { section in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(section.name.isEmpty ? "Unnamed Section" : section.name)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                ForEach(section.movements) { movement in
                                    ReviewMovementItem(movement: movement)
                                }
                            }
                        }
                    }
                    Divider()
                }

                // Cool-down
                if !vm.draft.coolDownMovements.isEmpty {
                    ReviewMovementSection(
                        title: "COOL-DOWN",
                        movements: vm.draft.coolDownMovements
                    )
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 4)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Sub-components

private struct ReviewSectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .kerning(1.2)
    }
}

private struct ReviewChip: View {
    let label: String
    var body: some View {
        Text(label)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.black)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .overlay(Capsule().stroke(Color.black, lineWidth: 1))
    }
}

private struct ReviewMovementSection: View {
    let title: String
    let movements: [Movement]
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ReviewSectionHeader(title: title)
            ForEach(movements) { movement in
                ReviewMovementItem(movement: movement)
            }
        }
    }
}

private struct ReviewMovementItem: View {
    let movement: Movement
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(Color(.systemGray3))
                .frame(width: 5, height: 5)
                .padding(.top, 7)
            VStack(alignment: .leading, spacing: 2) {
                Text(movement.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.black)
                HStack(spacing: 4) {
                    if let reps = movement.reps {
                        Text("\(reps) reps")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    } else if let secs = movement.seconds {
                        Text("\(secs)s")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    if let notes = movement.notes, !notes.isEmpty {
                        Text("·")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Text(notes)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
    }
}
