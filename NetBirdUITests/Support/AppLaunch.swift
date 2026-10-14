//
//  AppLaunch.swift
//  NetBirdUITests
//
//  Brings the unmodified app from a cold launch to its main screen, the way a
//  user would: answer the system prompts and pass the one-time onboarding.
//

import XCTest

enum AppLaunch {

    /// Launches the app and returns once the tab bar is on screen.
    @discardableResult
    static func toMainScreen(file: StaticString = #filePath, line: UInt = #line) -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()

        let tabBar = app.tabBars.firstMatch
        let onboardingContinue = app.buttons["Continue"]
        let deadline = Date().addingTimeInterval(30)

        // The notification prompt and the onboarding screen can appear in either
        // order, or not at all on a device that has run the app before.
        while !tabBar.exists && Date() < deadline {
            if SystemAlerts.acceptIfPresent() {
                continue
            }
            if onboardingContinue.exists && onboardingContinue.isHittable {
                onboardingContinue.tap()
                continue
            }
            _ = tabBar.waitForExistence(timeout: 1)
        }

        XCTAssertTrue(tabBar.exists, "the tab bar did not appear after launch", file: file, line: line)
        return app
    }
}

enum SystemAlerts {

    private static let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    /// Accepts a system alert owned by SpringBoard (notifications, VPN
    /// configuration) if one is showing. The accepting button is the last one
    /// in both, and matching by position keeps this independent of the
    /// device's language.
    @discardableResult
    static func acceptIfPresent(timeout: TimeInterval = 1) -> Bool {
        let alert = springboard.alerts.firstMatch
        guard alert.waitForExistence(timeout: timeout) else { return false }
        let buttons = alert.buttons
        guard buttons.count > 0 else { return false }
        buttons.element(boundBy: buttons.count - 1).tap()
        return true
    }
}
