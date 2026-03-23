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
    @Published var isSaving = false

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

    func save(
        uid: String,
        name: String,
        preferredClassTypes: [WorkoutType],
        workoutStructure: WorkoutStructurePreference?,
        musicApproach: MusicApproach?
    ) {
        guard !uid.isEmpty else {
            print("ProfileViewModel: save called with empty uid")
            return
        }
        isSaving = true
        let data: [String: Any] = [
            "displayName": name,
            "preferredClassTypes": preferredClassTypes.map { $0.rawValue },
            "workoutStructure": workoutStructure?.rawValue ?? "",
            "musicApproach": musicApproach?.rawValue ?? ""
        ]
        db.collection("users").document(uid).setData(data, merge: true) { [weak self] error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isSaving = false
                if let error {
                    print("ProfileViewModel: Save error — \(error.localizedDescription)")
                    return
                }
                self.displayName = name
                self.preferredClassTypes = preferredClassTypes
                self.workoutStructure = workoutStructure
                self.musicApproach = musicApproach
            }
        }
    }
}
