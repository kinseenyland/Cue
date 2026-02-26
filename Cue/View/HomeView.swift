//
//  HomeView.swift
//  Cue
//

import SwiftUI

struct HomeView: View {
    @Binding var selectedTab: MainTab

    var body: some View {
        VStack(spacing: 0) {
            Text("CUE")
                .font(.system(size: 48, weight: .black))
                .frame(maxWidth: .infinity)
                .padding(.top, 24)
                .padding(.bottom, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Welcome!")
                        .font(.system(size: 24, weight: .bold))
                        .padding(.horizontal, 16)
                }
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.white)
    }
}

#Preview {
    HomeView(selectedTab: .constant(.home))
}
