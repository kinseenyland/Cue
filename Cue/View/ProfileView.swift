//
//  ProfileView.swift
//  Cue
//

import FirebaseAuth
import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var spotifyManager: SpotifyManager
    @EnvironmentObject private var authVM: AuthViewModel
    @State private var isShowingSpotifyPage = false
    @StateObject private var profileVM = ProfileViewModel()
    @State private var showEditSheet = false

    private var displayName: String {
        profileVM.displayName.isEmpty ? (authVM.user?.displayName ?? "") : profileVM.displayName
    }

    private var email: String { authVM.user?.email ?? "" }

    private var initials: String {
        String(displayName.prefix(1)).uppercased()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // MARK: Page Title
                    HStack {
                        Text("Profile")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.black)
                        Spacer()
                    }
                    .padding(.top, 8)

                    // MARK: Profile Header
                    Text("My Info")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.black)
                                .frame(width: 48, height: 48)
                            Text(initials.isEmpty ? "?" : initials)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(displayName.isEmpty ? "Your Name" : displayName)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.black)
                            if !email.isEmpty {
                                Text(email)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button {
                            authVM.signOut()
                        } label: {
                            Text("Sign Out")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.black)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.black, lineWidth: 0.5)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.black, lineWidth: 0.5)
                    )

                    // MARK: Teaching Preferences
                    if !profileVM.isLoading {
                        preferencesSection
                    }

                    // MARK: Music
                    musicSection

                }
                .padding(EdgeInsets(top: 0, leading: 16, bottom: 60, trailing: 16))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.white)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $isShowingSpotifyPage) {
                SpotifySearchView(onTrackSelected: { _ in })
                    .environmentObject(spotifyManager)
            }
        }
        .onAppear {
            if let uid = authVM.user?.uid {
                profileVM.load(uid: uid)
            }
        }
        .sheet(isPresented: $showEditSheet) {
            EditProfileSheet(
                profileVM: profileVM,
                uid: authVM.user?.uid ?? "",
                currentName: displayName
            )
        }
    }

    // MARK: - Preferences Section

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Teaching Preferences")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                Spacer()
                Button {
                    showEditSheet = true
                } label: {
                    Text("Edit")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.black)
                        .underline()
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 16) {
                // Classes
                VStack(alignment: .leading, spacing: 8) {
                    Text("Classes I Teach")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    if profileVM.preferredClassTypes.isEmpty {
                        Text("Not set")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    } else {
                        LazyVGrid(
                            columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                            spacing: 8
                        ) {
                            ForEach(profileVM.preferredClassTypes, id: \.self) { type in
                                Text(type.displayName)
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

                profileDataRow(label: "How I Build Workouts", value: profileVM.workoutStructure?.label)
                profileDataRow(label: "Music Planning", value: profileVM.musicApproach?.label)
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

    private func profileDataRow(label: String, value: String?) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value ?? "Not set")
                .font(.system(size: 13, weight: value == nil ? .regular : .semibold))
                .foregroundColor(value == nil ? .secondary : .black)
        }
    }

    // MARK: - Music Section

    private var musicSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Music")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                Image(systemName: "music.note")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.black)
                Text("Spotify")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.black)
                Spacer()
                Button {
                    _ = spotifyManager.connect()
                    isShowingSpotifyPage = true
                } label: {
                    Text("Manage Playlists")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(10)
                        .frame(height: 38)
                        .background(.black)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 72)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .inset(by: 0.50)
                    .stroke(.black, lineWidth: 0.50)
            )
        }
    }
}

// MARK: - Edit Profile Sheet

private struct EditProfileSheet: View {
    @ObservedObject var profileVM: ProfileViewModel
    let uid: String
    let currentName: String

    @Environment(\.dismiss) private var dismiss
    @State private var selectedClassTypes: Set<WorkoutType>
    @State private var structurePreference: WorkoutStructurePreference?
    @State private var musicApproach: MusicApproach?

    init(profileVM: ProfileViewModel, uid: String, currentName: String) {
        self.profileVM = profileVM
        self.uid = uid
        self.currentName = currentName
        _selectedClassTypes = State(initialValue: Set(profileVM.preferredClassTypes))
        _structurePreference = State(initialValue: profileVM.workoutStructure)
        _musicApproach = State(initialValue: profileVM.musicApproach)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {

                    // Class types
                    VStack(alignment: .leading, spacing: 12) {
                        Text("What types of classes do you teach?")
                            .font(.system(size: 15, weight: .medium))
                        Text("Select all that apply.")
                            .font(.system(size: 12, weight: .thin))
                            .foregroundStyle(.secondary)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(WorkoutType.allCases, id: \.self) { type in
                                let selected = selectedClassTypes.contains(type)
                                Button {
                                    if selected { selectedClassTypes.remove(type) }
                                    else { selectedClassTypes.insert(type) }
                                } label: {
                                    Text(type.displayName)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(selected ? .white : .black)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(selected ? Color.black : Color.white)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.black, lineWidth: 1)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Divider()

                    // Workout structure
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How do you usually build your workouts?")
                            .font(.system(size: 15, weight: .medium))
                        VStack(spacing: 8) {
                            ForEach(WorkoutStructurePreference.allCases, id: \.self) { option in
                                let selected = structurePreference == option
                                Button {
                                    structurePreference = option
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(option.label)
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundStyle(selected ? .white : .black)
                                            Text(option.description)
                                                .font(.system(size: 11, weight: .thin))
                                                .foregroundStyle(selected ? .white.opacity(0.8) : .secondary)
                                        }
                                        Spacer()
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(selected ? Color.black : Color.white)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.black, lineWidth: 1)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Divider()

                    // Music approach
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How does music fit into your planning?")
                            .font(.system(size: 15, weight: .medium))
                        VStack(spacing: 8) {
                            ForEach(MusicApproach.allCases, id: \.self) { option in
                                let selected = musicApproach == option
                                Button {
                                    musicApproach = option
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(option.label)
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundStyle(selected ? .white : .black)
                                            Text(option.description)
                                                .font(.system(size: 11, weight: .thin))
                                                .foregroundStyle(selected ? .white.opacity(0.8) : .secondary)
                                        }
                                        Spacer()
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(selected ? Color.black : Color.white)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.black, lineWidth: 1)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(24)
            }
            .background(.white)
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.black)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let ordered = WorkoutType.allCases.filter { selectedClassTypes.contains($0) }
                        profileVM.save(
                            uid: uid,
                            name: currentName,
                            preferredClassTypes: ordered,
                            workoutStructure: structurePreference,
                            musicApproach: musicApproach
                        )
                        dismiss()
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black)
                }
            }
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(SpotifyManager.shared)
        .environmentObject(AuthViewModel())
}
