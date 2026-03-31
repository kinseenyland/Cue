//
//  MovementListStepView.swift
//  Cue
//

import SwiftUI

struct MovementListStepView: View {
    let headline: String
    let defaultGoalType: GoalType?
    @Binding var durationMinutes: Int
    @Binding var movements: [Movement]

    @State private var dismissDurationPickersTrigger = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top, spacing: 12) {
                    Text(headline)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.black)
                    Spacer()
                    EditableDurationBadge(
                        minutes: $durationMinutes,
                        dismissTrigger: dismissDurationPickersTrigger
                    )
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
                    movements: $movements
                )
                    .padding(.horizontal, 24)
            }
            .padding(.top, 4)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            dismissDurationPickersTrigger.toggle()
        }
    }
}

// MARK: - Movement Row

struct MovementRow: View {
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
            Button(action: onDelete) {
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

// MARK: - Editable Duration Badge

struct EditableDurationBadge: View {
    @Binding var minutes: Int
    var dismissTrigger: Bool = false
    @State private var showPicker = false

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                showPicker.toggle()
            }
        } label: {
            HStack(spacing: 4) {
                Text("\(minutes) min")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .rotationEffect(.degrees(showPicker ? 180 : 0))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topTrailing) {
            if showPicker {
                WheelPickerPopup(
                    selection: $minutes,
                    values: Array(1...120),
                    label: { "\($0) min" },
                    onDone: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showPicker = false
                        }
                    }
                )
                .offset(x: -8, y: 34)
                .zIndex(2)
            }
        }
        .zIndex(showPicker ? 50 : 0)
        .onChange(of: dismissTrigger) { _, _ in
            if showPicker {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showPicker = false
                }
            }
        }
    }
}
