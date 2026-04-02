//
//  ScheduleView.swift
//  Cue
//
//  Created by Kinsee Nyland on 2/10/26.
//

import SwiftUI

struct ScheduleView: View {
    @Binding var selectedTab: MainTab
    @StateObject private var vm = ScheduleViewModel()
    @StateObject private var plansVM = CueViewModel()
    @State private var isPresentingCreateForm = false
    @State private var navigationPath = NavigationPath()
    @State private var selectedDate: Date? = Date()
    @State private var displayedMonth: Date = Date()

    private let calendar = Calendar.current

    private var daysInMonth: [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth),
              let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth))
        else { return [] }
        return range.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth)
        }
    }

    private var monthYearLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: displayedMonth)
    }

    private var weekdaySymbols: [String] {
        let symbols = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
        let firstWeekday = calendar.firstWeekday - 1
        return Array(symbols[firstWeekday...]) + Array(symbols[..<firstWeekday])
    }

    private var firstWeekdayOffset: Int {
        guard let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth))
        else { return 0 }
        let weekday = calendar.component(.weekday, from: firstOfMonth)
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    private var itemsForSelectedDate: [ScheduleItem]? {
        guard let selectedDate else { return nil }
        return vm.items(for: selectedDate)
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                HStack {
                    Text("Schedule")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.black)
                    Spacer()
                    Button {
                        isPresentingCreateForm = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 20))
                            .foregroundStyle(.black)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 8)

                calendarStrip
                    .padding(.bottom, 8)

                Divider()

                ScrollView {
                    if let error = vm.errorMessage {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.footnote)
                            .padding(.horizontal)
                            .padding(.top, 8)
                    }

                    if let items = itemsForSelectedDate {
                        if items.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 36))
                                    .foregroundStyle(.secondary)
                                Text("No classes on this day")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Button {
                                    isPresentingCreateForm = true
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "plus")
                                            .font(.system(size: 13, weight: .semibold))
                                        Text("Schedule a Class")
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color.black)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 48)
                        } else {
                            VStack(spacing: 10) {
                                ForEach(items) { item in
                                    ScheduleCard(item: item)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            navigationPath.append(item)
                                        }
                                }
                            }
                            .padding(.top, 12)
                        }
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: ScheduleItem.self) { item in
                ScheduleDetailView(
                    item: item,
                    plans: plansVM.plans,
                    onUpdate: { draft in
                        Task { await vm.updateSchedule(id: item.id, from: draft) }
                    },
                    onDelete: {
                        Task {
                            await vm.deleteSchedule(id: item.id)
                            navigationPath.removeLast()
                        }
                    }
                )
            }
        }
        .task {
            await vm.fetchSchedules()
            await plansVM.fetchPlans()
        }
        .sheet(isPresented: $isPresentingCreateForm) {
            NavigationStack {
                ScheduleFormView(
                    plans: plansVM.plans,
                    initialDate: selectedDate
                ) { draft in
                    Task { await vm.createSchedule(from: draft) }
                }
            }
        }
    }

    // MARK: - Calendar Strip

    private var calendarStrip: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    withAnimation {
                        displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                        selectedDate = nil
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.black)
                }

                Spacer()

                Text(monthYearLabel)
                    .font(.headline)

                Spacer()

                Button {
                    withAnimation {
                        displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                        selectedDate = nil
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.black)
                }
            }
            .padding(.horizontal)

            // Weekday headers
            let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 8)

            // Day grid
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(0..<firstWeekdayOffset, id: \.self) { _ in
                    Color.clear.frame(height: 40)
                }

                ForEach(daysInMonth, id: \.self) { date in
                    let isSelected = selectedDate.map { calendar.isDate(date, inSameDayAs: $0) } ?? false
                    let isToday = calendar.isDateInToday(date)
                    let hasItems = vm.scheduledDates.contains(
                        calendar.dateComponents([.year, .month, .day], from: date)
                    )

                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedDate = date
                        }
                    } label: {
                        VStack(spacing: 3) {
                            Text("\(calendar.component(.day, from: date))")
                                .font(.system(size: 15, weight: isSelected ? .bold : .regular))
                                .foregroundStyle(
                                    isSelected ? .white : isToday ? .black : .primary
                                )
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle()
                                        .fill(isSelected ? Color.black : Color.clear)
                                )

                            Circle()
                                .fill(hasItems ? (isSelected ? .white : .black) : .clear)
                                .frame(width: 5, height: 5)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
        }
        .padding(.top, 4)
    }

}

// MARK: - Schedule Card

private struct ScheduleCard: View {
    let item: ScheduleItem

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        f.amSymbol = "AM"
        f.pmSymbol = "PM"
        return f
    }()

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    Text(Self.timeFormatter.string(from: item.startDate))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if !item.location.isEmpty {
                        Text("·")
                            .foregroundStyle(.secondary)
                        Text(item.location)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
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
    ScheduleView(selectedTab: .constant(.schedule))
}
