//
//  LoginBaselineTests.swift
//  NetBirdUITests
//
//  Section S of the login test plan (docs/login-ui-test-cases.md): the
//  everyday flows, one case each.
//

import XCTest

final class LoginBaselineTests: E2ETestCase {

    /// LOGIN-S03 — Switch to a newly created profile.
    ///
    /// Creates a profile without a setup key, checks that creating it does not
    /// make it active, switches to it, and — on a device — checks that its
    /// first connect asks for a login, because the new profile has not signed
    /// in yet. The login itself is cancelled: the IdP page is out of a test's
    /// reach.
    ///
    /// The plan starts from a reset app (only "default", "No Additional
    /// Profiles"); the test runs against the unmodified app and cannot reset
    /// it, so it works from whatever profiles the device has.
    func testS03_switchToNewlyCreatedProfile() {
        let profile = newProfileName()

        step("Create \(profile) on NetBird Cloud, without a setup key") {
            profiles.open()
            profiles.create(profile)

            let details = profiles.details(of: profile)
            XCTAssertTrue(details.contains { $0.contains("api.netbird.io") },
                          "the new row does not show the NetBird Cloud server: \(details)")
            XCTAssertFalse(details.contains { $0.contains("@") },
                           "a profile that never signed in shows an account: \(details)")
            XCTAssertEqual(profiles.activeProfileName, startingProfile,
                           "creating a profile changed the active one")
        }

        step("Switch to \(profile)") {
            profiles.switchTo(profile, checkingMessage: true)
            XCTAssertNotNil(profiles.row(startingProfile),
                            "\(startingProfile) did not move to All Profiles")
        }

        step("The Connection tab shows \(profile)") {
            TabBar(app: app).open("Connection")
            XCTAssertTrue(connection.badge(profile).waitForExistence(timeout: 5),
                          "the profile badge does not read \(profile)")
        }
        screenshot("Switched to \(profile)")

        // Connect does nothing in the Simulator: VPN configurations cannot be
        // saved there.
        if !isSimulator {
            step("Connect asks for a login, which is cancelled") {
                connection.tapToggle()
                // The first connect after an install also asks to add the VPN
                // configuration; accept that while waiting for the sign-in alert.
                let deadline = Date().addingTimeInterval(30)
                while !SignInAlert.isShowing && Date() < deadline {
                    SystemAlerts.acceptIfPresent(timeout: 1)
                }
                XCTAssertTrue(SignInAlert.isShowing, "connecting a new profile did not ask for a login within 30 s")
                screenshot("Sign-in asked for \(profile)")
                SignInAlert.cancel()
                XCTAssertNotEqual(connection.toggle.value as? String, "Connected",
                                  "the VPN connected without a login")
            }
        }

        markPassed()
    }
}
