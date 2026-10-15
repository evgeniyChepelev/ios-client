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
    /// Set as the last step of the test. XCTest's own testRun.hasSucceeded
    /// still reads false inside tearDown, so it cannot tell a pass from a
    /// failure there.
    private var passed = false

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = AppLaunch.toMainScreen()
        profiles = ProfilesScreen(app: app)
        connection = ConnectionScreen(app: app)
        removeLeftovers()
    }

    override func tearDownWithError() throws {
        guard passed, !testProfile.isEmpty else { return }
        connection.disconnect()
        profiles.open()
        profiles.switchTo(previousProfile)
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

        passed = true
    }

    /// Removes test profiles a failed run left behind. An active profile
    /// cannot be removed, so a test profile that is still active is switched
    /// away from first — to "default", which always exists.
    private func removeLeftovers() {
        profiles.open()
        let leftovers = profiles.leftoverTestProfiles
        guard !leftovers.isEmpty else { return }

        XCTContext.runActivity(named: "Remove leftovers: \(leftovers.joined(separator: ", "))") { _ in
            if let active = profiles.activeProfileName, active.hasPrefix(ProfilesScreen.testProfilePrefix) {
                connection.disconnect()
                profiles.open()
                profiles.switchTo("default")
            }
            for name in leftovers {
                profiles.remove(name)
            }
        }
    }
}
