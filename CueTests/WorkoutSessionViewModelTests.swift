//
//  WorkoutSessionViewModelTests.swift
//  CueTests
//

import XCTest
@testable import Cue

final class WorkoutSessionViewModelTests: XCTestCase {
    /// Avoid `load(plan:)` / cross-section navigation so Spotify is never invoked.
    func testProgressValueAndSectionCounts() async {
        await MainActor.run {
            let vm = WorkoutSessionViewModel()
            vm.movements = [
                Movement(name: "W", goalType: .timed, seconds: 30, section: .warmUp),
                Movement(name: "M1", goalType: .timed, seconds: 60, section: .main, sectionName: "A"),
                Movement(name: "M2", goalType: .timed, seconds: 60, section: .main, sectionName: "A"),
                Movement(name: "C", goalType: .timed, seconds: 30, section: .coolDown),
            ]
            vm.currentIndex = 1
            vm.planDurationMinutes = 20

            XCTAssertEqual(vm.progressValue, 0.5, accuracy: 0.0001)
            XCTAssertEqual(vm.warmUpCount, 1)
            XCTAssertEqual(vm.mainCount, 2)
            XCTAssertEqual(vm.coolDownCount, 1)
            XCTAssertEqual(vm.remainingSeconds, 20 * 60 - vm.elapsedSeconds)
        }
    }

    func testUpcomingMovesInSectionStopsAtSectionBoundary() async {
        await MainActor.run {
            let vm = WorkoutSessionViewModel()
            vm.movements = [
                Movement(name: "A1", goalType: .timed, seconds: 30, section: .main, sectionName: "Block1"),
                Movement(name: "A2", goalType: .timed, seconds: 30, section: .main, sectionName: "Block1"),
                Movement(name: "B1", goalType: .timed, seconds: 30, section: .main, sectionName: "Block2"),
            ]
            vm.currentIndex = 0
            let upcoming = vm.upcomingMovesInSection
            XCTAssertEqual(upcoming.count, 1)
            XCTAssertEqual(upcoming[0].0, 1)
            XCTAssertEqual(upcoming[0].1.name, "A2")
        }
    }

    func testNextMoveWithinSameMainSectionDoesNotHitSpotify() async {
        await MainActor.run {
            let vm = WorkoutSessionViewModel()
            vm.movements = [
                Movement(name: "M1", goalType: .timed, seconds: 10, section: .main, sectionName: "S"),
                Movement(name: "M2", goalType: .timed, seconds: 10, section: .main, sectionName: "S"),
            ]
            vm.currentIndex = 0
            vm.isRunning = true
            vm.nextMove()
            XCTAssertEqual(vm.currentIndex, 1)
            XCTAssertFalse(vm.isComplete)
        }
    }

    func testNextMoveOnLastMoveCompletesWorkout() async {
        await MainActor.run {
            let vm = WorkoutSessionViewModel()
            vm.movements = [
                Movement(name: "Only", goalType: .reps, reps: 10, section: .main, sectionName: "S"),
            ]
            vm.currentIndex = 0
            vm.nextMove()
            XCTAssertTrue(vm.isComplete)
            XCTAssertFalse(vm.isRunning)
        }
    }

    func testTickCompletesWhenTimedMoveReachesZeroOnLastMove() async {
        await MainActor.run {
            let vm = WorkoutSessionViewModel()
            vm.movements = [
                Movement(name: "Last", goalType: .timed, seconds: 30, section: .main, sectionName: "S"),
            ]
            vm.currentIndex = 0
            vm.isRunning = true
            vm.moveRemainingSeconds = 0
            vm.sectionRemainingSeconds = 60
            vm.tick()
            XCTAssertTrue(vm.isComplete)
        }
    }

    func testJumpToMoveIgnoresOutOfRangeIndex() async {
        await MainActor.run {
            let vm = WorkoutSessionViewModel()
            vm.movements = [
                Movement(name: "A", goalType: .timed, seconds: 10, section: .main, sectionName: "S"),
            ]
            vm.currentIndex = 0
            vm.jumpToMove(at: -1)
            vm.jumpToMove(at: 1)
            XCTAssertEqual(vm.currentIndex, 0)
        }
    }
}
