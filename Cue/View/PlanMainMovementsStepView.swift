//
//  PlanMainMovementsStepView.swift
//  Cue
//

import SwiftUI

struct PlanMainMovementsStepView: View {
    @EnvironmentObject var vm: PlanCreationViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                Text("Add movements to\neach section.")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 24)

                ForEach($vm.draft.mainSections) { $section in
                    SectionMovementBlock(
                        section: $section,
                        defaultGoalType: vm.draft.goalType,
                        showGoalOption: vm.showGoalOption
                    )
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SectionMovementBlock: View {
    @Binding var section: WorkoutSubSection
    let defaultGoalType: GoalType?
    var showGoalOption: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Text(section.name.isEmpty ? "Unnamed Section" : section.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .kerning(1.0)
                    .textCase(.uppercase)
                Spacer()
                EditableDurationBadge(minutes: $section.durationMinutes)
            }
            .padding(.horizontal, 24)

            Text("MOVEMENTS")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .kerning(1.2)
                .padding(.horizontal, 24)

            if !section.movements.isEmpty {
                ReorderableMovementList(movements: $section.movements)
                    .padding(.horizontal, 24)
            }

            MovementComposerView(
                defaultGoalType: defaultGoalType,
                showGoalOption: showGoalOption,
                movements: $section.movements
            )
                .padding(.horizontal, 24)

            Divider()
                .padding(.top, 8)
        }
    }
}
