//
//  CueViewModel.swift
//  Cue
//
//  Created by Kinsee Nyland on 2/3/26.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Observation

@Observable
class CueViewModel {
    var plans: [WorkoutPlan] = []
    var statusMessage: String? = nil
    var errorMessage: String? = nil

    private let db = Firestore.firestore()

    func fetchPlans() async {
        do {
            let snapshot = try await db.collection("plans").getDocuments()
            let docs = snapshot.documents

            plans = docs.compactMap { doc in
                let data = doc.data()

                guard
                    let ownerId = data["ownerId"] as? String,
                    let title = data["title"] as? String,
                    let typeRaw = data["type"] as? String,
                    let difficultyRaw = data["difficulty"] as? String,
                    let type = WorkoutType(rawValue: typeRaw),
                    let difficulty = Difficulty(rawValue: difficultyRaw)
                else { return nil }

                return WorkoutPlan(
                    id: doc.documentID,
                    ownerId: ownerId,
                    title: title,
                    type: type,
                    difficulty: difficulty,
                    createdAt: data["createdAt"] as? Double ?? Date().timeIntervalSince1970,
                    updatedAt: data["updatedAt"] as? Double ?? Date().timeIntervalSince1970,
                    isPublic: data["isPublic"] as? Bool ?? false,
                    movements: []
                )
            }

            statusMessage = "✅ Loaded \(plans.count) plans"
            errorMessage = nil
        } catch {
            errorMessage = "❌ Fetch failed: \(error.localizedDescription)"
            statusMessage = nil
            print(error)
        }
    }

    func addSamplePlan() async {
        statusMessage = "Creating sample plan..."
        errorMessage = nil

        do {
            let plan = WorkoutPlan(
                ownerId: "debug-user",
                title: "Hot Pilates - Core",
                type: .pilates,
                difficulty: .medium,
                isPublic: false,
                movements: [
                    Movement(name: "Plank", goalType: .timed, seconds: 30),
                    Movement(name: "Squats", goalType: .reps, reps: 12)
                ]
            )

            let data: [String: Any] = [
                "ownerId": plan.ownerId,
                "title": plan.title,
                "type": plan.type.rawValue,
                "difficulty": plan.difficulty.rawValue,
                "createdAt": plan.createdAt,
                "updatedAt": plan.updatedAt,
                "isPublic": plan.isPublic
            ]

            try await db.collection("plans").document(plan.id).setData(data, merge: true)

            statusMessage = "✅ Sample plan saved!"
            await fetchPlans()  // <-- this is what makes the UI update
        } catch {
            errorMessage = "❌ Save failed: \(error.localizedDescription)"
            statusMessage = nil
            print(error)
        }
    }

    func addPlan(from draft: WorkoutPlanDraft) async {
        statusMessage = "Saving plan..."
        errorMessage = nil

        let ownerId = Auth.auth().currentUser?.uid ?? "debug-user"
        let plan = WorkoutPlan(
            ownerId: ownerId,
            title: draft.title,
            type: draft.type,
            difficulty: draft.difficulty,
            isPublic: false,
            movements: []
        )

        let data: [String: Any] = [
            "ownerId": plan.ownerId,
            "title": plan.title,
            "type": plan.type.rawValue,
            "difficulty": plan.difficulty.rawValue,
            "durationMinutes": draft.durationMinutes,
            "movements": draft.movements,
            "createdAt": plan.createdAt,
            "updatedAt": plan.updatedAt,
            "isPublic": plan.isPublic
        ]

        do {
            try await db.collection("plans").document(plan.id).setData(data, merge: true)
            statusMessage = "✅ Plan saved to Firebase!"
        } catch {
            errorMessage = "❌ Save failed: \(error.localizedDescription)"
            statusMessage = nil
            print(error)
        }
    }
}
