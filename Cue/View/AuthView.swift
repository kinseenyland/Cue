//
//  AuthView.swift
//  Cue
//
//  Created by Kinsee Nyland on 2/10/26.
//

import SwiftUI

struct AuthView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @FocusState private var focusedField: Field?

    private enum Field { case email, password }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.black)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 40)

                    // Card
                    VStack(spacing: 14) {

                        // CUE wordmark
                        Text("CUE")
                            .font(.system(size: 96, weight: .regular))
                            .lineSpacing(22)
                            .foregroundStyle(.black)
                            .padding(.bottom, 4)


                        // Email field
                        TextField("e-mail address", text: $email)
                            .font(.system(size: 12, weight: .thin))
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .email)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .password }
                            .padding(.horizontal, 9)
                            .frame(height: 44)
                            .overlay(Rectangle().stroke(Color.black, lineWidth: 0.5))

                        // Password field
                        SecureField("password", text: $password)
                            .font(.system(size: 12, weight: .thin))
                            .focused($focusedField, equals: .password)
                            .submitLabel(.done)
                            .onSubmit { focusedField = nil }
                            .padding(.horizontal, 9)
                            .frame(height: 44)
                            .overlay(Rectangle().stroke(Color.black, lineWidth: 0.5))

                        // Sign In button
                        Button {
                            authVM.signIn(email: email, password: password)
                        } label: {
                            Text("Sign In")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                                .frame(height: 38)
                                .background(Color.black)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
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
                    .background(Color(red: 1, green: 1, blue: 1).opacity(0.50))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .inset(by: 0.25)
                            .stroke(Color.black, lineWidth: 0.5)
                    )
                    .cornerRadius(10)
                    .padding(.horizontal, 32)

                    Spacer(minLength: 40)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                focusedField = .email
            }
        }
    }
}

#Preview {
    AuthView()
        .environmentObject(AuthViewModel())
}
