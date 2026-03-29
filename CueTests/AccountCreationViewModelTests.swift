//
//  AccountCreationViewModelTests.swift
//  CueTests
//

import XCTest
@testable import Cue

final class AccountCreationViewModelTests: XCTestCase {
    /// `async` + `MainActor.run` avoids XCTest calling `@MainActor` tests off the main actor (which can corrupt memory with `ObservableObject`).
    func testCanAdvance_nameRequiresNonWhitespace() async {
        await MainActor.run {
            let vm = AccountCreationViewModel()
            vm.step = .name
            vm.displayName = ""
            XCTAssertFalse(vm.canAdvance)
            vm.displayName = "   "
            XCTAssertFalse(vm.canAdvance)
            vm.displayName = "Alex"
            XCTAssertTrue(vm.canAdvance)
        }
    }

    func testCanAdvance_emailRequiresAtSign() async {
        await MainActor.run {
            let vm = AccountCreationViewModel()
            vm.step = .email
            vm.email = "notanemail"
            XCTAssertFalse(vm.canAdvance)
            vm.email = "a@b.co"
            XCTAssertTrue(vm.canAdvance)
        }
    }

    func testCanAdvance_passwordRequiresLengthAndMatch() async {
        await MainActor.run {
            let vm = AccountCreationViewModel()
            vm.step = .password
            vm.password = "12345"
            vm.confirmPassword = "12345"
            XCTAssertFalse(vm.canAdvance)
            vm.password = "123456"
            vm.confirmPassword = "123457"
            XCTAssertFalse(vm.canAdvance)
            vm.confirmPassword = "123456"
            XCTAssertTrue(vm.canAdvance)
        }
    }
}
