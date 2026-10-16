//
//  E2ETestCase.swift
//  NetBirdUITests
//
//  The base for tests that create profiles. Every profile a test creates is
//  named e2e-<random> and is removed again after a passing test. A failing
//  test leaves the device exactly as it is, so a developer can look at the
//  state over remote access while the run is held; the next run removes the
//  leftovers before it starts.
//

import XCTest

class E2ETestCase: XCTestCase {

    var app: XCUIApplication!
    var profiles: ProfilesScreen!
    var connection: ConnectionScreen!

    /// The profile that was active when the test started; restored on success.
    private(set) var startingProfile = "default"
    private var createdProfiles: [String] = []

    /// Set by `markPassed()` as a test's last step. XCTest's own
    /// testRun.hasSucceeded still reads false inside tearDown, so it cannot
    /// tell a pass from a failure there.
    private var passed = false

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = AppLaunch.toMainScreen()
        profiles = ProfilesScreen(app: app)
        connection = ConnectionScreen(app: app)
        removeLeftovers()
        profiles.open()
        startingProfile = profiles.activeProfileName ?? startingProfile
    }

    override func tearDownWithError() throws {
        guard passed, !createdProfiles.isEmpty else { return }
        connection.disconnect()
        profiles.open()
        profiles.switchTo(startingProfile)
        for name in createdProfiles {
            profiles.remove(name)
        }
    }

    /// A unique name for a profile this test creates, remembered for cleanup.
    func newProfileName() -> String {
        let name = ProfilesScreen.testProfilePrefix + String(UUID().uuidString.prefix(8)).lowercased()
        createdProfiles.append(name)
        return name
    }

    func markPassed() {
        passed = true
    }

    /// Runs a block as a named step, so the result shows the steps the way
    /// the test plan lists them.
    func step(_ name: String, _ block: () throws -> Void) rethrows {
        try XCTContext.runActivity(named: name) { _ in try block() }
    }

    /// A screenshot kept with the result whatever the outcome.
    func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Force-quits the app and launches it again, as a user swiping it away
    /// from the app switcher would.
    func relaunch() {
        app.terminate()
        app = AppLaunch.toMainScreen(app)
        profiles = ProfilesScreen(app: app)
        connection = ConnectionScreen(app: app)
    }

    /// Taps Connect and waits for the app to ask for an SSO login, accepting
    /// the VPN configuration prompt a first connect after an install shows.
    /// Returns whether the sign-in alert appeared; it is left on screen.
    @discardableResult
    func connectExpectingLogin(timeout: TimeInterval = 30) -> Bool {
        connection.tapToggle()
        let deadline = Date().addingTimeInterval(timeout)
        while !SignInAlert.isShowing && Date() < deadline {
            if (connection.toggle.value as? String) == "Connected" {
                return false
            }
            SystemAlerts.acceptIfPresent(timeout: 1)
        }
        return SignInAlert.isShowing
    }

    /// Skips a test that needs to connect: VPN configurations cannot be saved
    /// in the Simulator, so Connect does nothing there.
    func requireDevice() throws {
        if isSimulator {
            throw XCTSkip("connecting needs a physical device")
        }
    }

    var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    /// Removes test profiles a failed run left behind. An active profile
    /// cannot be removed, so a test profile that is still active is switched
    /// away from first — to "default", which always exists.
    private func removeLeftovers() {
        profiles.open()
        let leftovers = profiles.leftoverTestProfiles
        guard !leftovers.isEmpty else { return }

        step("Remove leftovers: \(leftovers.joined(separator: ", "))") {
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
