//
//  ScheduleView.swift
//  Cue
//
//  Created by Kinsee Nyland on 2/10/26.
//

import SwiftUI

struct ScheduleView: View {
    @StateObject private var vm = ScheduleViewModel()
    @StateObject private var plansVM = CueViewModel()
    @State private var isPresentingCreateForm = false
    @State private var editingItem: ScheduleItem? = nil

    private var groupedByMonth: [(key: String, items: [ScheduleItem])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        let grouped = Dictionary(grouping: vm.items) { item -> String in
            formatter.string(from: item.startDate)
        }
        let ordered = vm.items.compactMap { item -> String in
            formatter.string(from: item.startDate)
        }
        var seen = Set<String>()
        let uniqueOrder = ordered.filter { seen.insert($0).inserted }
        return uniqueOrder.map { month in
            (key: month, items: grouped[month] ?? [])
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let error = vm.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.footnote)
                        .padding(.horizontal)
                }

                LazyVStack(alignment: .leading, spacing: 24) {
                    ForEach(groupedByMonth, id: \.key) { month, items in
                        Section {
                            VStack(spacing: 12) {
                                ForEach(items) { item in
                                    Button {
                                        editingItem = item
                                    } label: {
                                        ScheduleCard(item: item)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        } header: {
                            Text(month)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .padding(.horizontal)
                        }
                    }
                }
                .padding(.top, 8)
            }
            .navigationTitle("Schedule")
            .toolbar {
                Button {
                    isPresentingCreateForm = true
                } label: {
                    Image(systemName: "plus")
                        .fontWeight(.medium)
                }
            }
        }
        .task {
            await vm.fetchSchedules()
            await plansVM.fetchPlans()
        }
        .sheet(isPresented: $isPresentingCreateForm) {
            NavigationStack {
                ScheduleFormView(plans: plansVM.plans) { draft in
                    Task { await vm.createSchedule(from: draft) }
                }
            }
        }
        .sheet(item: $editingItem) { item in
            NavigationStack {
                ScheduleFormView(
                    plans: plansVM.plans,
                    draft: draft(from: item),
                    onSave: { updated in
                        Task { await vm.updateSchedule(id: item.id, from: updated) }
                    },
                    onDelete: {
                        Task { await vm.deleteSchedule(id: item.id) }
                    }
                )
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

// MARK: - Schedule Card

private struct ScheduleCard: View {
    let item: ScheduleItem

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f
    }()

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mma"
        f.amSymbol = "am"
        f.pmSymbol = "pm"
        return f
    }()

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 2) {
                Text(Self.monthFormatter.string(from: item.startDate).uppercased())
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                Text(Self.dayFormatter.string(from: item.startDate))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
            }
            .frame(width: 56)

            Divider()
                .frame(height: 40)
                .padding(.horizontal, 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                Text(item.location.isEmpty
                     ? Self.timeFormatter.string(from: item.startDate)
                     : "\(item.location) · \(Self.timeFormatter.string(from: item.startDate))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.body)
                .foregroundStyle(.secondary)
                .padding(.trailing, 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}

#Preview {
    ScheduleView()
}
