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

    // MARK: - Helpers

    /// Creates a signed-out profile, switches to it and taps Connect, leaving
    /// the sign-in alert on screen.
    private func signedOutProfileAsked() -> String {
        let profile = newProfileName()
        step("Create \(profile) without a setup key, switch to it and connect") {
            profiles.open()
            profiles.create(profile)
            profiles.switchTo(profile)
            XCTAssertTrue(connectExpectingLogin(), "connecting \(profile) did not ask for a login within 30 s")
        }
        return profile
    }

    /// Watches the toggle for a while: it must settle on Disconnected and
    /// never reach Connected.
    private func expectStaysDisconnected(for seconds: TimeInterval,
                                         file: StaticString = #filePath, line: UInt = #line) {
        let deadline = Date().addingTimeInterval(seconds)
        var last = ""
        while Date() < deadline {
            last = connection.toggle.value as? String ?? ""
            if last == "Connected" {
                XCTFail("the VPN connected after the login was cancelled", file: file, line: line)
                return
            }
            Thread.sleep(forTimeInterval: 0.5)
        }
        XCTAssertEqual(last, "Disconnected", "the VPN did not settle on Disconnected", file: file, line: line)
    }
}
