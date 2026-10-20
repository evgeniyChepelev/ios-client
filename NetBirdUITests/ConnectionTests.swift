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
}
