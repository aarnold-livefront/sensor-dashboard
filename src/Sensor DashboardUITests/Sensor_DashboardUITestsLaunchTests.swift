//
//  Sensor_DashboardUITestsLaunchTests.swift
//  Sensor DashboardUITests
//
//  Created by Annalise Arnold on 9/5/25.
//

import XCTest

final class Sensor_DashboardUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Verify all main UI elements are present on launch
        XCTAssertTrue(app.buttons["START"].exists, "START button should be visible on launch")
        XCTAssertTrue(app.staticTexts["G-FORCE"].exists, "G-FORCE label should be visible on launch")
        XCTAssertTrue(app.staticTexts["PITCH"].exists, "PITCH label should be visible on launch")
        XCTAssertTrue(app.staticTexts["ROLL"].exists, "ROLL label should be visible on launch")

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testLaunchWithSensorStart() throws {
        let app = XCUIApplication()
        app.launch()

        // Start sensors and take screenshot
        app.buttons["START"].tap()

        // Wait for sensors to initialize
        let stopButton = app.buttons["STOP"]
        XCTAssertTrue(stopButton.waitForExistence(timeout: 2), "Sensors should start")

        sleep(1)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Sensors Running Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testLaunchWithCalibration() throws {
        let app = XCUIApplication()
        app.launch()

        // Start sensors (which triggers calibration)
        app.buttons["START"].tap()

        // Capture screenshot during calibration/initial state
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Calibration Screen"
        attachment.lifetime = .keepAlways
        add(attachment)

        // Wait for calibration to complete
        let stopButton = app.buttons["STOP"]
        XCTAssertTrue(stopButton.waitForExistence(timeout: 3), "Calibration should complete")
    }
}
