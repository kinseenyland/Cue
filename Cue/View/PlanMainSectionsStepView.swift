//
//  PlanMainSectionsStepView.swift
//  Cue
//

import SwiftUI

struct PlanMainSectionsStepView: View {
    @EnvironmentObject var vm: PlanCreationViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("How is your main\nworkout structured?")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.black)

                    Text("Suggested ~\(vm.suggestedMainMinutes) min · Name each section — e.g. \"Circuit 1\", \"Strength Block\".")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 10) {
                    ForEach($vm.draft.mainSections) { $section in
                        HStack(spacing: 10) {
                            TextField("Section name", text: $section.name)
                                .font(.system(size: 16))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 13)
                                .overlay(Rectangle().stroke(Color.black, lineWidth: 1))

                            if vm.draft.mainSections.count > 1 {
                                Button {
                                    vm.draft.mainSections.removeAll { $0.id == section.id }
                                    redistributeSectionTimes()
                                } label: {
                                    Image(systemName: "minus.circle")
                                        .font(.system(size: 20))
                                        .foregroundStyle(Color(.systemGray3))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Button {
                    vm.draft.mainSections.append(WorkoutSubSection())
                    redistributeSectionTimes()
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
            }
            .padding(.horizontal, 24)
            .padding(.top, 4)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            redistributeSectionTimes()
        }
    }

    private func redistributeSectionTimes() {
        let count = vm.draft.mainSections.count
        guard count > 0 else { return }
        let perSection = max(1, vm.suggestedMainMinutes / count)
        for i in vm.draft.mainSections.indices {
            vm.draft.mainSections[i].durationMinutes = perSection
        }
    }
}
