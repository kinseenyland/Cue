//
//  ProfileView.swift
//  Cue
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var spotifyManager: SpotifyManager
    @EnvironmentObject private var authVM: AuthViewModel
    @State private var showSpotifyPopup = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                HStack(spacing: 154) {
                    Button("Sign Out") {
                        authVM.signOut()
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
                .foregroundColor(.clear)
                .padding(EdgeInsets(top: 21, leading: 24, bottom: 19, trailing: 24))
                .frame(maxWidth: .infinity)

                HStack(spacing: 10) {
                    Text("Profile")
                        .font(.system(size: 24, weight: .semibold))
                        .lineSpacing(52)
                        .foregroundColor(.black)
                }
                .padding(8)
                .frame(maxWidth: .infinity)
                .frame(height: 50)

                VStack(spacing: 18) {
                    Rectangle()
                        .foregroundColor(.clear)
                        .frame(width: 100, height: 100)
                        .background(Color(red: 0.65, green: 0.65, blue: 0.65))
                        .cornerRadius(50)
                    Text("First Last")
                        .font(.system(size: 16, weight: .semibold))
                        .lineSpacing(22)
                        .foregroundColor(.black)
                }
                .padding(EdgeInsets(top: 27, leading: 116, bottom: 27, trailing: 116))
                .frame(maxWidth: .infinity)

                // Stats + My Music inside bordered rectangle below First Last
                VStack(alignment: .leading, spacing: 16) {
                    ProfileStatsRow(classesCompleted: 0, topCategory: "Pilates")}
                
                .padding(16)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 120)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .inset(by: 0.50)
                        .stroke(.black, lineWidth: 0.50)
                )
                Text("My Music")
                    .font(.system(size: 16, weight: .semibold))
                    .lineSpacing(22)
                    .foregroundColor(.black)

                // Spotify row: "Connect Your Account" button when not connected, "Connected" when connected
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        Image(systemName: "music.note")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(Color(red: 0.11, green: 0.84, blue: 0.42)) // Spotify green
                        Text("Spotify")
                            .font(.system(size: 18, weight: .semibold))
                            .lineSpacing(22)
                            .foregroundColor(.black)
                        if spotifyManager.isConnected {
                            Text("Connected")
                                .font(.system(size: 16, weight: .semibold))
                                .lineSpacing(22)
                                .foregroundColor(.black)
                        } else {
                            Button {
                                showSpotifyPopup = true
                            } label: {
                                HStack(spacing: 10) {
                                    Text("Connect Your Account")
                                        .font(.system(size: 14, weight: .semibold))
                                        .lineSpacing(22)
                                        .foregroundColor(.white)
                                }
                                .padding(10)
                                .frame(height: 38)
                                .background(.black)
                                .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                        }
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
                .sheet(isPresented: $showSpotifyPopup) {
                    NavigationStack {
                        SpotifySearchView(onTrackSelected: { _ in })
                            .environmentObject(spotifyManager)
                        .navigationTitle("Spotify")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") {
                                    showSpotifyPopup = false
                                }
                            }
                        }
                    }
                }

                Spacer()
                    .frame(height: 108)
            }
            .padding(EdgeInsets(top: 0, leading: 16, bottom: 34, trailing: 16))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.white)
            .toolbar(.hidden, for: .navigationBar)
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
