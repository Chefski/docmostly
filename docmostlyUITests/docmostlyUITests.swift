//
//  docmostlyUITests.swift
//  docmostlyUITests
//
//  Created by Patryk on 17/06/2026.
//

import XCTest

final class DocmostlyUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // Configure any required initial UI state before tests run.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // XCUIAutomation Documentation
        // https://developer.apple.com/documentation/xcuiautomation
    }

    @MainActor
    func testSettingsRowsOpenTheirDestinations() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-MainShellPreview", "-MainShellPreviewSettings"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))

        assertSettingsDestinationOpens("account", title: "Account", app: app)
        assertSettingsDestinationOpens("workspace", title: "Workspace", app: app)
        assertSettingsDestinationOpens("members", title: "Members", app: app)
        assertSettingsDestinationOpens("spaces", title: "Spaces", app: app)
        assertSettingsDestinationOpens("groups", title: "Groups", app: app)
    }

    @MainActor
    func testSpaceSettingsEntrySupportsNestedNavigation() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-MainShellPreview"]
        app.launch()

        let spaceActions = app.buttons["Space Actions"]
        XCTAssertTrue(spaceActions.waitForExistence(timeout: 5))
        spaceActions.tap()

        let spaceSettings = app.buttons["Space Settings"]
        XCTAssertTrue(spaceSettings.waitForExistence(timeout: 5))
        spaceSettings.tap()

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        assertSettingsDestinationOpens("account", title: "Account", app: app)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    @MainActor
    private func assertSettingsDestinationOpens(_ identifier: String, title: String, app: XCUIApplication) {
        let destination = app.buttons["SettingsDestination.\(identifier)"]
        XCTAssertTrue(destination.waitForExistence(timeout: 5))
        destination.tap()

        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
    }
}
