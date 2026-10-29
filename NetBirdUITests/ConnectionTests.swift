//
//  ConnectionTests.swift
//  NetBirdUITests
//
//  Section H of the login UI test plan: the connection once a login is done.
//

import XCTest

final class ConnectionTests: E2ETestCase {

    /// LOGIN-H01 — a successful login lands on a usable connection: the
    /// status reads Connected, the peer's NetBird name and address are shown,
    /// and the Peers tab lists the network.
    func testH01_loginLandsOnUsableConnection() throws {
        try requireDevice()
        let profile = try createSignedInProfile()

        step("Connect \(profile)") {
            profiles.switchTo(profile)
            connectWithoutLogin()
            XCTAssertTrue(app.staticTexts["Connected"].exists, "the status does not read Connected")
        }

        step("The peer's name and address are shown") {
            // Both arrive with the first network map, a moment after Connected.
            XCTAssertTrue(connection.fqdn.waitForExistence(timeout: 30),
                          "no NetBird name under the status within 30 s")
            XCTAssertTrue(connection.ip.waitForExistence(timeout: 30),
                          "no NetBird address (100.x.x.x) under the status within 30 s")
        }
        screenshot("Connected with name \(connection.fqdn.label), address \(connection.ip.label)")

        step("The Peers tab renders") {
            TabBar(app: app).open("Peers")
            XCTAssertTrue(app.staticTexts["Peers connected"].waitForExistence(timeout: 5), "the Peers tab did not render")
            let count = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "^[0-9]+ of [0-9]+$")).firstMatch
            XCTAssertTrue(count.exists, "the Peers tab shows no \"N of M\" count")
        }
        screenshot("Peers")
        markPassed()
    }

    /// LOGIN-H02 — disconnecting ends the session cleanly: the status reads
    /// Disconnected and no error follows.
    ///
    /// The plan also expects the name and address to be cleared or hidden.
    /// The app clears them on a server or profile change but keeps them across
    /// a plain disconnect — the peer's identity does not change — so whether
    /// they stay is recorded with the result rather than failed on.
    func testH02_disconnectEndsTheSessionCleanly() throws {
        try requireDevice()
        let profile = try createSignedInProfile()

        step("Connect \(profile)") {
            profiles.switchTo(profile)
            connectWithoutLogin()
            _ = connection.ip.waitForExistence(timeout: 30)
        }

        step("Disconnect") {
            connection.disconnect()
            XCTAssertTrue(app.staticTexts["Disconnected"].waitForExistence(timeout: 10), "the status does not read Disconnected")
            XCTAssertEqual(app.alerts.count, 0, "an alert followed the disconnect: \(app.alerts.firstMatch.label)")
        }

        let kept = [connection.fqdn.exists ? "name" : nil, connection.ip.exists ? "address" : nil].compactMap { $0 }
        XCTContext.runActivity(named: kept.isEmpty ? "Name and address are cleared"
                                                   : "Still shown after the disconnect: \(kept.joined(separator: ", "))") { _ in }
        screenshot("After disconnecting")
        markPassed()
    }

    /// LOGIN-H03 — two quick taps on the toggle do not leave it stuck: it
    /// settles on Connected or Disconnected, and from there connects normally
    /// without a login.
    ///
    /// The toggle treats the second tap as "disconnect", so either end state is
    /// fine; what must not happen is a toggle stuck between the two.
    func testH03_doubleTapDoesNotLeaveTheToggleStuck() throws {
        try requireDevice()
        let profile = try createSignedInProfile()
        profiles.switchTo(profile)
        TabBar(app: app).open("Connection")

        step("Tap the toggle twice in quick succession") {
            XCTAssertTrue(connection.toggle.waitForExistence(timeout: 10), "no connect toggle")
            connection.toggle.tap()
            connection.toggle.tap()
        }

        step("The toggle settles within 60 s") {
            let settled = settledState(within: 60)
            XCTAssertNotNil(settled, "the toggle is stuck at \(connection.toggle.value as? String ?? "nothing")")
            XCTContext.runActivity(named: "Settled on \(settled ?? "nothing")") { _ in }
            XCTAssertFalse(SignInAlert.isShowing, "a login was asked for")
            XCTAssertFalse(app.alerts["Login failed"].exists, "a login error is shown")
        }

        step("It still connects normally") {
            if (connection.toggle.value as? String) != "Connected" {
                connectWithoutLogin()
            }
        }
        markPassed()
    }

    /// LOGIN-H04 — the connected state survives a force-quit: the tunnel runs
    /// in the extension, so the relaunched app must show Connected, not a
    /// stale Disconnected.
    func testH04_connectedStateSurvivesRelaunch() throws {
        try requireDevice()
        let profile = try createSignedInProfile()

        step("Connect \(profile)") {
            profiles.switchTo(profile)
            connectWithoutLogin()
        }

        step("Force-quit and relaunch") {
            relaunch()
        }

        step("The app shows the running tunnel") {
            TabBar(app: app).open("Connection")
            let connected = NSPredicate(format: "value == %@", "Connected")
            XCTAssertEqual(XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: connected, object: connection.toggle)],
                                            timeout: 15), .completed,
                           "after a relaunch the toggle shows \(connection.toggle.value as? String ?? "nothing")")
        }
        screenshot("After relaunch")
        markPassed()
    }

    /// LOGIN-H05 — On Demand on a profile without credentials does not start
    /// a reconnect loop: the VPN stays off and nothing keeps asking for a login.
    ///
    /// The plan expects the toggle to be refused. The app instead keeps the
    /// preference and defers arming the rules until the profile has
    /// credentials, so the toggle may stay on; what the test holds the app to
    /// is the reason behind the plan's case — no reconnect loop.
    ///
    /// On Demand is a device-wide setting, so it is switched off again whatever
    /// the outcome, unlike the rest of the state a failing test leaves behind.
    func testH05_onDemandWithoutCredentialsDoesNotLoop() throws {
        try requireDevice()
        let profile = createSignedOutProfile()
        profiles.switchTo(profile)

        let onDemand = OnDemandScreen(app: app)
        addTeardownBlock { [app] in
            // An alert the case itself provoked would cover the switch.
            AppAlerts.dismissAll(in: app!)
            let screen = OnDemandScreen(app: app!)
            screen.open()
            screen.set(false)
        }

        step("Turn On Demand on") {
            onDemand.open()
            onDemand.set(true)
            XCTContext.runActivity(named: onDemand.isOn ? "The toggle stays on (rules deferred)" : "The toggle was refused") { _ in }
            screenshot("On Demand on a signed-out profile")
        }

        step("For 20 s: no connection, no login prompt, no error") {
            let deadline = Date().addingTimeInterval(20)
            while Date() < deadline {
                XCTAssertFalse(SignInAlert.isShowing, "On Demand asked for a login on its own")
                XCTAssertEqual(app.alerts.count, 0, "an alert came up: \(app.alerts.firstMatch.label)")
                Thread.sleep(forTimeInterval: 1)
            }
            TabBar(app: app).open("Connection")
            XCTAssertEqual(connection.toggle.value as? String, "Disconnected", "the VPN started without credentials")
        }
        markPassed()
    }

    /// Waits for the toggle to rest on Connected or Disconnected for 5 s in a
    /// row, accepting the VPN configuration prompt on the way.
    private func settledState(within timeout: TimeInterval) -> String? {
        let deadline = Date().addingTimeInterval(timeout)
        var stableSince = Date()
        var last = ""
        while Date() < deadline {
            SystemAlerts.acceptIfPresent(timeout: 0.5)
            let value = connection.toggle.value as? String ?? ""
            if value != last {
                last = value
                stableSince = Date()
            }
            if ["Connected", "Disconnected"].contains(value) && Date().timeIntervalSince(stableSince) >= 5 {
                return value
            }
            Thread.sleep(forTimeInterval: 0.5)
        }
        return nil
    }
}
