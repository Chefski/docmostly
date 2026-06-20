//
//  DocmostlyMacUITests.swift
//  DocmostlyMacUITests
//
//  Created by Patryk on 20/06/2026.
//

import XCTest

@MainActor
final class DocmostlyMacUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunchesMainWindow() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }

    func testPreviewShellSwitchesSidebarDestinations() throws {
        let app = launchMainShellPreview()

        XCTAssertTrue(app.buttons["Product"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Roadmap"].waitForExistence(timeout: 5))

        app.buttons["Search"].click()
        XCTAssertTrue(app.staticTexts["Search"].waitForExistence(timeout: 5))

        app.buttons["Engineering"].click()
        XCTAssertTrue(app.buttons["Architecture"].waitForExistence(timeout: 5))
    }

    func testPreviewShellSelectsPageIntoDetailColumn() throws {
        let app = launchMainShellPreview()

        XCTAssertTrue(app.buttons["Roadmap"].waitForExistence(timeout: 5))
        app.buttons["Roadmap"].click()

        XCTAssertTrue(app.textFields["Page title"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["Page title"].value as? String, "Roadmap")
        XCTAssertTrue(app.staticTexts["Roadmap native preview content"].waitForExistence(timeout: 5))
    }

    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    private func launchMainShellPreview() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-MainShellPreview"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        return app
    }
}
