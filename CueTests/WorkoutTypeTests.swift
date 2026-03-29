//
//  WorkoutTypeTests.swift
//  CueTests
//

import XCTest
@testable import Cue

final class WorkoutTypeTests: XCTestCase {
    func testLegacyPilatesMapsToMatPilates() {
        XCTAssertEqual(WorkoutType(legacy: "pilates"), .matPilates)
    }

    func testLegacyRawValueStillParses() {
        XCTAssertEqual(WorkoutType(legacy: "yoga"), .yoga)
        XCTAssertEqual(WorkoutType(legacy: "strength"), .strength)
    }

    func testLegacyInvalidReturnsNil() {
        XCTAssertNil(WorkoutType(legacy: "not-a-type"))
    }
}
