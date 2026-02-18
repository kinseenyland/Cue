//
//  AuthView.swift
//  Cue
//
//  Created by Kinsee Nyland on 2/10/26.
//

import SwiftUI

struct AuthView: View {
    @EnvironmentObject var authVM: AuthViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 12) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 80))
                        .foregroundStyle(.white)
                        .padding(24)
                        .background(Circle().fill(Color.orange))

                    Text("CUE")
                        .font(.system(size: 40, weight: .bold))

                    Text("CUE handles class logistics so fitness instructors can stay present with their students.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                Spacer()

                VStack(spacing: 16) {
                    TextField("Email", text: $authVM.email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal, 24)

                    SecureField("Password", text: $authVM.password)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal, 24)

                    Button("Sign In") {
                        authVM.signIn()
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.borderedProminent)
                    .disabled(authVM.isLoading)
                    .padding(.horizontal, 24)

                    Button("Create Account") {
                        authVM.signUp()
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.bordered)
                    .disabled(authVM.isLoading)
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 24)

                if let status = authVM.statusMessage {
                    Text(status)
                        .foregroundStyle(.green)
                        .padding(.horizontal)
                }

                if let error = authVM.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }
            }
            .navigationTitle("Account")
        }
    }
}

#Preview {
    AuthView()
        .environmentObject(AuthViewModel())
}
