//
//  ScheduleFormView.swift
//  Cue
//
//  Created by Kinsee Nyland on 2/10/26.
//

import SwiftUI

struct ScheduleFormView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var startsAt: Date
    @State private var durationMinutes: Int
    @State private var planId: String

    let onSave: (ScheduleDraft) -> Void

    init(draft: ScheduleDraft? = nil, onSave: @escaping (ScheduleDraft) -> Void) {
        let initial = draft ?? ScheduleDraft(
            title: "",
            startsAt: Date(),
            durationMinutes: 60,
            planId: nil
        )
        _title = State(initialValue: initial.title)
        _startsAt = State(initialValue: initial.startsAt)
        _durationMinutes = State(initialValue: initial.durationMinutes)
        _planId = State(initialValue: initial.planId ?? "")
        self.onSave = onSave
    }

    var body: some View {
        Form {
            Section("Class Details") {
                TextField("Class title", text: $title)
                DatePicker("Start time", selection: $startsAt)
                Stepper("Duration: \(durationMinutes) mins", value: $durationMinutes, in: 10...180, step: 5)
                TextField("Plan ID (optional)", text: $planId)
            }
        }
        .navigationTitle("Schedule Class")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPlanId = planId.trimmingCharacters(in: .whitespacesAndNewlines)
        let draft = ScheduleDraft(
            title: trimmedTitle,
            startsAt: startsAt,
            durationMinutes: durationMinutes,
            planId: trimmedPlanId.isEmpty ? nil : trimmedPlanId
        )
        onSave(draft)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        ScheduleFormView { _ in }
    }
}
