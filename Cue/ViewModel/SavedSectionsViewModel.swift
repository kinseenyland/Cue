//
//  SavedSectionsViewModel.swift
//  Cue
//

import Combine
import FirebaseAuth
import FirebaseFirestore
import Foundation
import SwiftUI

@MainActor
final class SavedSectionsViewModel: ObservableObject {
    @Published var sections: [SavedSection] = []
    @Published var isLoading = false

    private let db = Firestore.firestore()

    // MARK: - Fetch

    func fetchSections() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let snapshot = try await db.collection("savedSections")
                .whereField("ownerId", isEqualTo: uid)
                .getDocuments()

            sections = snapshot.documents.compactMap { doc in
                let d = doc.data()
                guard let name = d["name"] as? String,
                      let typeRaw = d["sectionType"] as? String,
                      let sectionType = WorkoutSection(rawValue: typeRaw)
                else { return nil }

                let movementDicts = d["movements"] as? [[String: Any]] ?? []
                let movements = movementDicts.compactMap { movementFromDict($0) }

                return SavedSection(
                    id: doc.documentID,
                    ownerId: uid,
                    name: name,
                    sectionType: sectionType,
                    durationMinutes: d["durationMinutes"] as? Int ?? 5,
                    movements: movements,
                    createdAt: d["createdAt"] as? Double ?? 0
                )
            }
            .sorted { $0.createdAt > $1.createdAt }
        } catch {
            print("SavedSectionsViewModel: fetch error — \(error.localizedDescription)")
        }
    }

    // MARK: - Save

    func saveSection(_ section: SavedSection) async {
        let data: [String: Any] = [
            "ownerId": section.ownerId,
            "name": section.name,
            "sectionType": section.sectionType.rawValue,
            "durationMinutes": section.durationMinutes,
            "movements": section.movements.map { movementToDict($0) },
            "createdAt": section.createdAt
        ]
        do {
            try await db.collection("savedSections")
                .document(section.id)
                .setData(data)
            await fetchSections()
        } catch {
            print("SavedSectionsViewModel: save error — \(error.localizedDescription)")
        }
    }

    // MARK: - Delete

    func deleteSection(id: String) async {
        do {
            try await db.collection("savedSections").document(id).delete()
            sections.removeAll { $0.id == id }
        } catch {
            print("SavedSectionsViewModel: delete error — \(error.localizedDescription)")
        }
    }

    // MARK: - Filtered accessors

    func sections(for type: WorkoutSection) -> [SavedSection] {
        sections.filter { $0.sectionType == type }
    }

    // MARK: - Movement serialization

    private func movementToDict(_ m: Movement) -> [String: Any] {
        var data: [String: Any] = [
            "id": m.id,
            "name": m.name,
            "section": m.section.rawValue
        ]

        if let goalType = m.goalType {
            data["goalType"] = goalType.rawValue
        }
        if let s = m.seconds { data["seconds"] = s }
        if let r = m.reps { data["reps"] = r }
        if let n = m.notes { data["notes"] = n }
        if let sn = m.sectionName { data["sectionName"] = sn }
        if let sd = m.sectionDurationMinutes { data["sectionDurationMinutes"] = sd }

        return data
    }

    private func movementFromDict(_ data: [String: Any]) -> Movement? {
        guard let name = data["name"] as? String else { return nil }

        let goalType: GoalType? = {
            guard let goalTypeRaw = data["goalType"] as? String else { return nil }
            return GoalType(rawValue: goalTypeRaw)
        }()

        let sectionRaw = data["section"] as? String ?? WorkoutSection.main.rawValue
        let sectionType = WorkoutSection(rawValue: sectionRaw) ?? .main

        return Movement(
            id: data["id"] as? String ?? UUID().uuidString,
            name: name,
            notes: data["notes"] as? String,
            goalType: goalType,
            seconds: data["seconds"] as? Int,
            reps: data["reps"] as? Int,
            section: sectionType,
            sectionName: data["sectionName"] as? String,
            sectionDurationMinutes: data["sectionDurationMinutes"] as? Int
        )
    }
}

