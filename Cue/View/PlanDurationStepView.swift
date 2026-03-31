//
//  PlanDurationStepView.swift
//  Cue
//

import SwiftUI

struct PlanDurationStepView: View {
    @EnvironmentObject var vm: PlanCreationViewModel
    @State private var showCustomPicker = false

    private let standardDurations = [45, 60, 75]

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Text("How long is\nthis class?")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.black)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(standardDurations, id: \.self) { duration in
                    DurationCard(
                        duration: duration,
                        isSelected: vm.draft.durationMinutes == duration && !showCustomPicker
                    ) {
                        vm.draft.durationMinutes = duration
                        showCustomPicker = false
                    }
                }

                ZStack(alignment: .topTrailing) {
                    Button {
                        if !showCustomPicker && standardDurations.contains(vm.draft.durationMinutes) {
                            vm.draft.durationMinutes = 90
                        }
                        showCustomPicker.toggle()
                    } label: {
                        VStack(spacing: 4) {
                            Text(showCustomPicker || !standardDurations.contains(vm.draft.durationMinutes)
                                 ? "\(vm.draft.durationMinutes)"
                                 : "Other")
                                .font(.system(size: 32, weight: .bold))
                            Text(showCustomPicker || !standardDurations.contains(vm.draft.durationMinutes)
                                 ? "minutes"
                                 : "custom")
                                .font(.system(size: 12))
                                .foregroundStyle(showCustomPicker ? .white.opacity(0.7) : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 90)
                        .foregroundStyle(showCustomPicker ? .white : .black)
                        .background(showCustomPicker ? Color.black : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.black, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)

                    if showCustomPicker {
                        WheelPickerPopup(
                            selection: $vm.draft.durationMinutes,
                            values: Array(1...120),
                            label: { "\($0) min" },
                            onDone: { showCustomPicker = false }
                        )
                        .offset(y: 94)
                        .zIndex(1)
                    }
                }
                .zIndex(showCustomPicker ? 50 : 0)
            }
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            if !standardDurations.contains(vm.draft.durationMinutes) && vm.draft.durationMinutes > 0 {
                showCustomPicker = true
            }
        }
    }
}

struct DurationCard: View {
    let duration: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text("\(duration)")
                    .font(.system(size: 32, weight: .bold))
                Text("minutes")
                    .font(.system(size: 12))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 90)
            .foregroundStyle(isSelected ? .white : .black)
            .background(isSelected ? Color.black : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.black, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
