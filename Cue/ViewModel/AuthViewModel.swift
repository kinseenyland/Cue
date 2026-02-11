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
    @Published var statusMessage: String? = nil
    @Published var errorMessage: String? = nil
    @Published var isSendingLink = false
    @Published var isSigningIn = false

    private var handle: AuthStateDidChangeListenerHandle?

    private let pendingEmailKey = "cue.pendingEmail"
    private let signInLinkURL = "https://cue-1-70e22.firebaseapp.com/login"

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

    func sendSignInLink() {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Enter a valid email."
            return
        }

        isSendingLink = true
        statusMessage = nil
        errorMessage = nil

        let settings = ActionCodeSettings()
        settings.url = URL(string: signInLinkURL)
        settings.handleCodeInApp = true
        settings.setIOSBundleID(Bundle.main.bundleIdentifier ?? "")

        Auth.auth().sendSignInLink(toEmail: trimmed, actionCodeSettings: settings) { [weak self] error in
            guard let self else { return }
            self.isSendingLink = false
            if let error {
                self.errorMessage = "Send link failed: \(error.localizedDescription)"
            } else {
                UserDefaults.standard.set(trimmed, forKey: self.pendingEmailKey)
                self.statusMessage = "Check your email for the sign-in link."
            }
        }
    }

    func handleSignInLink(_ url: URL) {
        let link = url.absoluteString
        guard Auth.auth().isSignIn(withEmailLink: link) else { return }
        guard let pendingEmail = UserDefaults.standard.string(forKey: pendingEmailKey) else {
            errorMessage = "Open the link on the same device after requesting it."
            return
        }

        isSigningIn = true
        statusMessage = nil
        errorMessage = nil

        Auth.auth().signIn(withEmail: pendingEmail, link: link) { [weak self] _, error in
            guard let self else { return }
            self.isSigningIn = false
            if let error {
                self.errorMessage = "Sign-in failed: \(error.localizedDescription)"
            } else {
                self.statusMessage = "Signed in."
                UserDefaults.standard.removeObject(forKey: self.pendingEmailKey)
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
