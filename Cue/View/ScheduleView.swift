//
//  ScheduleView.swift
//  Cue
//
//  Created by Kinsee Nyland on 2/10/26.
//

import SwiftUI

struct ScheduleItem: Identifiable {
    let id = UUID()
    let day: String
    let date: String
    let title: String
    let time: String
}

struct ScheduleView: View {
    private let items: [ScheduleItem] = [
        ScheduleItem(day: "Mar", date: "30", title: "Hot Pilates", time: "8:00 AM"),
        ScheduleItem(day: "Mar", date: "30", title: "Yoga Flow", time: "6:00 PM"),
        ScheduleItem(day: "Apr", date: "01", title: "Hot Pilates", time: "8:00 AM"),
        ScheduleItem(day: "Apr", date: "02", title: "Power Flow", time: "9:30 AM"),
        ScheduleItem(day: "Apr", date: "03", title: "Hot Pilates", time: "8:00 AM"),
        ScheduleItem(day: "Apr", date: "05", title: "Strength + Core", time: "10:00 AM")
    ]
    @State private var isShowingAlert = false
    @State private var alertMessage = ""

    var body: some View {
        NavigationStack {
            List(items) { item in
                Button {
                    alertMessage = "\(item.title) at \(item.time)"
                    isShowingAlert = true
                } label: {
                    HStack(spacing: 12) {
                        VStack {
                            Text(item.day)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(item.date)
                                .font(.headline)
                        }
                        .frame(width: 44)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.headline)
                            Text(item.time)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Schedule")
            .toolbar {
                Button {
                    alertMessage = "Add class coming soon."
                    isShowingAlert = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.orange)
                }
            }
        }
        .alert("Cue", isPresented: $isShowingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }
}

#Preview {
    ScheduleView()
}
