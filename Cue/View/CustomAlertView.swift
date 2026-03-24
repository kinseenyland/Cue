//
//  CustomAlertView.swift
//  Cue
//

import SwiftUI

struct CustomAlertView: View {
    let title: String
    var message: String? = nil
    let primaryLabel: String
    let primaryAction: () -> Void
    var primaryStyle: CustomAlertButtonStyle = .gray
    var secondaryLabel: String? = nil
    var secondaryAction: (() -> Void)? = nil
    var secondaryStyle: CustomAlertButtonStyle = .destructive
    let onDismiss: () -> Void

    enum CustomAlertButtonStyle {
        case gray, destructive, black
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 16) {
                HStack {
                    Spacer()
                    Button { onDismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 30, height: 30)
                            .background(Color(.systemGray5))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }

                Text(title)
                    .font(.system(size: 18, weight: .bold))

                if let message {
                    Text(message)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 10) {
                    alertButton(label: primaryLabel, style: primaryStyle, action: primaryAction)

                    if let secondaryLabel, let secondaryAction {
                        alertButton(label: secondaryLabel, style: secondaryStyle, action: secondaryAction)
                    }
                }
            }
            .padding(20)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
            .padding(.horizontal, 40)
        }
    }

    private func alertButton(label: String, style: CustomAlertButtonStyle, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(style == .gray ? .black : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(buttonColor(for: style))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func buttonColor(for style: CustomAlertButtonStyle) -> Color {
        switch style {
        case .gray: return Color(.systemGray6)
        case .destructive: return Color.red
        case .black: return Color.black
        }
    }
}
