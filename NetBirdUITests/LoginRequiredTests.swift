//
//  LoginRequiredTests.swift
//  NetBirdUITests
//
//  Section A of the login UI test plan: the app asks for a login exactly when
//  one is needed. A test sees the request as the system sign-in alert iOS
//  shows before the browser opens; it never goes past that alert.
//

import XCTest

final class LoginRequiredTests: E2ETestCase {

    /// LOGIN-A01 — a profile that never signed in asks for a login on its
    /// first connect, and does not connect before it.
    ///
    /// The plan starts from a reset app; the test cannot reset the unmodified
    /// app, so a freshly created profile stands in for a fresh install — it
    /// has no identity on the server either.
    func testA01_newProfileAsksForLogin() throws {
        try requireDevice()
        let profile = newProfileName()

        step("Create \(profile) without a setup key and switch to it") {
            profiles.open()
            profiles.create(profile)
            profiles.switchTo(profile)
        }

        step("Connect asks for a login within 30 s") {
            XCTAssertTrue(connectExpectingLogin(timeout: 30), "no sign-in alert within 30 s of Connect")
            XCTAssertNotEqual(connection.toggle.value as? String, "Connected",
                              "the VPN reached Connected before the login")
            screenshot("Sign-in asked for \(profile)")
            SignInAlert.cancel()
        }

        markPassed()
    }
}
