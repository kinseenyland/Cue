//
//  PlanNameStepView.swift
//  Cue
//

import SwiftUI

struct PlanNameStepView: View {
    @EnvironmentObject var vm: PlanCreationViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Let's build your\nnext class.")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.black)

                Text("We'll walk you through it step by step.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }

            TextField("Give it a name...", text: $vm.draft.name)
                .font(.system(size: 16))
                .autocorrectionDisabled()
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
                .overlay(Rectangle().stroke(Color.black, lineWidth: 1))
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
