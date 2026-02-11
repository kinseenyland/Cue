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
                Section("Sign In") {
                    TextField("Email", text: $authVM.email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)

                    Button("Send Sign-In Link") {
                        authVM.sendSignInLink()
                    }
                    .disabled(authVM.isSendingLink)
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
