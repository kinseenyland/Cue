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
    @Published var profileImage: UIImage? = nil
    @Published var isLoading = false
    @Published var isSaving = false

    private let db = Firestore.firestore()

    // MARK: - Local cache

    private static func cacheURL(for uid: String) -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("profile_\(uid).jpg")
    }

    private func loadCachedImage(uid: String) {
        let url = Self.cacheURL(for: uid)
        if let data = try? Data(contentsOf: url) {
            profileImage = UIImage(data: data)
        }
    }

    private func cacheImage(_ image: UIImage, uid: String) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        try? data.write(to: Self.cacheURL(for: uid))
    }

    private func compressedBase64(from image: UIImage) -> String? {
        let maxDim: CGFloat = 200
        let scale = min(maxDim / image.size.width, maxDim / image.size.height, 1)
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        guard let jpeg = resized?.jpegData(compressionQuality: 0.7) else { return nil }
        return jpeg.base64EncodedString()
    }

    // MARK: - Load

    func load(uid: String) {
        isLoading = true
        loadCachedImage(uid: uid)

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

                if let b64 = data["profileImageBase64"] as? String,
                   let imgData = Data(base64Encoded: b64),
                   let img = UIImage(data: imgData) {
                    self.profileImage = img
                    self.cacheImage(img, uid: uid)
                }

                self.isLoading = false
            }
        }
    }

    // MARK: - Save profile image

    func saveProfileImage(_ image: UIImage, uid: String) {
        guard !uid.isEmpty else { return }
        profileImage = image
        cacheImage(image, uid: uid)

        guard let b64 = compressedBase64(from: image) else { return }
        isSaving = true
        db.collection("users").document(uid).setData(
            ["profileImageBase64": b64], merge: true
        ) { [weak self] error in
            DispatchQueue.main.async {
                self?.isSaving = false
                if let error {
                    print("ProfileViewModel: Image save error — \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Save preferences

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
