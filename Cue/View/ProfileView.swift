//
//  ProfileView.swift
//  Cue
//

import FirebaseAuth
import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var spotifyManager: SpotifyManager
    @EnvironmentObject private var authVM: AuthViewModel
    @StateObject private var profileVM = ProfileViewModel()
    @State private var showSpotifyPopup = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            let name = authVM.user?.displayName ?? profileVM.displayName
                            if name.isEmpty {
                                Text("Account Settings")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundColor(.black)
                            } else {
                                Text(name)
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundColor(.black)
                                Text("Account Settings")
                                    .font(.system(size: 13, weight: .thin))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 8)
                    .frame(height: 50)

                    // Teaching style section — only show if profile data was loaded
                    let hasTeachingData = !profileVM.preferredClassTypes.isEmpty
                        || profileVM.workoutStructure != nil
                        || profileVM.musicApproach != nil
                    if !profileVM.isLoading && hasTeachingData {
                        teachingStyleSection
                    }

                    // Music section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Music")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 12) {
                                Image(systemName: "music.note")
                                    .font(.system(size: 24, weight: .medium))
                                    .foregroundStyle(.black)
                                Text("Spotify")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.black)
                                Spacer()
                                if spotifyManager.isConnected {
                                    Text("Connected")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.black)
                                } else {
                                    Button {
                                        showSpotifyPopup = true
                                    } label: {
                                        Text("Connect Your Account")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.white)
                                            .padding(10)
                                            .frame(height: 38)
                                            .background(.black)
                                            .cornerRadius(10)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(12)
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
                                            Button("Done") { showSpotifyPopup = false }
                                        }
                                    }
                            }
                        }
                    }

                    Spacer(minLength: 24)

                    // Sign Out
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
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.white)
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear {
            if let uid = authVM.user?.uid {
                profileVM.load(uid: uid)
            }
        }
    }

    // MARK: - Teaching Style Section

    private var teachingStyleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Teaching Style")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.black)

            VStack(alignment: .leading, spacing: 16) {
                // Class types
                if !profileVM.preferredClassTypes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Classes I Teach")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        // Wrap pills in rows of 3
                        let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(profileVM.preferredClassTypes, id: \.self) { type in
                                Text(type.rawValue.capitalized)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                    .background(Color.black)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                }

                // Workout structure
                if let structure = profileVM.workoutStructure {
                    profileRow(
                        label: "How I Build Workouts",
                        value: structure.label
                    )
                }

                // Music approach
                if let music = profileVM.musicApproach {
                    profileRow(
                        label: "Music Planning",
                        value: music.label
                    )
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .inset(by: 0.50)
                    .stroke(.black, lineWidth: 0.50)
            )
        }
    }

    private func profileRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.black)
        }
    }
}

// MARK: - Profile stats row

struct ProfileStatsRow: View {
    var classesCompleted: Int
    var topCategory: String

    var body: some View {
        HStack(spacing: 0) {
            statBlock(label: "Top Category", value: topCategory.capitalized)
            Rectangle()
                .fill(Color.black.opacity(0.15))
                .frame(width: 0.5)
                .padding(.vertical, 8)
            statBlock(label: "Classes Completed", value: "\(classesCompleted)")
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
