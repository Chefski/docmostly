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
        let spacePicker = app.buttons["SpacePicker"]

        XCTAssertTrue(spacePicker.waitForExistence(timeout: 5))
        XCTAssertEqual(spacePicker.label, "Product")
        XCTAssertTrue(app.buttons["PageOpenLink.roadmap"].waitForExistence(timeout: 5))

        app.buttons["Search"].click()
        XCTAssertTrue(app.staticTexts["Search"].waitForExistence(timeout: 5))

        spacePicker.click()
        XCTAssertTrue(app.menuItems["Engineering"].waitForExistence(timeout: 5))
        app.menuItems["Engineering"].click()
        XCTAssertTrue(app.buttons["PageOpenLink.architecture"].waitForExistence(timeout: 5))
    }

    func testPreviewShellSelectsPageIntoDetailColumn() throws {
        let app = launchMainShellPreview()

        XCTAssertTrue(app.buttons["PageOpenLink.roadmap"].waitForExistence(timeout: 5))
        app.buttons["PageOpenLink.roadmap"].click()

        XCTAssertTrue(app.textFields["Page title"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["Page title"].value as? String, "Roadmap")
        XCTAssertTrue(app.textViews["Paragraph"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textViews["Paragraph"].value as? String, "Roadmap native preview content")
    }

    func testPreviewShellCanSwitchSpacesAfterOpeningOverviewPage() throws {
        let app = launchMainShellPreview()

        XCTAssertTrue(app.buttons["PageOpenLink.roadmap"].waitForExistence(timeout: 5))
        app.buttons["PageOpenLink.roadmap"].click()
        XCTAssertTrue(app.textFields["Page title"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["Page title"].value as? String, "Roadmap")

        app.buttons["SpacePicker"].click()
        XCTAssertTrue(app.menuItems["Engineering"].waitForExistence(timeout: 5))
        app.menuItems["Engineering"].click()

        XCTAssertTrue(app.buttons["PageOpenLink.architecture"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.images["Warning"].exists)

        app.buttons["PageOpenLink.architecture"].click()
        XCTAssertTrue(app.textFields["Page title"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["Page title"].value as? String, "Architecture")
        XCTAssertTrue(app.textViews["Paragraph"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textViews["Paragraph"].value as? String, "Architecture native preview content")
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
