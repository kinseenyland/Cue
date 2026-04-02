//
//  ScheduleViewModelTests.swift
//  CueTests
//

import XCTest
@testable import Cue

final class ScheduleViewModelTests: XCTestCase {
    func testItemsForDateFiltersSameCalendarDay() async {
        await MainActor.run {
            let vm = ScheduleViewModel()
            let cal = Calendar.current
            var c = DateComponents()
            c.calendar = cal
            c.year = 2026
            c.month = 6
            c.day = 10
            c.hour = 9
            c.minute = 0
            let morning = cal.date(from: c)!
            c.hour = 16
            let afternoon = cal.date(from: c)!
            c.day = 11
            let nextDay = cal.date(from: c)!

            vm.items = [
                ScheduleItem(ownerId: "o", title: "A", startsAt: morning.timeIntervalSince1970, durationMinutes: 60),
                ScheduleItem(ownerId: "o", title: "B", startsAt: afternoon.timeIntervalSince1970, durationMinutes: 60),
                ScheduleItem(ownerId: "o", title: "C", startsAt: nextDay.timeIntervalSince1970, durationMinutes: 60),
            ]

            let june10 = morning
            let sameDay = vm.items(for: june10)
            XCTAssertEqual(sameDay.count, 2)
            XCTAssertTrue(sameDay.contains { $0.title == "A" })
            XCTAssertTrue(sameDay.contains { $0.title == "B" })

            XCTAssertEqual(vm.items(for: nextDay).count, 1)
        }
    }

    func testScheduledDatesUsesYearMonthDayComponents() async {
        await MainActor.run {
            let vm = ScheduleViewModel()
            let cal = Calendar.current
            var c = DateComponents()
            c.calendar = cal
            c.year = 2026
            c.month = 7
            c.day = 4
            c.hour = 8
            let d1 = cal.date(from: c)!
            c.hour = 20
            let d2 = cal.date(from: c)!

            vm.items = [
                ScheduleItem(ownerId: "o", title: "Early", startsAt: d1.timeIntervalSince1970, durationMinutes: 1),
                ScheduleItem(ownerId: "o", title: "Late", startsAt: d2.timeIntervalSince1970, durationMinutes: 1),
            ]

            let days = vm.scheduledDates
            XCTAssertEqual(days.count, 1)
            let only = days.first!
            XCTAssertEqual(only.year, 2026)
            XCTAssertEqual(only.month, 7)
            XCTAssertEqual(only.day, 4)
        }
    }
}
