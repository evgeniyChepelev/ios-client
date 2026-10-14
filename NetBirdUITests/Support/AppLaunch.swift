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

    /// The accepting button of the prompts the app triggers (notifications,
    /// VPN configuration), in the languages a test device is likely to use.
    private static let acceptLabels: Set<String> = ["Allow", "OK", "Разрешить", "Дозволити"]

    /// Accepts a system alert owned by SpringBoard if one is showing. Matches
    /// the button by label first, since its position differs between prompts
    /// (Allow is on the left in the VPN prompt and on the right in the
    /// notification one); falls back to the last button for an unknown
    /// language.
    @discardableResult
    static func acceptIfPresent(timeout: TimeInterval = 1) -> Bool {
        let alert = springboard.alerts.firstMatch
        guard alert.waitForExistence(timeout: timeout) else { return false }
        let buttons = alert.buttons.allElementsBoundByIndex
        guard let button = buttons.first(where: { acceptLabels.contains($0.label) }) ?? buttons.last else {
            return false
        }
        button.tap()
        return true
    }
}
