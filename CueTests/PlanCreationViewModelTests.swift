//
//  PlanCreationViewModelTests.swift
//  CueTests
//

import XCTest
@testable import Cue

final class PlanCreationViewModelTests: XCTestCase {
    func testRedistributeMainSectionTime_splitsEvenlyWithRemainderOnFirstSection() async {
        await MainActor.run {
            let vm = PlanCreationViewModel()
            vm.draft.durationMinutes = 60
            vm.draft.warmUpDurationMinutes = 10
            vm.draft.coolDownDurationMinutes = 10
            vm.draft.mainSections = [
                WorkoutSubSection(name: "A", durationMinutes: 0, movements: [sampleMovement()]),
                WorkoutSubSection(name: "B", durationMinutes: 0, movements: [sampleMovement()]),
                WorkoutSubSection(name: "C", durationMinutes: 0, movements: [sampleMovement()]),
            ]

            vm.redistributeMainSectionTime()

            XCTAssertEqual(vm.draft.mainSections[0].durationMinutes, 14)
            XCTAssertEqual(vm.draft.mainSections[1].durationMinutes, 13)
            XCTAssertEqual(vm.draft.mainSections[2].durationMinutes, 13)
            XCTAssertEqual(vm.totalMainMinutes, 40)
        }
    }

    func testRedistributeWarmUpCoolDown_assignsOddRemainderToCoolDown() async {
        await MainActor.run {
            let vm = PlanCreationViewModel()
            vm.draft.durationMinutes = 50
            vm.draft.mainSections = [
                WorkoutSubSection(name: "Only", durationMinutes: 35, movements: [sampleMovement()]),
            ]

            vm.redistributeWarmUpCoolDown()

            XCTAssertEqual(vm.draft.warmUpDurationMinutes, 7)
            XCTAssertEqual(vm.draft.coolDownDurationMinutes, 8)
        }
    }

    func testToWorkoutPlanDraft_flattensSectionsAndTagsMovements() async {
        await MainActor.run {
            let vm = PlanCreationViewModel()
            vm.draft.name = "Test Plan"
            vm.draft.type = .yoga
            vm.draft.difficulty = .easy
            vm.draft.durationMinutes = 40
            vm.draft.warmUpDurationMinutes = 5
            vm.draft.coolDownDurationMinutes = 5
            vm.draft.warmUpMovements = [Movement(name: "W", goalType: .timed, seconds: 30, section: .main)]
            vm.draft.mainSections = [
                WorkoutSubSection(
                    name: "Block A",
                    durationMinutes: 10,
                    movements: [Movement(name: "M1", goalType: .reps, reps: 10, section: .main)]
                ),
            ]
            vm.draft.coolDownMovements = [Movement(name: "C", goalType: .timed, seconds: 60, section: .main)]

            let plan = vm.toWorkoutPlanDraft()

            XCTAssertEqual(plan.movements.count, 3)
            XCTAssertEqual(plan.movements[0].section, .warmUp)
            XCTAssertNil(plan.movements[0].sectionName)
            XCTAssertEqual(plan.movements[0].sectionDurationMinutes, 5)

            XCTAssertEqual(plan.movements[1].section, .main)
            XCTAssertEqual(plan.movements[1].sectionName, "Block A")
            XCTAssertEqual(plan.movements[1].sectionDurationMinutes, 10)

            XCTAssertEqual(plan.movements[2].section, .coolDown)
            XCTAssertNil(plan.movements[2].sectionName)
            XCTAssertEqual(plan.movements[2].sectionDurationMinutes, 5)
        }
    }

    private func sampleMovement() -> Movement {
        Movement(name: "Move", goalType: .timed, seconds: 30)
    }
}
