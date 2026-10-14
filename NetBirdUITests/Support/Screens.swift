//
//  Screens.swift
//  NetBirdUITests
//
//  The app's screens as a test drives them. Elements are found by what a user
//  sees — tab names, button titles, screen titles — because the tests run
//  against the unmodified app.
//

import XCTest

/// Values the CI passes in through the test runner's environment
/// (TEST_RUNNER_<NAME> on the xcodebuild command line).
enum TestSecrets {
    static func value(_ name: String, file: StaticString = #filePath, line: UInt = #line) throws -> String {
        let value = ProcessInfo.processInfo.environment[name] ?? ""
        return try XCTUnwrap(value.isEmpty ? nil : value, "\(name) is not set for this run", file: file, line: line)
    }
}

struct TabBar {
    let app: XCUIApplication

    func open(_ name: String) {
        let button = app.tabBars.firstMatch.buttons[name]
        XCTAssertTrue(button.waitForExistence(timeout: 5), "no \(name) tab")
        button.tap()
    }
}

struct ConnectionScreen {
    let app: XCUIApplication

    /// The connect/disconnect toggle; its value is the connection state.
    var toggle: XCUIElement {
        app.descendants(matching: .any)["VPN Connection"]
    }

    func connect(timeout: TimeInterval = 60) {
        TabBar(app: app).open("Connection")
        XCTAssertTrue(toggle.waitForExistence(timeout: 10), "no connect toggle")
        toggle.tap()
        waitForState("Connected", timeout: timeout, acceptingPrompts: true)
    }

    func disconnect(timeout: TimeInterval = 30) {
        TabBar(app: app).open("Connection")
        guard (toggle.value as? String) != "Disconnected" else { return }
        toggle.tap()
        waitForState("Disconnected", timeout: timeout, acceptingPrompts: false)
    }

    /// Waits for the toggle to report a state. The first connect after an
    /// install asks to add the VPN configuration; that prompt is accepted
    /// while waiting.
    private func waitForState(_ state: String, timeout: TimeInterval, acceptingPrompts: Bool) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if (toggle.value as? String) == state {
                return
            }
            if acceptingPrompts && SystemAlerts.acceptIfPresent(timeout: 0.5) {
                continue
            }
            Thread.sleep(forTimeInterval: 1)
        }
        XCTFail("the connection did not reach \(state) within \(Int(timeout)) s, it shows \(toggle.value as? String ?? "nothing")")
    }
}

struct ProfilesScreen {
    let app: XCUIApplication

    static let testProfilePrefix = "e2e-"

    /// Opens Settings → Profiles.
    @discardableResult
    func open() -> ProfilesScreen {
        if app.navigationBars["Profiles"].exists {
            return self
        }
        TabBar(app: app).open("Settings")
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Profiles'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "no Profiles row in Settings")
        row.tap()
        XCTAssertTrue(app.navigationBars["Profiles"].waitForExistence(timeout: 5), "the Profiles screen did not open")
        return self
    }

    /// The row of a profile that is not the active one.
    func row(_ name: String) -> XCUIElement {
        app.cells.containing(.staticText, identifier: name).firstMatch
    }

    var activeProfileName: String? {
        // The Active section holds a single row: the name and a green "Active" badge.
        let badge = app.staticTexts["Active"].firstMatch
        guard badge.exists else { return nil }
        let cell = app.cells.containing(.staticText, identifier: "Active").firstMatch
        return cell.staticTexts.allElementsBoundByIndex.map(\.label).first { $0 != "Active" }
    }

    /// Creates a profile on the default server (NetBird Cloud) and logs it in
    /// with a setup key, through the New Profile sheet.
    func create(_ name: String, setupKey: String, timeout: TimeInterval = 60) {
        let add = app.navigationBars["Profiles"].buttons["Add"]
        XCTAssertTrue(add.waitForExistence(timeout: 5), "no add button on the Profiles screen")
        add.tap()

        let sheet = app.navigationBars["New Profile"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 5), "the New Profile sheet did not open")

        let nameField = textField(placeholder: "Profile name")
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "no profile name field")
        nameField.tap()
        nameField.typeText(name)

        app.buttons["Add this device with a setup key"].tap()
        // The placeholder is an example key; it is the only stable handle the field has.
        let keyField = textField(placeholder: "0EF79C2F-DEE1-419B-BFC8-1BF529332998")
        XCTAssertTrue(keyField.waitForExistence(timeout: 5), "the setup key field did not appear")
        keyField.tap()
        keyField.typeText(setupKey)

        sheet.buttons["Create"].tap()

        // The sheet closes itself once the server accepted the key; on an
        // error it stays open with the message under the field.
        let closed = NSPredicate(format: "exists == false")
        let result = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: closed, object: sheet)], timeout: timeout)
        if result != .completed {
            let errors = app.staticTexts.allElementsBoundByIndex.map(\.label).filter { !$0.isEmpty }
            XCTFail("the profile was not created within \(Int(timeout)) s; the sheet shows: \(errors.joined(separator: " | "))")
        }
        XCTAssertTrue(row(name).waitForExistence(timeout: 5), "\(name) is not in the profile list")
    }

    func switchTo(_ name: String) {
        let target = row(name)
        XCTAssertTrue(target.waitForExistence(timeout: 5), "no \(name) profile")
        target.tap()
        let alert = app.alerts["Switch Profile"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "no Switch Profile confirmation")
        alert.buttons["Switch"].tap()
        XCTAssertTrue(app.cells.containing(.staticText, identifier: name).containing(.staticText, identifier: "Active").firstMatch
            .waitForExistence(timeout: 10), "\(name) did not become the active profile")
    }

    func remove(_ name: String) {
        let target = row(name)
        guard target.waitForExistence(timeout: 2) else { return }
        target.swipeLeft()
        let remove = app.buttons["Remove"]
        XCTAssertTrue(remove.waitForExistence(timeout: 3), "no Remove action on \(name)")
        remove.tap()
        let alert = app.alerts["Remove Profile"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "no Remove Profile confirmation")
        alert.buttons["Remove"].tap()
        let gone = NSPredicate(format: "exists == false")
        _ = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: gone, object: target)], timeout: 5)
    }

    private func textField(placeholder: String) -> XCUIElement {
        app.textFields.matching(NSPredicate(format: "placeholderValue == %@", placeholder)).firstMatch
    }

    /// Profiles the earlier runs left behind, for instance after a failure.
    var leftoverTestProfiles: [String] {
        app.staticTexts.allElementsBoundByIndex
            .map(\.label)
            .filter { $0.hasPrefix(Self.testProfilePrefix) }
    }
}
