//
//  MovementFirestoreTests.swift
//  CueTests
//

import XCTest
@testable import Cue

final class MovementFirestoreTests: XCTestCase {
    func testDecodeMinimalFields() {
        let m = Movement(firestoreDictionary: [
            "name": "Plank",
            "goalType": "timed",
            "seconds": 45,
        ])
        XCTAssertNotNil(m)
        XCTAssertEqual(m?.name, "Plank")
        XCTAssertEqual(m?.goalType, .timed)
        XCTAssertEqual(m?.seconds, 45)
        XCTAssertEqual(m?.section, .main)
    }

    func testDecodeReturnsNilWithoutRequiredFields() {
        XCTAssertNil(Movement(firestoreDictionary: ["name": "X"]))
        XCTAssertNil(Movement(firestoreDictionary: ["goalType": "timed"]))
    }

    func testDecodeSectionAndSubsection() {
        let m = Movement(firestoreDictionary: [
            "id": "mid-1",
            "name": "Squat",
            "goalType": "reps",
            "reps": 12,
            "section": "main",
            "sectionName": "Legs",
            "sectionDurationMinutes": 8,
            "notes": "slow",
        ])
        XCTAssertEqual(m?.id, "mid-1")
        XCTAssertEqual(m?.section, .main)
        XCTAssertEqual(m?.sectionName, "Legs")
        XCTAssertEqual(m?.sectionDurationMinutes, 8)
        XCTAssertEqual(m?.notes, "slow")
        XCTAssertEqual(m?.reps, 12)
    }

    func testRoundTripWithCueViewModelShape() {
        let original = Movement(
            name: "Push-up",
            notes: nil,
            goalType: .timed,
            seconds: 30,
            reps: nil,
            section: .warmUp,
            sectionName: nil,
            sectionDurationMinutes: 5
        )
        let dict: [String: Any] = [
            "id": original.id,
            "name": original.name,
            "goalType": original.goalType.rawValue,
            "section": original.section.rawValue,
            "seconds": original.seconds as Any,
            "sectionDurationMinutes": original.sectionDurationMinutes as Any,
        ]
        let decoded = Movement(firestoreDictionary: dict)
        XCTAssertEqual(decoded?.id, original.id)
        XCTAssertEqual(decoded?.name, original.name)
        XCTAssertEqual(decoded?.section, .warmUp)
        XCTAssertEqual(decoded?.seconds, 30)
        XCTAssertEqual(decoded?.sectionDurationMinutes, 5)
    }
}
