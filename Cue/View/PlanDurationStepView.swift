//
//  PlanDurationStepView.swift
//  Cue
//

import SwiftUI

struct PlanDurationStepView: View {
    @EnvironmentObject var vm: PlanCreationViewModel
    @State private var showCustomInput = false
    @State private var customText = ""

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
                        isSelected: vm.draft.durationMinutes == duration && !showCustomInput
                    ) {
                        vm.draft.durationMinutes = duration
                        showCustomInput = false
                    }
                }

                Button {
                    showCustomInput = true
                    vm.draft.durationMinutes = Int(customText) ?? 0
                } label: {
                    VStack(spacing: 4) {
                        Text("Other")
                            .font(.system(size: 32, weight: .bold))
                        Text("custom")
                            .font(.system(size: 12))
                            .foregroundStyle(showCustomInput ? .white.opacity(0.7) : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 90)
                    .foregroundStyle(showCustomInput ? .white : .black)
                    .background(showCustomInput ? Color.black : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.black, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }

            if showCustomInput {
                TextField("Enter minutes...", text: $customText)
                    .keyboardType(.numberPad)
                    .font(.system(size: 16))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 14)
                    .overlay(Rectangle().stroke(Color.black, lineWidth: 1))
                    .onChange(of: customText) { _, newValue in
                        vm.draft.durationMinutes = Int(newValue) ?? 0
                    }
            }
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            if !standardDurations.contains(vm.draft.durationMinutes) && vm.draft.durationMinutes > 0 {
                showCustomInput = true
                customText = "\(vm.draft.durationMinutes)"
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
