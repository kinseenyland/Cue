//
//  MovementListStepView.swift
//  Cue
//

import SwiftUI

struct MovementListStepView: View {
    let headline: String
    let defaultGoalType: GoalType?
    var showGoalOption: Bool = true
    let durationMinutes: Int
    @Binding var movements: [Movement]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top, spacing: 12) {
                    Text(headline)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.black)
                    Spacer()
                    Text("~\(durationMinutes) min")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .padding(.top, 8)
                }
                .padding(.horizontal, 24)

                Text("MOVEMENTS")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .kerning(1.2)
                    .padding(.horizontal, 24)

                if !movements.isEmpty {
                    ReorderableMovementList(movements: $movements)
                        .padding(.horizontal, 24)
                }

                MovementComposerView(
                    defaultGoalType: defaultGoalType,
                    showGoalOption: showGoalOption,
                    movements: $movements
                )
                    .padding(.horizontal, 24)
            }
            .padding(.top, 4)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Movement Row

struct MovementRow: View {
    let movement: Movement
    let isConfirmingDelete: Bool
    let onDeleteTap: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // Metric column: number above unit, centered vertically
            if let reps = movement.reps {
                VStack(spacing: 1) {
                    Text("\(reps)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.black)
                    Text("reps")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 38, alignment: .center)
            } else if let secs = movement.seconds {
                VStack(spacing: 1) {
                    Text("\(secs)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.black)
                    Text("sec")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 38, alignment: .center)
            } else {
                Image(systemName: "infinity")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(.systemGray3))
                    .frame(width: 38, alignment: .center)
            }

            // Divider
            Rectangle()
                .fill(Color(.systemGray4))
                .frame(width: 1)
                .frame(maxHeight: .infinity)
                .padding(.vertical, 6)

            // Name + notes
            VStack(alignment: .leading, spacing: 3) {
                Text(movement.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.black)
                if let note = movement.notes, !note.isEmpty {
                    Text(note)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .italic()
                }
            }

            Spacer()

            Button(action: onDeleteTap) {
                Image(systemName: isConfirmingDelete ? "trash.fill" : "trash")
                    .font(.system(size: 13))
                    .foregroundStyle(isConfirmingDelete ? .red : Color(.systemGray3))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

