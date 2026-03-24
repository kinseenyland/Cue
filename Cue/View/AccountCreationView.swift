//
//  AccountCreationView.swift
//  Cue
//

import SwiftUI

struct AccountCreationView: View {
    @StateObject private var vm = AccountCreationViewModel()
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject private var spotifyManager: SpotifyManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header
            progressBar

            stepContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if let error = authVM.errorMessage {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
            }

            continueButton
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
        }
        .background(Color.white.ignoresSafeArea())
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            HStack {
                if vm.isOnFirstStep {
                    Button("Cancel") { dismiss() }
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                } else {
                    Button {
                        vm.back()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.black)
                    }
                }
                Spacer()
            }

            Text(vm.step.title)
                .font(.system(size: 17, weight: .semibold))
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(height: 3)
                Rectangle()
                    .fill(Color.black)
                    .frame(width: geo.size.width * progress, height: 3)
                    .animation(.easeInOut(duration: 0.25), value: progress)
            }
        }
        .frame(height: 3)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        switch vm.step {
        case .name:
            AccountNameStepView(displayName: $vm.displayName)
        case .email:
            AccountEmailStepView(email: $vm.email, displayName: vm.displayName)
        case .password:
            AccountPasswordStepView(password: $vm.password, confirmPassword: $vm.confirmPassword)
        case .classTypes:
            AccountClassTypesStepView(selectedClassTypes: $vm.preferredClassTypes)
        case .workoutStructure:
            AccountWorkoutStructureStepView(structurePreference: $vm.workoutStructurePreference)
        case .musicApproach:
            AccountMusicApproachStepView(musicApproach: $vm.musicApproach)
        case .spotify:
            AccountSpotifyStepView()
                .environmentObject(spotifyManager)
        }
    }

    // MARK: - Continue / Create Button

    private var continueButton: some View {
        Button {
            if vm.isOnLastStep {
                vm.submit(authVM: authVM)
            } else {
                vm.advance()
            }
        } label: {
            Group {
                if authVM.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(vm.isOnLastStep ? "Create Account" : "Continue")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(vm.canAdvance && !authVM.isLoading ? Color.black : Color(.systemGray4))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(!vm.canAdvance || authVM.isLoading)
    }

    // MARK: - Helpers

    private var progress: Double {
        Double(vm.step.rawValue + 1) / Double(AccountCreationStep.total)
    }
}

// MARK: - Step Views

private struct AccountNameStepView: View {
    @Binding var displayName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Welcome to Cue.")
                    .font(.system(size: 26, weight: .semibold))
                Text("We're excited to have you here.")
                    .font(.system(size: 14, weight: .thin))
                    .foregroundStyle(.secondary)
                Text("Cue helps you build smarter workouts and pair the perfect music to every movement — so you can focus on teaching, not planning.")
                    .font(.system(size: 13, weight: .thin))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("What should we call you?")
                    .font(.system(size: 15, weight: .medium))
                Text("Just your first name is okay!")
                    .font(.system(size: 12, weight: .thin))
                    .foregroundStyle(.secondary)
                TextField("Your name", text: $displayName)
                    .font(.system(size: 14, weight: .thin))
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 9)
                    .padding(.vertical, 10)
                    .overlay(Rectangle().stroke(Color.black, lineWidth: 1))
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        Spacer()
    }
}

private struct AccountEmailStepView: View {
    @Binding var email: String
    let displayName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Nice to meet you, \(displayName)!")
                    .font(.system(size: 26, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("What's your email address?")
                    .font(.system(size: 15, weight: .medium))
                TextField("e-mail address", text: $email)
                    .font(.system(size: 14, weight: .thin))
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 9)
                    .padding(.vertical, 10)
                    .overlay(Rectangle().stroke(Color.black, lineWidth: 1))
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        Spacer()
    }
}

private struct AccountPasswordStepView: View {
    @Binding var password: String
    @Binding var confirmPassword: String

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Almost there.")
                    .font(.system(size: 26, weight: .semibold))
                Text("Create a password to secure your account.")
                    .font(.system(size: 14, weight: .thin))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                SecureField("password", text: $password)
                    .font(.system(size: 14, weight: .thin))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 10)
                    .overlay(Rectangle().stroke(Color.black, lineWidth: 1))

                SecureField("confirm password", text: $confirmPassword)
                    .font(.system(size: 14, weight: .thin))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 10)
                    .overlay(Rectangle().stroke(Color.black, lineWidth: 1))

                if !confirmPassword.isEmpty && password != confirmPassword {
                    Text("Passwords don't match.")
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                }

                Text("At least 6 characters")
                    .font(.system(size: 11, weight: .thin))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        Spacer()
    }
}

private struct AccountClassTypesStepView: View {
    @Binding var selectedClassTypes: Set<WorkoutType>

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Let's set up your profile.")
                        .font(.system(size: 26, weight: .semibold))
                    Text("What types of classes do you teach?")
                        .font(.system(size: 15, weight: .medium))
                    Text("Select all that apply.")
                        .font(.system(size: 12, weight: .thin))
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(WorkoutType.allCases, id: \.self) { type in
                        let selected = selectedClassTypes.contains(type)
                        Button {
                            if selected { selectedClassTypes.remove(type) }
                            else        { selectedClassTypes.insert(type) }
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
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 8)
        }
    }
}

private struct AccountWorkoutStructureStepView: View {
    @Binding var structurePreference: WorkoutStructurePreference?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("How do you usually build your workouts?")
                    .font(.system(size: 22, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 8) {
                    ForEach(WorkoutStructurePreference.allCases, id: \.self) { option in
                        let selected = structurePreference == option
                        Button {
                            structurePreference = option
                        } label: {
                            HStack(spacing: 12) {
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
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 8)
        }
    }
}

private struct AccountMusicApproachStepView: View {
    @Binding var musicApproach: MusicApproach?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("How does music fit into your planning?")
                    .font(.system(size: 22, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 8) {
                    ForEach(MusicApproach.allCases, id: \.self) { option in
                        let selected = musicApproach == option
                        Button {
                            musicApproach = option
                        } label: {
                            HStack(spacing: 12) {
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
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 8)
        }
    }
}

private struct AccountSpotifyStepView: View {
    @EnvironmentObject var spotifyManager: SpotifyManager

    private var isConnected: Bool {
        spotifyManager.accessToken != nil || spotifyManager.apiAccessToken != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Last step.")
                    .font(.system(size: 26, weight: .semibold))
                Text("Connect your Spotify account to get the most out of Cue.")
                    .font(.system(size: 14, weight: .thin))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 12) {
                Button {
                    spotifyManager.connect()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: isConnected ? "checkmark.circle.fill" : "music.note")
                            .font(.system(size: 16))
                        Text(isConnected ? "Spotify Connected" : "Connect Spotify")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(isConnected ? .black : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(isConnected ? Color(.systemGray6) : Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(isConnected)

                if !isConnected {
                    Text("Skip for now")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        Spacer()
    }
}

#Preview {
    AccountCreationView()
        .environmentObject(AuthViewModel())
        .environmentObject(SpotifyManager.shared)
}
