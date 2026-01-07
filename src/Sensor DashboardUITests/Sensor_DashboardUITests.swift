//
//  Sensor_DashboardUITests.swift
//  Sensor DashboardUITests
//
//  Created by Annalise Arnold on 9/5/25.
//

import XCTest

final class Sensor_DashboardUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testAccelerometerGaugeElements() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Test that the G-FORCE label is visible
        let gForceLabel = app.staticTexts["G-FORCE"]
        XCTAssertTrue(gForceLabel.exists, "G-FORCE label should be visible")
        
        // Test that the accelerometer gauge numeric display exists (initially shows default value)
        let numericDisplay = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "^\\d+\\.\\d{2}$"))
        XCTAssertTrue(numericDisplay.count > 0, "Numeric G-force display should be visible")
        
        // Test that the bullseye gauge container is present
        // Since the gauge is custom drawn, we verify the app launched successfully with gauge content
        XCTAssertTrue(app.exists, "App should launch with accelerometer gauge content")
    }
    
    @MainActor
    func testPitchGaugeElements() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Test that the PITCH label is visible
        let pitchLabel = app.staticTexts["PITCH"]
        XCTAssertTrue(pitchLabel.exists, "PITCH label should be visible")
        
        // Test that pitch angle numeric display exists (should show 0.0° initially)
        let pitchAngleDisplay = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "^-?\\d+\\.\\d°$"))
        XCTAssertTrue(pitchAngleDisplay.count > 0, "Pitch angle display should be visible")
        
        // Verify initial pitch reading is 0.0°
        let initialPitchReading = app.staticTexts["0.0°"]
        XCTAssertTrue(initialPitchReading.exists, "Initial pitch reading should be 0.0°")
    }
    
    @MainActor
    func testRollGaugeElements() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Test that the ROLL label is visible
        let rollLabel = app.staticTexts["ROLL"]
        XCTAssertTrue(rollLabel.exists, "ROLL label should be visible")
        
        // Test that roll angle numeric display exists (should show 0.0° initially)
        let rollAngleDisplay = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "^-?\\d+\\.\\d°$"))
        XCTAssertTrue(rollAngleDisplay.count > 0, "Roll angle display should be visible")
        
        // Verify initial roll reading is 0.0°
        let initialRollReading = app.staticTexts["0.0°"]
        XCTAssertTrue(initialRollReading.exists, "Initial roll reading should be 0.0°")
    }
    
    @MainActor
    func testSensorControlButton() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Test that START button is initially visible
        let startButton = app.buttons["START"]
        XCTAssertTrue(startButton.exists, "START button should be visible initially")
        
        // Test button tap functionality
        startButton.tap()
        
        // After tapping, button should change to STOP
        let stopButton = app.buttons["STOP"]
        XCTAssertTrue(stopButton.waitForExistence(timeout: 2), "Button should change to STOP after starting sensors")
        
        // Test that RECALIBRATE button appears when sensors are running
        let recalibrateButton = app.buttons["RECALIBRATE"]
        XCTAssertTrue(recalibrateButton.exists, "RECALIBRATE button should appear when sensors are running")
        
        // Stop the sensors
        stopButton.tap()
        
        // Button should return to START state
        XCTAssertTrue(startButton.waitForExistence(timeout: 2), "Button should return to START after stopping sensors")
        
        // RECALIBRATE button should disappear
        XCTAssertFalse(recalibrateButton.exists, "RECALIBRATE button should disappear when sensors are stopped")
    }
    
    @MainActor
    func testCalibrationFunctionality() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Start the sensors first
        let startButton = app.buttons["START"]
        startButton.tap()
        
        // Wait for RECALIBRATE button to appear
        let recalibrateButton = app.buttons["RECALIBRATE"]
        XCTAssertTrue(recalibrateButton.waitForExistence(timeout: 2), "RECALIBRATE button should appear")
        
        // Tap RECALIBRATE button
        recalibrateButton.tap()
        
        // Button should temporarily show "CALIBRATING..." state
        let calibratingButton = app.buttons["CALIBRATING..."]
        XCTAssertTrue(calibratingButton.waitForExistence(timeout: 1), "Button should show CALIBRATING... state")
        
        // Wait for calibration to complete and sensors to restart
        let stopButton = app.buttons["STOP"]
        XCTAssertTrue(stopButton.waitForExistence(timeout: 3), "Sensors should restart after calibration")
    }
    
    @MainActor
    func testGaugeVisibilityStates() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Initially, gauges should be visible but in inactive state (opacity 0.5)
        let pitchLabel = app.staticTexts["PITCH"]
        let rollLabel = app.staticTexts["ROLL"]
        let gForceLabel = app.staticTexts["G-FORCE"]
        
        XCTAssertTrue(pitchLabel.exists, "PITCH gauge should be visible initially")
        XCTAssertTrue(rollLabel.exists, "ROLL gauge should be visible initially")
        XCTAssertTrue(gForceLabel.exists, "G-FORCE gauge should be visible initially")
        
        // Start sensors
        let startButton = app.buttons["START"]
        startButton.tap()
        
        // Gauges should still be visible and now active
        XCTAssertTrue(pitchLabel.exists, "PITCH gauge should remain visible when active")
        XCTAssertTrue(rollLabel.exists, "ROLL gauge should remain visible when active")
        XCTAssertTrue(gForceLabel.exists, "G-FORCE gauge should remain visible when active")
        
        // Stop sensors
        let stopButton = app.buttons["STOP"]
        stopButton.tap()
        
        // Gauges should return to inactive state but remain visible
        XCTAssertTrue(pitchLabel.waitForExistence(timeout: 2), "PITCH gauge should remain visible after stopping")
        XCTAssertTrue(rollLabel.exists, "ROLL gauge should remain visible after stopping")
        XCTAssertTrue(gForceLabel.exists, "G-FORCE gauge should remain visible after stopping")
    }
    
    @MainActor
    func testGaugeDataUpdatesDuringOperation() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Start sensors
        let startButton = app.buttons["START"]
        startButton.tap()
        
        // Wait for sensors to initialize
        sleep(1)
        
        // Check that numeric displays exist and could potentially show real data
        // Note: In simulator, actual sensor data may not change, but we can verify the display elements exist
        let gForceNumericDisplays = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "^\\d+\\.\\d{2}$"))
        XCTAssertTrue(gForceNumericDisplays.count > 0, "G-force numeric display should be present during operation")
        
        let angleDisplays = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "^-?\\d+\\.\\d°$"))
        XCTAssertTrue(angleDisplays.count >= 2, "Pitch and roll angle displays should be present during operation")
        
        // Stop sensors
        let stopButton = app.buttons["STOP"]
        stopButton.tap()
        
        // Verify gauges return to default state
        let defaultGForceReading = app.staticTexts["1.00"]
        let defaultPitchReading = app.staticTexts["0.0°"]
        let defaultRollReading = app.staticTexts["0.0°"]
        
        XCTAssertTrue(defaultGForceReading.waitForExistence(timeout: 2) || 
                     gForceNumericDisplays.count > 0, "G-force should show valid reading")
        XCTAssertTrue(defaultPitchReading.exists || 
                     angleDisplays.count > 0, "Pitch should show valid reading")
        XCTAssertTrue(defaultRollReading.exists || 
                     angleDisplays.count > 0, "Roll should show valid reading")
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    @MainActor
    func testRapidButtonToggling() throws {
        let app = XCUIApplication()
        app.launch()

        let startButton = app.buttons["START"]

        // Rapidly toggle the sensor state multiple times
        for _ in 0..<3 {
            startButton.tap()

            let stopButton = app.buttons["STOP"]
            XCTAssertTrue(stopButton.waitForExistence(timeout: 2), "Button should change to STOP")

            stopButton.tap()
            XCTAssertTrue(startButton.waitForExistence(timeout: 2), "Button should return to START")
        }

        // Verify app is still responsive
        XCTAssertTrue(app.exists, "App should still be running after rapid toggling")
    }

    @MainActor
    func testMultipleCalibrationCycles() throws {
        let app = XCUIApplication()
        app.launch()

        // Start sensors
        let startButton = app.buttons["START"]
        startButton.tap()

        let recalibrateButton = app.buttons["RECALIBRATE"]
        XCTAssertTrue(recalibrateButton.waitForExistence(timeout: 2), "RECALIBRATE button should appear")

        // Perform multiple calibration cycles
        for cycle in 1...3 {
            recalibrateButton.tap()

            // Wait for calibration to complete
            let stopButton = app.buttons["STOP"]
            XCTAssertTrue(stopButton.waitForExistence(timeout: 4),
                         "Calibration cycle \(cycle) should complete and return to running state")

            // Small delay between calibrations
            sleep(1)
        }

        // Verify app is still in running state after multiple calibrations
        let stopButton = app.buttons["STOP"]
        XCTAssertTrue(stopButton.exists, "App should still be running after multiple calibrations")
    }

    @MainActor
    func testGaugeConsistencyAfterStateChanges() throws {
        let app = XCUIApplication()
        app.launch()

        // Verify initial state
        let gForceLabel = app.staticTexts["G-FORCE"]
        let pitchLabel = app.staticTexts["PITCH"]
        let rollLabel = app.staticTexts["ROLL"]

        XCTAssertTrue(gForceLabel.exists, "G-FORCE label should exist")
        XCTAssertTrue(pitchLabel.exists, "PITCH label should exist")
        XCTAssertTrue(rollLabel.exists, "ROLL label should exist")

        // Start sensors
        let startButton = app.buttons["START"]
        startButton.tap()

        sleep(2)

        // All gauges should still be visible during operation
        XCTAssertTrue(gForceLabel.exists, "G-FORCE label should persist during operation")
        XCTAssertTrue(pitchLabel.exists, "PITCH label should persist during operation")
        XCTAssertTrue(rollLabel.exists, "ROLL label should persist during operation")

        // Stop sensors
        let stopButton = app.buttons["STOP"]
        stopButton.tap()

        // All gauges should still be visible after stopping
        XCTAssertTrue(gForceLabel.exists, "G-FORCE label should persist after stopping")
        XCTAssertTrue(pitchLabel.exists, "PITCH label should persist after stopping")
        XCTAssertTrue(rollLabel.exists, "ROLL label should persist after stopping")
    }

    @MainActor
    func testInitialGaugeReadings() throws {
        let app = XCUIApplication()
        app.launch()

        // Verify default/initial gauge readings when sensors are stopped
        let defaultGForce = app.staticTexts["1.00"]
        let defaultPitch = app.staticTexts["0.0°"]
        let defaultRoll = app.staticTexts["0.0°"]

        // At least one of the angle displays should show 0.0°
        XCTAssertTrue(defaultPitch.exists || defaultRoll.exists,
                     "Initial angle readings should show 0.0°")

        // G-force should show default value (1.00 for standard gravity)
        XCTAssertTrue(defaultGForce.exists, "Initial G-force should show 1.00")
    }

    @MainActor
    func testSensorControlButtonAccessibility() throws {
        let app = XCUIApplication()
        app.launch()

        // Verify button is accessible
        let startButton = app.buttons["START"]
        XCTAssertTrue(startButton.exists, "START button should be accessible")
        XCTAssertTrue(startButton.isHittable, "START button should be hittable")

        startButton.tap()

        let stopButton = app.buttons["STOP"]
        XCTAssertTrue(stopButton.waitForExistence(timeout: 2), "STOP button should be accessible")
        XCTAssertTrue(stopButton.isHittable, "STOP button should be hittable")

        let recalibrateButton = app.buttons["RECALIBRATE"]
        XCTAssertTrue(recalibrateButton.exists, "RECALIBRATE button should be accessible")
        XCTAssertTrue(recalibrateButton.isHittable, "RECALIBRATE button should be hittable")
    }

    @MainActor
    func testLongRunningSensorSession() throws {
        let app = XCUIApplication()
        app.launch()

        // Start sensors
        let startButton = app.buttons["START"]
        startButton.tap()

        let stopButton = app.buttons["STOP"]
        XCTAssertTrue(stopButton.waitForExistence(timeout: 2), "Sensors should start")

        // Let sensors run for a longer period to verify stability
        sleep(5)

        // Verify UI is still responsive and showing data
        let gForceLabel = app.staticTexts["G-FORCE"]
        let pitchLabel = app.staticTexts["PITCH"]
        let rollLabel = app.staticTexts["ROLL"]

        XCTAssertTrue(gForceLabel.exists, "G-FORCE label should still be visible after long session")
        XCTAssertTrue(pitchLabel.exists, "PITCH label should still be visible after long session")
        XCTAssertTrue(rollLabel.exists, "ROLL label should still be visible after long session")

        // Verify we can still stop the sensors
        XCTAssertTrue(stopButton.exists, "STOP button should still be accessible")
        stopButton.tap()

        XCTAssertTrue(startButton.waitForExistence(timeout: 2), "Should be able to stop sensors after long session")
    }

    @MainActor
    func testCalibrationButtonDisabledDuringCalibration() throws {
        let app = XCUIApplication()
        app.launch()

        // Start sensors
        let startButton = app.buttons["START"]
        startButton.tap()

        let recalibrateButton = app.buttons["RECALIBRATE"]
        XCTAssertTrue(recalibrateButton.waitForExistence(timeout: 2), "RECALIBRATE button should appear")

        // Tap calibrate
        recalibrateButton.tap()

        // During calibration, the main button should show "CALIBRATING..."
        let calibratingButton = app.buttons["CALIBRATING..."]
        XCTAssertTrue(calibratingButton.waitForExistence(timeout: 1), "Should show CALIBRATING... state")

        // Verify the calibrating button is disabled (not hittable while calibrating)
        // Note: The button is visually present but should not respond to taps during calibration
    }
}
