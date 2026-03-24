//
//  ScheduleViewModel.swift
//  Cue
//
//  Created by Kinsee Nyland on 2/10/26.
//

import Combine
import FirebaseAuth
import FirebaseFirestore
import Foundation
import SwiftUI

@MainActor
final class ScheduleViewModel: ObservableObject {
    @Published var items: [ScheduleItem] = []
    @Published var statusMessage: String? = nil
    @Published var errorMessage: String? = nil

    private let db = Firestore.firestore()
    private let calendar = Calendar.current

    /// Set of dates (day-level) that have at least one scheduled item.
    var scheduledDates: Set<DateComponents> {
        Set(items.map { item in
            calendar.dateComponents([.year, .month, .day], from: item.startDate)
        })
    }

    /// Items for a specific day.
    func items(for date: Date) -> [ScheduleItem] {
        items.filter { calendar.isDate($0.startDate, inSameDayAs: date) }
    }

    func fetchSchedules() async {
        guard let ownerId = Auth.auth().currentUser?.uid else {
            errorMessage = "Sign in required."
            statusMessage = nil
            return
        }

        do {
            let snapshot = try await db.collection("schedules")
                .whereField("ownerId", isEqualTo: ownerId)
                .order(by: "startsAt", descending: false)
                .getDocuments()

            items = snapshot.documents.compactMap { doc in
                let data = doc.data()
                guard
                    let title = data["title"] as? String,
                    let startsAt = data["startsAt"] as? Double,
                    let durationMinutes = data["durationMinutes"] as? Int
                else { return nil }

                let wt = (data["workoutType"] as? String).flatMap { WorkoutType(legacy: $0) }
                let diff = (data["difficulty"] as? String).flatMap { Difficulty(rawValue: $0) }

                return ScheduleItem(
                    id: doc.documentID,
                    ownerId: ownerId,
                    title: title,
                    location: data["location"] as? String ?? "",
                    workoutType: wt,
                    difficulty: diff,
                    startsAt: startsAt,
                    durationMinutes: durationMinutes,
                    planId: data["planId"] as? String
                )
            }

            statusMessage = "✅ Loaded \(items.count) classes"
            errorMessage = nil
        } catch {
            errorMessage = "❌ Fetch failed: \(error.localizedDescription)"
            statusMessage = nil
        }
    }

    func createSchedule(from draft: ScheduleDraft) async {
        statusMessage = "Saving class..."
        errorMessage = nil

        let ownerId = Auth.auth().currentUser?.uid ?? "debug-user"
        let schedule = ScheduleItem(
            ownerId: ownerId,
            title: draft.title,
            location: draft.location,
            workoutType: draft.workoutType,
            difficulty: draft.difficulty,
            startsAt: draft.startsAt.timeIntervalSince1970,
            durationMinutes: draft.durationMinutes,
            planId: draft.planId
        )

        var data: [String: Any] = [
            "ownerId": schedule.ownerId,
            "title": schedule.title,
            "location": schedule.location,
            "startsAt": schedule.startsAt,
            "durationMinutes": schedule.durationMinutes,
            "planId": schedule.planId as Any,
            "createdAt": Date().timeIntervalSince1970,
            "updatedAt": Date().timeIntervalSince1970
        ]
        if let wt = schedule.workoutType { data["workoutType"] = wt.rawValue }
        if let diff = schedule.difficulty { data["difficulty"] = diff.rawValue }

        do {
            try await db.collection("schedules").document(schedule.id).setData(data, merge: true)
            statusMessage = "✅ Class saved!"
            await fetchSchedules()
        } catch {
            errorMessage = "❌ Save failed: \(error.localizedDescription)"
            statusMessage = nil
        }
    }

    func updateSchedule(id: String, from draft: ScheduleDraft) async {
        statusMessage = "Updating class..."
        errorMessage = nil

        var data: [String: Any] = [
            "title": draft.title,
            "location": draft.location,
            "startsAt": draft.startsAt.timeIntervalSince1970,
            "durationMinutes": draft.durationMinutes,
            "planId": draft.planId as Any,
            "updatedAt": Date().timeIntervalSince1970
        ]
        if let wt = draft.workoutType { data["workoutType"] = wt.rawValue }
        if let diff = draft.difficulty { data["difficulty"] = diff.rawValue }

        do {
            try await db.collection("schedules").document(id).updateData(data)
            statusMessage = "✅ Class updated!"
            await fetchSchedules()
        } catch {
            errorMessage = "❌ Update failed: \(error.localizedDescription)"
            statusMessage = nil
        }
    }

    func deleteSchedule(id: String) async {
        statusMessage = "Deleting class..."
        errorMessage = nil

        do {
            try await db.collection("schedules").document(id).delete()
            statusMessage = "✅ Class deleted."
            await fetchSchedules()
        } catch {
            errorMessage = "❌ Delete failed: \(error.localizedDescription)"
            statusMessage = nil
        }
    }
}
