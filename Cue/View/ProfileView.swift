//
//  ProfileView.swift
//  Cue
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var spotifyManager: SpotifyManager
    @EnvironmentObject private var authVM: AuthViewModel

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Button("Sign Out") {
                        authVM.signOut()
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    Spacer()
                    Text("Profile")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.black)
                    Spacer()
                    // balance the sign out button
                    Text("Sign Out")
                        .font(.system(size: 12))
                        .foregroundStyle(.clear)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 16)

                SpotifySearchView(onTrackSelected: { _ in })
                    .environmentObject(spotifyManager)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.white)
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(SpotifyManager.shared)
        .environmentObject(AuthViewModel())
}
