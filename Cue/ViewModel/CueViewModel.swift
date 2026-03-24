//
//  CueViewModel.swift
//  Cue
//
//  Created by Kinsee Nyland on 2/3/26.
//

import Combine
import FirebaseAuth
import FirebaseFirestore
import Foundation
import SwiftUI

@MainActor
class CueViewModel: ObservableObject {
    @Published var plans: [WorkoutPlan] = []
    @Published var statusMessage: String? = nil
    @Published var errorMessage: String? = nil

    private let db = Firestore.firestore()

    func fetchPlans() async {
        guard let ownerId = Auth.auth().currentUser?.uid else {
            errorMessage = "Sign in required."
            statusMessage = nil
            return
        }

        do {
            let snapshot = try await db.collection("plans")
                .whereField("ownerId", isEqualTo: ownerId)
                .order(by: "updatedAt", descending: true)
                .getDocuments()
            let docs = snapshot.documents

            plans = docs.compactMap { doc in
                let data = doc.data()

                guard
                    let title = data["title"] as? String,
                    let typeRaw = data["type"] as? String,
                    let difficultyRaw = data["difficulty"] as? String,
                    let type = WorkoutType(legacy: typeRaw),
                    let difficulty = Difficulty(rawValue: difficultyRaw)
                else { return nil }

                let durationMinutes = data["durationMinutes"] as? Int ?? 45
                let movementData = data["movements"] as? [[String: Any]] ?? []
                let movements = movementData.compactMap { movementFromDict($0) }
                let fallbackNames = data["movements"] as? [String] ?? []
                let resolvedMovements = movements.isEmpty
                    ? fallbackNames.map { Movement(name: $0, goalType: .timed, seconds: 30) }
                    : movements

                return WorkoutPlan(
                    id: doc.documentID,
                    ownerId: ownerId,
                    title: title,
                    type: type,
                    difficulty: difficulty,
                    durationMinutes: durationMinutes,
                    createdAt: data["createdAt"] as? Double ?? Date().timeIntervalSince1970,
                    updatedAt: data["updatedAt"] as? Double ?? Date().timeIntervalSince1970,
                    isPublic: data["isPublic"] as? Bool ?? false,
                    isFavorited: data["isFavorited"] as? Bool ?? false,
                    movements: resolvedMovements,
                    warmUpPlaylistId: data["warmUpPlaylistId"] as? String,
                    mainPlaylistId: data["mainPlaylistId"] as? String,
                    coolDownPlaylistId: data["coolDownPlaylistId"] as? String,
                    lastRunAt: data["lastRunAt"] as? Double
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
                ownerId: Auth.auth().currentUser?.uid ?? "debug-user",
                title: "Hot Pilates - Core",
                type: .matPilates,
                difficulty: .medium,
                durationMinutes: 60,
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
                "durationMinutes": plan.durationMinutes,
                "movements": plan.movements.map { movementToDict($0) },
                "createdAt": plan.createdAt,
                "updatedAt": plan.updatedAt,
                "isPublic": plan.isPublic,
                "isFavorited": false
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

    func createPlan(from draft: WorkoutPlanDraft) async {
        statusMessage = "Saving plan..."
        errorMessage = nil

        let ownerId = Auth.auth().currentUser?.uid ?? "debug-user"
        let plan = WorkoutPlan(
            ownerId: ownerId,
            title: draft.title,
            type: draft.type,
            difficulty: draft.difficulty,
            durationMinutes: draft.durationMinutes,
            isPublic: false,
            movements: draft.movements,
            warmUpPlaylistId: draft.warmUpPlaylistId,
            mainPlaylistId: draft.mainPlaylistId,
            coolDownPlaylistId: draft.coolDownPlaylistId
        )

        var data: [String: Any] = [
            "ownerId": plan.ownerId,
            "title": plan.title,
            "type": plan.type.rawValue,
            "difficulty": plan.difficulty.rawValue,
            "durationMinutes": draft.durationMinutes,
            "movements": draft.movements.map { movementToDict($0) },
            "createdAt": plan.createdAt,
            "updatedAt": plan.updatedAt,
            "isPublic": plan.isPublic,
            "isFavorited": false
        ]

        if let warm = draft.warmUpPlaylistId {
            data["warmUpPlaylistId"] = warm
        }
        if let main = draft.mainPlaylistId {
            data["mainPlaylistId"] = main
        }
        if let cool = draft.coolDownPlaylistId {
            data["coolDownPlaylistId"] = cool
        }

        do {
            try await db.collection("plans").document(plan.id).setData(data, merge: true)
            statusMessage = "✅ Plan saved to Firebase!"
            await fetchPlans()
        } catch {
            errorMessage = "❌ Save failed: \(error.localizedDescription)"
            statusMessage = nil
            print(error)
        }
    }

    func updatePlan(id: String, from draft: WorkoutPlanDraft) async {
        statusMessage = "Updating plan..."
        errorMessage = nil

        var data: [String: Any] = [
            "title": draft.title,
            "type": draft.type.rawValue,
            "difficulty": draft.difficulty.rawValue,
            "durationMinutes": draft.durationMinutes,
            "movements": draft.movements.map { movementToDict($0) },
            "updatedAt": Date().timeIntervalSince1970
        ]

        if let warm = draft.warmUpPlaylistId {
            data["warmUpPlaylistId"] = warm
        }
        if let main = draft.mainPlaylistId {
            data["mainPlaylistId"] = main
        }
        if let cool = draft.coolDownPlaylistId {
            data["coolDownPlaylistId"] = cool
        }

        do {
            try await db.collection("plans").document(id).updateData(data)
            statusMessage = "✅ Plan updated!"
            await fetchPlans()
        } catch {
            errorMessage = "❌ Update failed: \(error.localizedDescription)"
            statusMessage = nil
        }
    }

    func toggleFavorite(id: String, isFavorited: Bool) async {
        // Optimistic update
        if let idx = plans.firstIndex(where: { $0.id == id }) {
            plans[idx].isFavorited = isFavorited
        }
        do {
            try await db.collection("plans").document(id).updateData(["isFavorited": isFavorited])
        } catch {
            // Revert on failure
            if let idx = plans.firstIndex(where: { $0.id == id }) {
                plans[idx].isFavorited = !isFavorited
            }
            errorMessage = "❌ Update failed: \(error.localizedDescription)"
        }
    }

    func markPlanAsRun(id: String) async {
        let now = Date().timeIntervalSince1970
        if let idx = plans.firstIndex(where: { $0.id == id }) {
            plans[idx].lastRunAt = now
        }
        do {
            try await db.collection("plans").document(id).updateData(["lastRunAt": now])
        } catch {
            print("Failed to update lastRunAt: \(error.localizedDescription)")
        }
    }

    func duplicatePlan(_ plan: WorkoutPlan, newName: String) async {
        let draft = WorkoutPlanDraft(
            title: newName,
            type: plan.type,
            difficulty: plan.difficulty,
            durationMinutes: plan.durationMinutes,
            movements: plan.movements,
            warmUpPlaylistId: plan.warmUpPlaylistId,
            mainPlaylistId: plan.mainPlaylistId,
            coolDownPlaylistId: plan.coolDownPlaylistId
        )
        await createPlan(from: draft)
    }

    func deletePlan(id: String) async {
        statusMessage = "Deleting plan..."
        errorMessage = nil

        do {
            try await db.collection("plans").document(id).delete()
            statusMessage = "✅ Plan deleted."
            await fetchPlans()
        } catch {
            errorMessage = "❌ Delete failed: \(error.localizedDescription)"
            statusMessage = nil
        }
    }

    private func movementToDict(_ movement: Movement) -> [String: Any] {
        var data: [String: Any] = [
            "id": movement.id,
            "name": movement.name,
            "goalType": movement.goalType.rawValue,
            "section": movement.section.rawValue
        ]
        if let seconds = movement.seconds {
            data["seconds"] = seconds
        }
        if let reps = movement.reps {
            data["reps"] = reps
        }
        if let notes = movement.notes {
            data["notes"] = notes
        }
        if let sectionName = movement.sectionName {
            data["sectionName"] = sectionName
        }
        if let sectionDurationMinutes = movement.sectionDurationMinutes {
            data["sectionDurationMinutes"] = sectionDurationMinutes
        }
        return data
    }

    private func movementFromDict(_ data: [String: Any]) -> Movement? {
        guard
            let name = data["name"] as? String,
            let goalTypeRaw = data["goalType"] as? String,
            let goalType = GoalType(rawValue: goalTypeRaw)
        else { return nil }

        let section = WorkoutSection(rawValue: data["section"] as? String ?? "") ?? .main

        return Movement(
            id: data["id"] as? String ?? UUID().uuidString,
            name: name,
            notes: data["notes"] as? String,
            goalType: goalType,
            seconds: data["seconds"] as? Int,
            reps: data["reps"] as? Int,
            section: section,
            sectionName: data["sectionName"] as? String,
            sectionDurationMinutes: data["sectionDurationMinutes"] as? Int
        )
    }
}
