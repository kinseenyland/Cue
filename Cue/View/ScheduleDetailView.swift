//
//  ScheduleDetailView.swift
//  Cue
//

import SwiftUI

struct ScheduleDetailView: View {
    let item: ScheduleItem
    let plans: [WorkoutPlan]
    let onUpdate: (ScheduleDraft) -> Void
    let onDelete: () -> Void
    var onGoToPlan: ((WorkoutPlan) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var currentItem: ScheduleItem
    @State private var isShowingEdit = false

    init(
        item: ScheduleItem,
        plans: [WorkoutPlan],
        onUpdate: @escaping (ScheduleDraft) -> Void,
        onDelete: @escaping () -> Void,
        onGoToPlan: ((WorkoutPlan) -> Void)? = nil
    ) {
        self.item = item
        self.plans = plans
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        self.onGoToPlan = onGoToPlan
        self._currentItem = State(initialValue: item)
    }

    // MARK: - Formatters

    private var typeIcon: String {
        guard let wt = currentItem.workoutType else { return "figure.run" }
        switch wt {
        case .matPilates, .reformerPilates: return "figure.pilates"
        case .yoga: return "figure.yoga"
        case .cycle: return "bicycle"
        case .strength: return "dumbbell.fill"
        case .cardio: return "heart.fill"
        }
    }

    private var typeLabel: String {
        currentItem.workoutType?.displayName ?? "—"
    }

    private var difficultyLabel: String {
        guard let d = currentItem.difficulty else { return "—" }
        switch d {
        case .easy: return "Low"
        case .medium: return "Medium"
        case .hard: return "High"
        }
    }

    private var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d, yyyy"
        return f.string(from: currentItem.startDate)
    }

    private var formattedTime: String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        f.amSymbol = "AM"
        f.pmSymbol = "PM"
        return f.string(from: currentItem.startDate)
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.black)
                        .frame(width: 33, height: 31)
                }
                Spacer()
            }
            .padding(.horizontal, 7)

            HStack(alignment: .center, spacing: 10) {
                Text(currentItem.title)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)

            HStack(spacing: 10) {
                Spacer()
                PlanDetailCard(icon: typeIcon, label: "Type", value: typeLabel)
                PlanDetailCard(icon: "timer", label: "Time", value: "\(currentItem.durationMinutes) min")
                PlanDetailCard(icon: "flame.fill", label: "Intensity", value: difficultyLabel)
                Spacer()
            }
            .padding(.horizontal, 10)

            VStack(alignment: .leading, spacing: 16) {
                infoRow(icon: "calendar", label: "Date", value: formattedDate)
                infoRow(icon: "clock", label: "Time", value: formattedTime)
                if !currentItem.location.isEmpty {
                    infoRow(icon: "mappin.and.ellipse", label: "Location", value: currentItem.location)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)

            Spacer()

            VStack(spacing: 12) {
                Button { isShowingEdit = true } label: {
                    Text("Edit Schedule")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                if let planId = currentItem.planId,
                   let plan = plans.first(where: { $0.id == planId }),
                   let goToPlan = onGoToPlan {
                    Button { goToPlan(plan) } label: {
                        Text("Go to Plan")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.black)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }

            }
            .padding(.horizontal, 16)
            .padding(.bottom, 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $isShowingEdit) {
            NavigationStack {
                ScheduleFormView(
                    plans: plans,
                    draft: draft(from: currentItem),
                    onSave: { updated in
                        var newItem = currentItem
                        newItem.title = updated.title
                        newItem.location = updated.location
                        newItem.workoutType = updated.workoutType
                        newItem.difficulty = updated.difficulty
                        newItem.startsAt = updated.startsAt.timeIntervalSince1970
                        newItem.durationMinutes = updated.durationMinutes
                        newItem.planId = updated.planId
                        currentItem = newItem
                        onUpdate(updated)
                    },
                    onDelete: {
                        onDelete()
                        dismiss()
                    }
                )
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 12, weight: .thin))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.black)
            }
        }
    }

    private func draft(from item: ScheduleItem) -> ScheduleDraft {
        ScheduleDraft(
            title: item.title,
            location: item.location,
            workoutType: item.workoutType,
            difficulty: item.difficulty,
            startsAt: Date(timeIntervalSince1970: item.startsAt),
            durationMinutes: item.durationMinutes,
            planId: item.planId
        )
    }
}
