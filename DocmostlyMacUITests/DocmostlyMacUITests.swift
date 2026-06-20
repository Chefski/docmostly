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

    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
