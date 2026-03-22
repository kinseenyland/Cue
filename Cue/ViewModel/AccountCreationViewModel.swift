//
//  AccountCreationViewModel.swift
//  Cue
//

import Combine
import Foundation
import SwiftUI

enum AccountCreationStep: Int, CaseIterable {
    case name        = 0
    case email       = 1
    case password    = 2
    case preferences = 3

    static let total = Self.allCases.count

    var title: String {
        switch self {
        case .name:        return "Your Name"
        case .email:       return "Your Email"
        case .password:    return "Create a Password"
        case .preferences: return "Your Teaching Style"
        }
    }
}

@MainActor
final class AccountCreationViewModel: ObservableObject {
    @Published var step: AccountCreationStep = .name
    @Published var displayName = ""
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var preferredClassTypes: Set<WorkoutType> = []
    @Published var workoutStructurePreference: WorkoutStructurePreference? = nil
    @Published var musicApproach: MusicApproach? = nil

    var isOnFirstStep: Bool { step == .name }
    var isOnLastStep:  Bool { step == .preferences }

    var canAdvance: Bool {
        switch step {
        case .name:
            return !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .email:
            return email.trimmingCharacters(in: .whitespacesAndNewlines).contains("@")
        case .password:
            return password.count >= 6 && password == confirmPassword
        case .preferences:
            return !preferredClassTypes.isEmpty
                && workoutStructurePreference != nil
                && musicApproach != nil
        }
    }

    func advance() {
        if let next = AccountCreationStep(rawValue: step.rawValue + 1) { step = next }
    }

    func back() {
        if let prev = AccountCreationStep(rawValue: step.rawValue - 1) { step = prev }
    }

    func submit(authVM: AuthViewModel) {
        authVM.signUp(
            name: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password,
            preferredClassTypes: preferredClassTypes.map(\.rawValue),
            workoutStructure: workoutStructurePreference?.rawValue ?? "",
            musicApproach: musicApproach?.rawValue ?? ""
        )
    }
}
