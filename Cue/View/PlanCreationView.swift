//
//  PlanCreationView.swift
//  Cue
//

import SwiftUI

struct PlanCreationView: View {
    @StateObject private var vm = PlanCreationViewModel()
    let onSave: (WorkoutPlanDraft) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header
            progressBar

            // Step content — each step's view will slot in here
            stepContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            continueButton
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
        }
        .background(Color.white.ignoresSafeArea())
        .environmentObject(vm)
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            HStack {
                if vm.isOnFirstStep {
                    Button("Cancel") { dismiss() }
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                } else {
                    Button {
                        vm.back()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.black)
                    }
                }
                Spacer()
            }

            Text(vm.step.title)
                .font(.system(size: 17, weight: .semibold))
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(height: 3)
                Rectangle()
                    .fill(Color.black)
                    .frame(width: geo.size.width * progress, height: 3)
                    .animation(.easeInOut(duration: 0.25), value: progress)
            }
        }
        .frame(height: 3)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        switch vm.step {
        case .name:
            PlanNameStepView()
        case .type:
            PlanTypeStepView()
        case .duration:
            PlanDurationStepView()
        case .warmUpIntro:
            PlanSectionIntroStepView(
                headline: "Let's warm up.",
                subtext: "Suggested ~5 min · Add the movements you use to prepare your class.",
                bullets: [
                    "Dynamic stretches, mobility work, or light cardio",
                    "Movements that raise heart rate gradually",
                    "Prep for the main workout ahead"
                ]
            )
        case .warmUpMovements:
            MovementListStepView(
                headline: "Warm-Up Movements",
                defaultGoalType: vm.draft.goalType,
                durationMinutes: $vm.draft.warmUpDurationMinutes,
                movements: $vm.draft.warmUpMovements
            )
        case .mainSections:
            PlanMainSectionsStepView()
        case .mainMovements:
            PlanMainMovementsStepView()
        case .coolDownIntro:
            PlanSectionIntroStepView(
                headline: "Wind it down.",
                subtext: "Suggested ~5 min · Add the movements you use to close out your class.",
                bullets: [
                    "Static stretches and breathing exercises",
                    "Movements that lower heart rate",
                    "Help your class recover and reflect"
                ]
            )
        case .coolDownMovements:
            MovementListStepView(
                headline: "Cool-Down Movements",
                defaultGoalType: vm.draft.goalType,
                durationMinutes: $vm.draft.coolDownDurationMinutes,
                movements: $vm.draft.coolDownMovements
            )
        case .review:
            PlanReviewStepView()
        }
    }

    // MARK: - Continue / Save Button

    private var continueButton: some View {
        Button {
            if vm.isOnLastStep {
                onSave(vm.toWorkoutPlanDraft())
                dismiss()
            } else {
                vm.advance()
            }
        } label: {
            Text(vm.isOnLastStep ? "Save Plan" : "Continue")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(vm.canAdvance ? Color.black : Color(.systemGray4))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(!vm.canAdvance)
    }

    // MARK: - Helpers

    private var progress: Double {
        Double(vm.step.rawValue + 1) / Double(PlanCreationStep.total)
    }
}

#Preview {
    PlanCreationView { _ in }
}
