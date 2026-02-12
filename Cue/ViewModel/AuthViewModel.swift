//
//  AuthViewModel.swift
//  Cue
//
//  Created by Kinsee Nyland on 2/10/26.
//

import Combine
import FirebaseAuth
import Foundation
import SwiftUI

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var user: User? = nil
    @Published var email = ""
    @Published var password = ""
    @Published var statusMessage: String? = nil
    @Published var errorMessage: String? = nil
    @Published var isLoading = false

    private var handle: AuthStateDidChangeListenerHandle?

    init() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.user = user
        }
    }

    deinit {
        if let handle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    func signIn() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else {
            errorMessage = "Enter your email."
            return
        }
        guard !password.isEmpty else {
            errorMessage = "Enter your password."
            return
        }

        isLoading = true
        statusMessage = nil
        errorMessage = nil

        Auth.auth().signIn(withEmail: trimmedEmail, password: password) { [weak self] _, error in
            guard let self else { return }
            self.isLoading = false
            if let error {
                self.errorMessage = "Sign in failed: \(error.localizedDescription)"
            } else {
                self.statusMessage = "Signed in."
            }
        }
    }

    func signUp() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else {
            errorMessage = "Enter your email."
            return
        }
        guard !password.isEmpty else {
            errorMessage = "Enter a password."
            return
        }
        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters."
            return
        }

        isLoading = true
        statusMessage = nil
        errorMessage = nil

        Auth.auth().createUser(withEmail: trimmedEmail, password: password) { [weak self] _, error in
            guard let self else { return }
            self.isLoading = false
            if let error {
                self.errorMessage = "Sign up failed: \(error.localizedDescription)"
            } else {
                self.statusMessage = "Account created. Signed in."
            }
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
        } catch {
            errorMessage = "Sign out failed: \(error.localizedDescription)"
        }
    }
}
