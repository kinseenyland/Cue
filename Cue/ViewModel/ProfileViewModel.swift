//
//  ProfileViewModel.swift
//  Cue
//

import Combine
import FirebaseFirestore
import Foundation
import SwiftUI

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var displayName: String = ""
    @Published var preferredClassTypes: [WorkoutType] = []
    @Published var workoutStructure: WorkoutStructurePreference? = nil
    @Published var musicApproach: MusicApproach? = nil
    @Published var isLoading = false

    private let db = Firestore.firestore()

    func load(uid: String) {
        isLoading = true
        db.collection("users").document(uid).getDocument { [weak self] snapshot, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    print("ProfileViewModel: Firestore fetch error — \(error.localizedDescription)")
                    self.isLoading = false
                    return
                }
                guard let data = snapshot?.data() else {
                    print("ProfileViewModel: No document found for uid \(uid)")
                    self.isLoading = false
                    return
                }
                print("ProfileViewModel: Loaded data — \(data)")
                self.displayName = data["displayName"] as? String ?? ""
                self.preferredClassTypes = (data["preferredClassTypes"] as? [String] ?? [])
                    .compactMap { WorkoutType(rawValue: $0) }
                self.workoutStructure = WorkoutStructurePreference(
                    rawValue: data["workoutStructure"] as? String ?? ""
                )
                self.musicApproach = MusicApproach(
                    rawValue: data["musicApproach"] as? String ?? ""
                )
                self.isLoading = false
            }
        }
    }
}
