//
//  AccountCreationViewModel.swift
//  Cue
//

import Combine
import Foundation
import SwiftUI

enum AccountCreationStep: Int, CaseIterable {
    case name             = 0
    case email            = 1
    case password         = 2
    case classTypes       = 3
    case workoutStructure = 4
    case musicApproach    = 5
    case spotify          = 6

    static let total = Self.allCases.count  // 7

    var title: String {
        switch self {
        case .name:             return "Your Name"
        case .email:            return "Your Email"
        case .password:         return "Create a Password"
        case .classTypes:       return "Your Teaching Style"
        case .workoutStructure: return "Your Workflow"
        case .musicApproach:    return "Music & Planning"
        case .spotify:          return "Connect Spotify"
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
    var isOnLastStep:  Bool { step == .spotify }

    var canAdvance: Bool {
        switch step {
        case .name:             return !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .email:            return email.trimmingCharacters(in: .whitespacesAndNewlines).contains("@")
        case .password:         return password.count >= 6 && password == confirmPassword
        case .classTypes:       return !preferredClassTypes.isEmpty
        case .workoutStructure: return workoutStructurePreference != nil
        case .musicApproach:    return musicApproach != nil
        case .spotify:          return true
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
