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
    func testPreviewShellOpensPageAndSwitchesMode() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-MainShellPreview"]
        app.launch()

        let roadmap = app.buttons["PageTreeNode.roadmap"]
        XCTAssertTrue(roadmap.waitForExistence(timeout: 5))
        roadmap.tap()

        let title = app.textFields["Page title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertEqual(title.value as? String, "Roadmap")

        let readMode = app.buttons["Read"]
        XCTAssertTrue(readMode.waitForExistence(timeout: 3))
        readMode.tap()
        XCTAssertFalse(title.isEnabled)

        let editMode = app.buttons["Edit"]
        XCTAssertTrue(editMode.waitForExistence(timeout: 3))
        editMode.tap()
        XCTAssertTrue(title.isEnabled)
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
    func testSpaceSettingsEntryShowsSpaceConfiguration() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-MainShellPreview"]
        app.launch()

        let spaceActions = app.buttons["Space Actions"]
        XCTAssertTrue(spaceActions.waitForExistence(timeout: 5))
        spaceActions.tap()

        let spaceSettings = app.buttons["Space Settings"]
        XCTAssertTrue(spaceSettings.waitForExistence(timeout: 5))
        spaceSettings.tap()

        XCTAssertTrue(app.navigationBars["Product"].waitForExistence(timeout: 5))

        let settingsTab = app.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))
        XCTAssertEqual(settingsTab.value as? String, "Selected")

        let membersTab = app.buttons["Members"]
        XCTAssertTrue(membersTab.waitForExistence(timeout: 5))
        membersTab.tap()
        XCTAssertEqual(membersTab.value as? String, "Selected")
        XCTAssertTrue(app.textFields["Search members"].waitForExistence(timeout: 5))
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
