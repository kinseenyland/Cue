//
//  PlanSectionIntroStepView.swift
//  Cue
//

import SwiftUI

struct PlanSectionIntroStepView: View {
    let headline: String
    let subtext: String
    let bullets: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 8) {
                Text(headline)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.black)

                Text(subtext)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(bullets, id: \.self) { bullet in
                    HStack(alignment: .top, spacing: 12) {
                        Circle()
                            .fill(Color.black)
                            .frame(width: 6, height: 6)
                            .padding(.top, 6)
                        Text(bullet)
                            .font(.system(size: 15))
                            .foregroundStyle(.black)
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
