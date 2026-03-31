//
//  WheelPickerPopup.swift
//  Cue
//

import SwiftUI

/// A compact wheel picker card.
/// Used for duration, reps, and seconds inputs to avoid keyboard.
struct WheelPickerPopup: View {
    @Binding var selection: Int
    let values: [Int]
    let label: (Int) -> String
    var onDone: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 4) {
            Picker("", selection: $selection) {
                ForEach(values, id: \.self) { value in
                    Text(label(value))
                        .tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 160, height: 120)

            if let onDone {
                Button {
                    onDone()
                } label: {
                    Text("Done")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 6)
                        .background(Color.black)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.bottom, 8)
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
    }
}
