//
//  ProfileView.swift
//  Cue
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var spotifyManager: SpotifyManager
    @EnvironmentObject private var authVM: AuthViewModel
    @State private var isShowingSpotifyPage = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    Text("Account Settings")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.black)
                }
                .padding(8)
                .frame(maxWidth: .infinity)
                .frame(height: 50)

                // Music section
                Text("Music")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Spotify row: "Connect Your Account" button when not connected, "Connected" when connected
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        Image(systemName: "music.note")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(.black)
                        Text("Spotify")
                            .font(.system(size: 18, weight: .semibold))
                            .lineSpacing(22)
                            .foregroundColor(.black)
                        
                        Spacer()

                        Button {
                            // Connect to Spotify without triggering playback, then open playlist manager.
                            _ = spotifyManager.connect()
                            isShowingSpotifyPage = true
                        } label: {
                            HStack(spacing: 10) {
                                Text("Manage Playlists")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .padding(10)
                            .frame(height: 38)
                            .background(.black)
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 72)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .inset(by: 0.50)
                        .stroke(.black, lineWidth: 0.50)
                )
                // Previously this was a modal sheet; now we navigate directly to the Spotify page.

                Spacer()

                // Sign Out button at bottom
                Button {
                    authVM.signOut()
                } label: {
                    HStack {
                        Spacer()
                        Text("Sign Out")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black)
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.black, lineWidth: 0.5)
                    )
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
            .padding(EdgeInsets(top: 0, leading: 16, bottom: 60, trailing: 16))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.white)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $isShowingSpotifyPage) {
                SpotifySearchView(onTrackSelected: { _ in })
                    .environmentObject(spotifyManager)
            }
        }
    }
}

// MARK: - Profile stats row

struct ProfileStatsRow: View {
    var classesCompleted: Int
    var topCategory: String

    var body: some View {
        HStack(spacing: 0) {
            statBlock(
                label: "Top Category",
                value: topCategory.capitalized
            )
            Rectangle()
                .fill(Color.black.opacity(0.15))
                .frame(width: 0.5)
                .padding(.vertical, 8)
            statBlock(
                label: "Classes Completed",
                value: "\(classesCompleted)"
            )
        }
        .padding(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .inset(by: 0.50)
                .stroke(.black, lineWidth: 0.50)
        )
    }

    private func statBlock(label: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.black)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ProfileView()
        .environmentObject(SpotifyManager.shared)
        .environmentObject(AuthViewModel())
}
