//
//  PlanTypeStepView.swift
//  Cue
//

import SwiftUI

struct PlanTypeStepView: View {
    @EnvironmentObject var vm: PlanCreationViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            Text("What kind of\nclass is this?")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.black)
                .padding(.horizontal, 24)

            VStack(alignment: .leading, spacing: 10) {
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
                            ) {
                                vm.draft.type = type
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 2)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
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
                            ) {
                                vm.draft.difficulty = difficulty
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 2)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Text("FORMAT")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .kerning(1.2)
                    Text("· Optional")
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
                            if vm.draft.goalType == goalType {
                                vm.draft.goalType = nil
                            } else {
                                vm.draft.goalType = goalType
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)

                Text("Skip this if movements vary — you can set timed or reps individually on each move.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct PlanPillButton: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isSelected ? .white : .black)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(isSelected ? Color.black : Color.clear)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.black, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
