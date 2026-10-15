//
//  ProfileManagementTests.swift
//  NetBirdUITests
//
//  Section F of the login test plan: managing profiles.
//

import XCTest

final class ProfileManagementTests: E2ETestCase {

    /// LOGIN-F05 — neither the default profile nor the active one can be
    /// removed. The app does not offer the action at all: the default row's
    /// swipe actions hold Logout but no Remove, and the active row has none.
    func testF05_defaultAndActiveProfilesCannotBeRemoved() {
        let profile = newProfileName()

        step("Make \(profile) active, so default is listed among the others") {
            profiles.open()
            profiles.create(profile)
            profiles.switchTo(profile)
        }

        step("default offers Logout but no Remove") {
            guard let row = profiles.row("default") else {
                XCTFail("default is not under All Profiles")
                return
            }
            row.swipeLeft()
            XCTAssertTrue(app.buttons["Logout"].waitForExistence(timeout: 3),
                          "the swipe on default did not reveal its actions")
            XCTAssertFalse(app.buttons["Remove"].exists, "default can be removed")
            screenshot("default swipe actions")
            // Close the actions without choosing one.
            row.swipeRight()
        }

        step("The active profile offers no actions") {
            let active = app.cells.containing(.staticText, identifier: profile).firstMatch
            XCTAssertTrue(active.exists, "no row for the active profile")
            active.swipeLeft()
            XCTAssertFalse(app.buttons["Remove"].waitForExistence(timeout: 2), "the active profile can be removed")
            XCTAssertFalse(app.buttons["Logout"].exists, "the active profile offers Logout in the list")
            screenshot("Active profile swipe")
        }

        markPassed()
    }
}
