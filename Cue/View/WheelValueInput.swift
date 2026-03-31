//
//  WheelValueInput.swift
//  Cue
//

import SwiftUI

/// A tappable numeric display that opens a wheel picker for reps or seconds input.
/// Replaces TextField + numberPad to eliminate keyboard friction.
struct WheelValueInput: View {
    @Binding var value: String
    let mode: GoalType
    @State private var showPicker = false
    @State private var pickerValue: Int = 0

    private var values: [Int] {
        switch mode {
        case .reps:
            return Array(1...50)
        case .timed:
            return Array(stride(from: 5, through: 300, by: 5))
        }
    }

    private var displayText: String {
        value.isEmpty ? "0" : value
    }

    var body: some View {
        VStack(spacing: 6) {
            Button {
                if let current = Int(value), values.contains(current) {
                    pickerValue = current
                } else {
                    pickerValue = mode == .reps ? 10 : 30
                }
                withAnimation(.easeInOut(duration: 0.2)) {
                    showPicker.toggle()
                }
            } label: {
                HStack(spacing: 3) {
                    Text(displayText)
                        .font(.system(size: 20, weight: .semibold))
                        .multilineTextAlignment(.center)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.black.opacity(0.5))
                        .rotationEffect(.degrees(showPicker ? 180 : 0))
                }
                .frame(width: 64)
                .padding(.vertical, 10)
                .overlay(Rectangle().stroke(Color.black, lineWidth: 1))
            }
            .buttonStyle(.plain)

            if showPicker {
                WheelPickerPopup(
                    selection: $pickerValue,
                    values: values,
                    label: { "\($0)" },
                    onDone: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showPicker = false
                        }
                    }
                )
                .onChange(of: pickerValue) { _, newValue in
                    value = "\(newValue)"
                }
            }
        }
        .zIndex(showPicker ? 50 : 0)
        // Large clear background catches taps outside the picker to dismiss it
        .background {
            if showPicker {
                Color.clear
                    .frame(width: 1000, height: 1000)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showPicker = false
                        }
                    }
            }
        }
    }
}
