//
//  PlanCreationChoiceView.swift
//  Cue
//

import SwiftUI

enum PlanCreationMode: String, Identifiable {
    case guided, quick
    var id: String { rawValue }
}

struct PlanCreationChoiceView: View {
    let onChoice: (PlanCreationMode) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("Create a Plan")
                .font(.system(size: 18, weight: .bold))
                .padding(.top, 20)

            VStack(spacing: 12) {
                choiceCard(
                    mode: .quick,
                    title: "Quick Create",
                    subtitle: "Everything on one page"
                )
                choiceCard(
                    mode: .guided,
                    title: "Guided",
                    subtitle: "Step-by-step walkthrough"
                )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .presentationDetents([.height(240)])
        .presentationDragIndicator(.visible)
    }

    private func choiceCard(mode: PlanCreationMode, title: String, subtitle: String) -> some View {
        Button {
            dismiss()
            onChoice(mode)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: mode == .quick ? "bolt.fill" : "list.bullet.clipboard")
                    .font(.system(size: 18))
                    .foregroundStyle(Color(UIColor.systemGray3))
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.black)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.black, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
