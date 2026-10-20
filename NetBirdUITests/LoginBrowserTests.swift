//
//  LoginBrowserTests.swift
//  NetBirdUITests
//
//  Section B of the login UI test plan: what the app does when the login
//  browser is closed without signing in. A test reaches that outcome by
//  cancelling the system sign-in alert — the IdP page behind it is out of a
//  test's reach.
//

import XCTest

final class LoginBrowserTests: E2ETestCase {

    /// LOGIN-B01 — cancelling the sign-in alert aborts cleanly: the VPN does
    /// not start, no login error or prompt follows, and the app stays usable.
    ///
    /// The regression this guards is the VPN starting anyway, which would
    /// launch the extension, hit its needs-login path and pop a spurious
    /// "Authentication required" alert.
    func testB01_cancellingTheLoginAbortsCleanly() throws {
        try requireDevice()
        let profile = signedOutProfileAsked()

        step("Cancel the sign-in") {
            SignInAlert.cancel()
        }

        step("The VPN stays off and nothing else pops up") {
            expectStaysDisconnected(for: 10)
            XCTAssertEqual(app.alerts.count, 0,
                           "an alert followed the cancelled login: \(app.alerts.firstMatch.label)")
            XCTAssertFalse(SignInAlert.isShowing, "the sign-in alert came back by itself")
        }

        step("The app is still usable") {
            TabBar(app: app).open("Peers")
            XCTAssertTrue(app.staticTexts["Peers connected"].waitForExistence(timeout: 5), "the Peers tab did not open")
            TabBar(app: app).open("Connection")
            XCTAssertTrue(connection.badge(profile).waitForExistence(timeout: 5), "the Connection tab did not come back")
        }
        screenshot("After cancelling the login")
        markPassed()
    }

    /// LOGIN-B02 — a cancelled login can be retried straight away.
    ///
    /// Guards the local callback port being released: the aborted login keeps
    /// its loopback HTTP server bound until it is cancelled, and if that stops
    /// happening the retry stalls trying to bind the same port — the sign-in
    /// alert then never appears.
    func testB02_cancelledLoginCanBeRetried() throws {
        try requireDevice()
        _ = signedOutProfileAsked()

        step("Cancel the first login") {
            SignInAlert.cancel()
            expectStaysDisconnected(for: 3)
        }

        step("Connect again asks for a login within 60 s") {
            XCTAssertTrue(connectExpectingLogin(timeout: 60), "the retry did not ask for a login within 60 s")
            screenshot("Second sign-in alert")
            SignInAlert.cancel()
        }

        markPassed()
    }

    /// LOGIN-B03 — repeated cancellations leave nothing behind: every attempt
    /// asks for the login again, the VPN never leaves Disconnected and no
    /// error piles up.
    func testB03_repeatedCancellationsLeaveNoResidue() throws {
        try requireDevice()
        _ = signedOutProfileAsked()

        for attempt in 1...4 {
            step("Attempt \(attempt): cancel the sign-in") {
                if attempt > 1 {
                    XCTAssertTrue(connectExpectingLogin(timeout: 60),
                                  "attempt \(attempt) did not ask for a login within 60 s")
                }
                SignInAlert.cancel()
                expectStaysDisconnected(for: 3)
                XCTAssertEqual(app.alerts.count, 0,
                               "an alert is left after attempt \(attempt): \(app.alerts.firstMatch.label)")
            }
        }
        screenshot("After four cancelled logins")
        markPassed()
    }

    // MARK: - Helpers

    /// Creates a signed-out profile, switches to it and taps Connect, leaving
    /// the sign-in alert on screen.
    private func signedOutProfileAsked() -> String {
        let profile = createSignedOutProfile()
        step("Switch to \(profile) and connect") {
            profiles.switchTo(profile)
            XCTAssertTrue(connectExpectingLogin(), "connecting \(profile) did not ask for a login within 30 s")
        }
        return profile
    }
}
