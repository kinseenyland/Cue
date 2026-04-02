//
//  PlanDurationStepView.swift
//  Cue
//

import SwiftUI

struct PlanDurationStepView: View {
    @EnvironmentObject var vm: PlanCreationViewModel
    @State private var showCustomPicker = false
    @State private var customText = ""
    @FocusState private var customFieldFocused: Bool

    private let standardDurations = [45, 60, 75]

    private var isCustom: Bool {
        !standardDurations.contains(vm.draft.durationMinutes)
    }

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
                        customFieldFocused = false
                    }
                }

                // Custom card — shows a numeric text field when active
                Button {
                    if !showCustomPicker {
                        customText = isCustom ? "\(vm.draft.durationMinutes)" : ""
                        showCustomPicker = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            customFieldFocused = true
                        }
                    }
                } label: {
                    VStack(spacing: 4) {
                        if showCustomPicker {
                            TextField("90", text: $customText)
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .keyboardType(.numberPad)
                                .focused($customFieldFocused)
                                .frame(maxWidth: .infinity)
                                .onChange(of: customText) { _, val in
                                    let digits = val.filter { $0.isNumber }
                                    if digits != val { customText = digits }
                                    if let n = Int(digits), n > 0, n <= 300 {
                                        vm.draft.durationMinutes = n
                                    }
                                }
                        } else {
                            Text(isCustom ? "\(vm.draft.durationMinutes)" : "Other")
                                .font(.system(size: 32, weight: .bold))
                        }
                        Text(showCustomPicker || isCustom ? "minutes" : "custom")
                            .font(.system(size: 12))
                            .foregroundStyle(showCustomPicker ? .white.opacity(0.7) : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 90)
                    .foregroundStyle(showCustomPicker || isCustom ? .white : .black)
                    .background(showCustomPicker || isCustom ? Color.black : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.black, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .contentShape(Rectangle())
        .onTapGesture { customFieldFocused = false }
        .onAppear {
            if isCustom && vm.draft.durationMinutes > 0 {
                showCustomPicker = true
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
