//
//  ScheduleFormView.swift
//  Cue
//
//  Created by Kinsee Nyland on 2/10/26.
//

import SwiftUI

struct ScheduleFormView: View {
    @Environment(\.dismiss) private var dismiss

    let plans: [WorkoutPlan]
    let onSave: (ScheduleDraft) -> Void
    let onDelete: (() -> Void)?

    private var isEditing: Bool { onDelete != nil }

    @State private var searchText = ""
    @State private var selectedPlan: WorkoutPlan?
    @State private var location: String
    @State private var selectedDate: Date
    @State private var selectedTimeSlot: Int // minutes from midnight (e.g. 360 = 6:00 AM)
    @State private var showDeleteConfirmation = false

    private static let timeSlots: [Int] = Array(stride(from: 0, to: 24 * 60, by: 15))

    private static func defaultTimeSlot() -> Int {
        360 // 6:00 AM
    }

    private static func timeSlotFromDate(_ date: Date) -> Int {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: date)
        let minute = cal.component(.minute, from: date)
        let total = hour * 60 + minute
        return timeSlots.min(by: { abs($0 - total) < abs($1 - total) }) ?? 360
    }

    private static func labelForSlot(_ slot: Int) -> String {
        let hour = slot / 60
        let minute = slot % 60
        let period = hour < 12 ? "AM" : "PM"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return String(format: "%d:%02d %@", displayHour, minute, period)
    }

    private var filteredPlans: [WorkoutPlan] {
        if searchText.isEmpty { return plans }
        let query = searchText.lowercased()
        return plans.filter { plan in
            plan.title.lowercased().contains(query)
            || plan.type.rawValue.lowercased().contains(query)
            || plan.difficulty.rawValue.lowercased().contains(query)
        }
    }

    init(plans: [WorkoutPlan], draft: ScheduleDraft? = nil, onSave: @escaping (ScheduleDraft) -> Void, onDelete: (() -> Void)? = nil) {
        self.plans = plans
        self.onSave = onSave
        self.onDelete = onDelete

        if let draft {
            _selectedPlan = State(initialValue: plans.first { $0.id == draft.planId })
            _location = State(initialValue: draft.location)
            _selectedDate = State(initialValue: draft.startsAt)
            _selectedTimeSlot = State(initialValue: Self.timeSlotFromDate(draft.startsAt))
        } else {
            _selectedPlan = State(initialValue: nil)
            _location = State(initialValue: "")
            _selectedDate = State(initialValue: Date())
            _selectedTimeSlot = State(initialValue: Self.defaultTimeSlot())
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(isEditing ? "Edit Schedule" : "Add to Schedule")
                    .font(.title)
                    .fontWeight(.semibold)
                    .padding(.horizontal)
                    .padding(.top, 8)

                planSelectionSection

                if let plan = selectedPlan {
                    selectedPlanCard(plan)
                }

                if selectedPlan != nil {
                    scheduleDetailsSection
                }

                if isEditing {
                    Divider().padding(.horizontal)

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete from Schedule")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 24)
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(selectedPlan == nil)
            }
        }
        .alert("Delete this scheduled class?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                onDelete?()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
    }

    // MARK: - Plan Selection

    private var planSelectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search plans...", text: $searchText)
                    .font(.subheadline)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.black, lineWidth: 1)
            )
            .padding(.horizontal)

            if filteredPlans.isEmpty {
                Text(plans.isEmpty ? "No plans yet — create one first." : "No matching plans.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else {
                VStack(spacing: 0) {
                    ForEach(filteredPlans) { plan in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if selectedPlan?.id == plan.id {
                                    selectedPlan = nil
                                } else {
                                    selectedPlan = plan
                                }
                                searchText = ""
                            }
                        } label: {
                            PlanRow(plan: plan, isSelected: selectedPlan?.id == plan.id)
                        }
                        .buttonStyle(.plain)

                        if plan.id != filteredPlans.last?.id {
                            Divider().padding(.leading, 52)
                        }
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Selected Plan Card

    private func selectedPlanCard(_ plan: WorkoutPlan) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.white, .black)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(plan.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                HStack(spacing: 6) {
                    InfoChip(label: plan.type.rawValue.capitalized)
                    InfoChip(label: plan.difficulty.rawValue.capitalized)
                    InfoChip(label: "\(plan.durationMinutes) min")
                }
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
        .padding(.horizontal)
    }

    // MARK: - Time, Calendar, Location

    private var scheduleDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Divider().padding(.horizontal)

            HStack {
                Text("Time")
                    .font(.headline)
                Spacer()
                Picker("Time", selection: $selectedTimeSlot) {
                    ForEach(Self.timeSlots, id: \.self) { slot in
                        Text(Self.labelForSlot(slot)).tag(slot)
                    }
                }
                .pickerStyle(.menu)
                .tint(.primary)
            }
            .padding(.horizontal)

            RoundedTextField(placeholder: "Location", text: $location)

            Text("Date")
                .font(.headline)
                .padding(.horizontal)

            DatePicker(
                "Date",
                selection: $selectedDate,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .padding(.horizontal)
        }
    }

    // MARK: - Save

    private func save() {
        guard let plan = selectedPlan else { return }
        let trimmedLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)

        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        var merged = DateComponents()
        merged.year = dateComponents.year
        merged.month = dateComponents.month
        merged.day = dateComponents.day
        merged.hour = selectedTimeSlot / 60
        merged.minute = selectedTimeSlot % 60
        let combinedDate = calendar.date(from: merged) ?? selectedDate

        let draft = ScheduleDraft(
            title: plan.title,
            location: trimmedLocation,
            workoutType: plan.type,
            difficulty: plan.difficulty,
            startsAt: combinedDate,
            durationMinutes: plan.durationMinutes,
            planId: plan.id
        )
        onSave(draft)
        dismiss()
    }
}

// MARK: - Plan Row

private struct PlanRow: View {
    let plan: WorkoutPlan
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? .white : Color(.systemGray3), .black)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(plan.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                Text("\(plan.type.rawValue.capitalized) · \(plan.difficulty.rawValue.capitalized)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(plan.durationMinutes) min")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .background(isSelected ? Color(.systemGray6) : Color.clear)
    }
}

// MARK: - Rounded Text Field

private struct RoundedTextField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        TextField(placeholder, text: $text)
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.black, lineWidth: 1)
            )
            .padding(.horizontal)
    }
}

// MARK: - Info Chip

private struct InfoChip: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(.systemGray3), lineWidth: 1)
            )
    }
}

#Preview {
    NavigationStack {
        ScheduleFormView(plans: []) { _ in }
    }
}
