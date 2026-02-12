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
            Form {
                Section("Account") {
                    TextField("Email", text: $authVM.email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)

                    SecureField("Password", text: $authVM.password)
                }

                Section {
                    Button("Sign In") {
                        authVM.signIn()
                    }
                    .disabled(authVM.isLoading)

                    Button("Create Account") {
                        authVM.signUp()
                    }
                    .disabled(authVM.isLoading)
                }

                if let status = authVM.statusMessage {
                    Text(status)
                        .foregroundStyle(.green)
                }

                if let error = authVM.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
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
