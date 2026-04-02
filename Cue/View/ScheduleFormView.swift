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
    @State private var isPlanPickerExpanded: Bool
    @State private var location: String
    @State private var selectedDate: Date
    @State private var selectedHour: Int    // 1–12
    @State private var selectedMinute: Int  // 0, 15, 30, 45
    @State private var selectedPeriod: String // "AM" or "PM"
    @State private var showDeleteConfirmation = false
    @State private var showExitConfirmation = false

    private static let hours = Array(1...12)
    private static let minutes = [0, 15, 30, 45]
    private static let periods = ["AM", "PM"]

    private static func componentsFromDate(_ date: Date) -> (hour: Int, minute: Int, period: String) {
        let cal = Calendar.current
        let h24 = cal.component(.hour, from: date)
        let m = cal.component(.minute, from: date)
        let snappedMinute = minutes.min(by: { abs($0 - m) < abs($1 - m) }) ?? 0
        let period = h24 < 12 ? "AM" : "PM"
        let h12 = h24 == 0 ? 12 : (h24 > 12 ? h24 - 12 : h24)
        return (h12, snappedMinute, period)
    }

    private var selectedHour24: Int {
        if selectedPeriod == "AM" {
            return selectedHour == 12 ? 0 : selectedHour
        } else {
            return selectedHour == 12 ? 12 : selectedHour + 12
        }
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

    init(plans: [WorkoutPlan], draft: ScheduleDraft? = nil, initialDate: Date? = nil, onSave: @escaping (ScheduleDraft) -> Void, onDelete: (() -> Void)? = nil) {
        self.plans = plans
        self.onSave = onSave
        self.onDelete = onDelete

        if let draft {
            let comps = Self.componentsFromDate(draft.startsAt)
            _selectedPlan = State(initialValue: plans.first { $0.id == draft.planId })
            _isPlanPickerExpanded = State(initialValue: false)
            _location = State(initialValue: draft.location)
            _selectedDate = State(initialValue: draft.startsAt)
            _selectedHour = State(initialValue: comps.hour)
            _selectedMinute = State(initialValue: comps.minute)
            _selectedPeriod = State(initialValue: comps.period)
        } else {
            _selectedPlan = State(initialValue: nil)
            _isPlanPickerExpanded = State(initialValue: false)
            _location = State(initialValue: "")
            _selectedDate = State(initialValue: initialDate ?? Date())
            _selectedHour = State(initialValue: 6)
            _selectedMinute = State(initialValue: 0)
            _selectedPeriod = State(initialValue: "AM")
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
                Button("Cancel") {
                    if selectedPlan != nil {
                        showExitConfirmation = true
                    } else {
                        dismiss()
                    }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(selectedPlan == nil)
            }
        }
        .overlay {
            if showDeleteConfirmation {
                CustomAlertView(
                    title: "Delete this scheduled class?",
                    message: "This action cannot be undone.",
                    primaryLabel: "Cancel",
                    primaryAction: { showDeleteConfirmation = false },
                    primaryStyle: .gray,
                    secondaryLabel: "Delete",
                    secondaryAction: {
                        showDeleteConfirmation = false
                        onDelete?()
                        dismiss()
                    },
                    secondaryStyle: .destructive,
                    onDismiss: { showDeleteConfirmation = false }
                )
            }
            if showExitConfirmation {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture { showExitConfirmation = false }

                VStack(spacing: 16) {
                    HStack {
                        Spacer()
                        Button { showExitConfirmation = false } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 30, height: 30)
                                .background(Color(.systemGray5))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }

                    Text("Are you sure?")
                        .font(.system(size: 18, weight: .bold))

                    Text("Your schedule changes will be lost if you leave.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button {
                        showExitConfirmation = false
                        dismiss()
                    } label: {
                        Text("Discard")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color.red)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
                .padding(.horizontal, 40)
            }
        }
    }

    // MARK: - Plan Selection

    private var planSelectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Plan")
                .font(.headline)
                .padding(.horizontal)

            if !isPlanPickerExpanded {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isPlanPickerExpanded = true
                    }
                } label: {
                    if let plan = selectedPlan {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.white, .black)
                                .font(.title3)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(plan.title)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)
                                HStack(spacing: 4) {
                                    Text(plan.type.displayName)
                                    Text("·")
                                    Text(plan.difficulty.rawValue.capitalized)
                                    Text("·")
                                    Text("\(plan.durationMinutes) min")
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text("Change")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )
                    } else {
                        HStack {
                            Text("Select a Plan")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
            } else {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 14))
                        TextField("Search plans...", text: $searchText)
                            .font(.subheadline)
                        if !searchText.isEmpty {
                            Button { searchText = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal)

                    if filteredPlans.isEmpty {
                        Text(plans.isEmpty ? "No plans yet — create one first." : "No matching plans.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    } else {
                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(filteredPlans) { plan in
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedPlan = plan
                                            isPlanPickerExpanded = false
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
                        }
                        .frame(maxHeight: 250)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                        .padding(.horizontal)
                    }
                }
            }
        }
    }

    // MARK: - Time, Calendar, Location

    private var scheduleDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Divider().padding(.horizontal)

            Text("Time")
                .font(.headline)
                .padding(.horizontal)

            HStack(spacing: 0) {
                Picker("Hour", selection: $selectedHour) {
                    ForEach(Self.hours, id: \.self) { h in
                        Text("\(h)").tag(h)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 70)
                .clipped()

                Picker("Minute", selection: $selectedMinute) {
                    ForEach(Self.minutes, id: \.self) { m in
                        Text(String(format: "%02d", m)).tag(m)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 70)
                .clipped()

                Picker("Period", selection: $selectedPeriod) {
                    ForEach(Self.periods, id: \.self) { p in
                        Text(p).tag(p)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 70)
                .clipped()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)

            Text("Location")
                .font(.headline)
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
        merged.hour = selectedHour24
        merged.minute = selectedMinute
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
                Text("\(plan.type.displayName) · \(plan.difficulty.rawValue.capitalized)")
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
