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
        ZStack {
            Color.white.ignoresSafeArea()

            VStack {
                Spacer()

                // Card
                VStack(spacing: 14) {

                    // CUE wordmark
                    Text("CUE")
                        .font(.system(size: 96, weight: .black))
                        .foregroundStyle(.black)
                        .padding(.bottom, 10)

                    // Email field
                    TextField("e-mail address", text: $authVM.email)
                        .font(.system(size: 12, weight: .thin))
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 9)
                        .padding(.vertical, 7)
                        .overlay(Rectangle().stroke(Color.black, lineWidth: 1))

                    // Password field
                    SecureField("password", text: $authVM.password)
                        .font(.system(size: 12, weight: .thin))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 7)
                        .overlay(Rectangle().stroke(Color.black, lineWidth: 1))

                    // Sign In button
                    Button {
                        authVM.signIn()
                    } label: {
                        Text("Sign In")
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 10)
                            .background(Color.black)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(authVM.isLoading)

                    // Create account link
                    Button {
                        authVM.signUp()
                    } label: {
                        Text("Create an Account")
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundStyle(.black)
                    }
                    .disabled(authVM.isLoading)

                    if let status = authVM.statusMessage {
                        Text(status)
                            .font(.system(size: 11))
                            .foregroundStyle(.green)
                            .multilineTextAlignment(.center)
                    }

                    if let error = authVM.errorMessage {
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 31)
                .padding(.vertical, 28)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.black, lineWidth: 1)
                )
                .padding(.horizontal, 32)

                Spacer()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    AuthView()
        .environmentObject(AuthViewModel())
}
