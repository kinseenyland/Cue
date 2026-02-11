//
//  ScheduleView.swift
//  Cue
//
//  Created by Kinsee Nyland on 2/10/26.
//

import SwiftUI

struct ScheduleView: View {
    @StateObject private var vm = ScheduleViewModel()
    @State private var isPresentingCreateForm = false
    @State private var editingItem: ScheduleItem? = nil

    var body: some View {
        NavigationStack {
            List {
                if let status = vm.statusMessage {
                    Text(status)
                        .foregroundStyle(.green)
                }

                if let error = vm.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                }

                ForEach(vm.items) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.headline)
                        Text("\(dateText(for: item)) • \(item.durationMinutes) mins")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Task { await vm.deleteSchedule(id: item.id) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            editingItem = item
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
            }
            .navigationTitle("Schedule")
            .toolbar {
                Button {
                    isPresentingCreateForm = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.orange)
                }
            }
        }
        .task {
            await vm.fetchSchedules()
        }
        .sheet(isPresented: $isPresentingCreateForm) {
            NavigationStack {
                ScheduleFormView { draft in
                    Task { await vm.createSchedule(from: draft) }
                }
            }
        }
        .sheet(item: $editingItem) { item in
            NavigationStack {
                ScheduleFormView(draft: draft(from: item)) { updated in
                    Task { await vm.updateSchedule(id: item.id, from: updated) }
                }
            }
        }
    }

    private func dateText(for item: ScheduleItem) -> String {
        let date = Date(timeIntervalSince1970: item.startsAt)
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    private func draft(from item: ScheduleItem) -> ScheduleDraft {
        ScheduleDraft(
            title: item.title,
            startsAt: Date(timeIntervalSince1970: item.startsAt),
            durationMinutes: item.durationMinutes,
            planId: item.planId
        )
    }
}

#Preview {
    ScheduleView()
}
