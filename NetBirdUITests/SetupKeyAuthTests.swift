//
//  SetupKeyAuthTests.swift
//  NetBirdUITests
//
//  E2E-001: setup-key login — the iOS counterpart of the Android
//  SetupKeyAuthTest. A fresh profile is created through the Profiles UI and
//  logged in to NetBird Cloud with the setup key from NB_SETUP_KEY; the
//  login is proven by connecting on that profile without being asked to
//  sign in.
//
//  On success the test leaves the device as it found it. On failure it
//  leaves everything in place for troubleshooting; the next run removes the
//  leftovers first.
//

import XCTest

final class SetupKeyAuthTests: XCTestCase {

    private var app: XCUIApplication!
    private var profiles: ProfilesScreen!
    private var connection: ConnectionScreen!
    private var previousProfile = "default"
    private var testProfile = ""

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = AppLaunch.toMainScreen()
        profiles = ProfilesScreen(app: app)
        connection = ConnectionScreen(app: app)
        removeLeftovers()
    }

    override func tearDownWithError() throws {
        guard testRun?.hasSucceeded == true, !testProfile.isEmpty else { return }
        connection.disconnect()
        profiles.open()
        if profiles.activeProfileName == testProfile {
            profiles.switchTo(previousProfile)
        }
        profiles.remove(testProfile)
    }

    func testLoginWithSetupKeyViaUi() throws {
        let setupKey = try TestSecrets.value("NB_SETUP_KEY")
        testProfile = ProfilesScreen.testProfilePrefix + String(UUID().uuidString.prefix(8)).lowercased()

        XCTContext.runActivity(named: "Create \(testProfile) with the setup key") { _ in
            profiles.open()
            previousProfile = profiles.activeProfileName ?? previousProfile
            profiles.create(testProfile, setupKey: setupKey)
        }

        XCTContext.runActivity(named: "Switch to \(testProfile)") { _ in
            profiles.switchTo(testProfile)
        }

        XCTContext.runActivity(named: "Connect") { _ in
            connection.connect()
            XCTAssertTrue(app.staticTexts["Connected"].waitForExistence(timeout: 5), "the status does not read Connected")
            XCTAssertFalse(app.alerts["Login failed"].exists, "a login error is shown")
        }

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Connected on \(testProfile)"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    /// Removes test profiles a failed run left behind, switching away from one
    /// first if it is still active — an active profile cannot be removed.
    private func removeLeftovers() {
        profiles.open()
        let leftovers = profiles.leftoverTestProfiles
        guard !leftovers.isEmpty else { return }

        XCTContext.runActivity(named: "Remove leftovers: \(leftovers.joined(separator: ", "))") { _ in
            if let active = profiles.activeProfileName, active.hasPrefix(ProfilesScreen.testProfilePrefix) {
                connection.disconnect()
                profiles.open()
                profiles.switchTo(previousProfile)
            }
            for name in profiles.leftoverTestProfiles where name != profiles.activeProfileName {
                profiles.remove(name)
            }
        }
    }
}
