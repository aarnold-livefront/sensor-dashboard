//
//  Sensor_DashboardTests.swift
//  Sensor DashboardTests
//
//  Created by Annalise Arnold on 9/5/25.
//

import Testing
import CoreMotion
@testable import Sensor_Dashboard

// MARK: - MotionManager Tests
struct MotionManagerTests {

    @Test("MotionManager initializes in stopped state")
    func initialStateIsStopped() {
        let manager = MotionManager()
        #expect(manager.sensorState == .stopped)
        #expect(manager.currentPitch == 0.0)
        #expect(manager.currentRoll == 0.0)
        #expect(manager.trailPoints.isEmpty)
        #expect(manager.accelerometerData == nil)
    }

    @Test("Trail time limit is correctly set")
    func trailTimeLimitIsCorrect() {
        let manager = MotionManager()
        #expect(manager.trailTimeLimit == 3.5)
    }

    @Test("Radians to degrees conversion is accurate")
    func radiansToDegreesConversion() {
        let manager = MotionManager()

        // Test common angles
        #expect(manager.radiansToDegrees(0) == 0.0)
        #expect(abs(manager.radiansToDegrees(.pi) - 180.0) < 0.001)
        #expect(abs(manager.radiansToDegrees(.pi / 2) - 90.0) < 0.001)
        #expect(abs(manager.radiansToDegrees(.pi / 4) - 45.0) < 0.001)
        #expect(abs(manager.radiansToDegrees(-.pi) - (-180.0)) < 0.001)
    }

    @Test("Pitch angle calculation from quaternion")
    func pitchAngleFromQuaternion() {
        let manager = MotionManager()

        // Test zero rotation quaternion (identity)
        let identityQuaternion = CMQuaternion(x: 0, y: 0, z: 0, w: 1)
        let pitchIdentity = manager.calculatePitchAngleFromQuaternion(identityQuaternion)
        #expect(abs(pitchIdentity) < 0.1) // Should be close to 0

        // Test various quaternion configurations
        let forwardTilt = CMQuaternion(x: 0.1, y: 0, z: 0, w: 0.995)
        let pitchForward = manager.calculatePitchAngleFromQuaternion(forwardTilt)
        #expect(pitchForward > 0) // Forward tilt should be positive
    }

    @Test("Lateral roll angle calculation")
    func lateralRollAngleCalculation() {
        let manager = MotionManager()

        // Test level position (no roll)
        let levelGravity = CMAcceleration(x: 0.0, y: 0.0, z: -1.0)
        let rollLevel = manager.calculateLateralRollAngle(from: levelGravity)
        #expect(abs(rollLevel) < 0.1) // Should be close to 0

        // Test right tilt (positive x)
        let rightTilt = CMAcceleration(x: 0.5, y: 0.0, z: -0.866) // ~30 degrees
        let rollRight = manager.calculateLateralRollAngle(from: rightTilt)
        #expect(rollRight > 20 && rollRight < 35) // Should be around 30 degrees

        // Test left tilt (negative x)
        let leftTilt = CMAcceleration(x: -0.5, y: 0.0, z: -0.866)
        let rollLeft = manager.calculateLateralRollAngle(from: leftTilt)
        #expect(rollLeft < -20 && rollLeft > -35) // Should be around -30 degrees

        // Test edge case: very small vertical magnitude
        let edgeCase = CMAcceleration(x: 0.001, y: 0.001, z: 0.001)
        let rollEdge = manager.calculateLateralRollAngle(from: edgeCase)
        #expect(rollEdge == 0.0) // Should return 0 for very small magnitudes
    }

    @Test("Stop sensor resets state correctly")
    func stopSensorResetsState() {
        let manager = MotionManager()

        // Simulate some state changes (without actually starting sensors)
        manager.sensorState = .running

        manager.stopSensor()

        #expect(manager.sensorState == .stopped)
        #expect(manager.accelerometerData == nil)
        #expect(manager.trailPoints.isEmpty)
        #expect(manager.currentPitch == 0.0)
        #expect(manager.currentRoll == 0.0)
    }
}

// MARK: - Data Structure Tests
struct DataStructureTests {

    @Test("TrailPoint has unique identifiers")
    func trailPointUniqueIdentifiers() {
        let point1 = TrailPoint(x: 1.0, y: 2.0, timestamp: Date())
        let point2 = TrailPoint(x: 1.0, y: 2.0, timestamp: Date())

        #expect(point1.id != point2.id)
    }

    @Test("TrailPoint stores coordinates correctly")
    func trailPointCoordinates() {
        let x = 1.5
        let y = -2.3
        let timestamp = Date()
        let point = TrailPoint(x: x, y: y, timestamp: timestamp)

        #expect(point.x == x)
        #expect(point.y == y)
        #expect(point.timestamp == timestamp)
    }

    @Test("AdjustedAccelerometerData applies offset correctly")
    func adjustedDataAppliesOffset() {
        let rawAcceleration = CMAcceleration(x: 1.0, y: 2.0, z: 3.0)
        let offset = CMAcceleration(x: 0.1, y: 0.2, z: 0.3)
        let mockData = MockAccelerometerData(acceleration: rawAcceleration, timestamp: 1000.0)

        let adjustedData = AdjustedAccelerometerData(from: mockData, offset: offset)

        #expect(abs(adjustedData.acceleration.x - 0.9) < 0.001)
        #expect(abs(adjustedData.acceleration.y - 1.8) < 0.001)
        #expect(abs(adjustedData.acceleration.z - 2.7) < 0.001)
        #expect(adjustedData.timestamp == 1000.0)
    }

    @Test("AdjustedAccelerometerData uses smoothed values when provided")
    func adjustedDataUsesSmoothedValues() {
        let rawAcceleration = CMAcceleration(x: 1.0, y: 2.0, z: 3.0)
        let smoothedAcceleration = CMAcceleration(x: 0.5, y: 1.0, z: 1.5)
        let offset = CMAcceleration(x: 0.0, y: 0.0, z: 0.0)
        let mockData = MockAccelerometerData(acceleration: rawAcceleration, timestamp: 1000.0)

        let adjustedData = AdjustedAccelerometerData(from: mockData, offset: offset, smoothed: smoothedAcceleration)

        #expect(adjustedData.acceleration.x == 0.5)
        #expect(adjustedData.acceleration.y == 1.0)
        #expect(adjustedData.acceleration.z == 1.5)
    }

    @Test("SensorState enum cases")
    func sensorStateEnumCases() {
        let stopped = SensorState.stopped
        let running = SensorState.running
        let calibrating = SensorState.calibrating

        #expect(stopped != running)
        #expect(running != calibrating)
        #expect(calibrating != stopped)
    }
}

// MARK: - Gauge Calculation Tests
struct GaugeCalculationTests {

    @Test("BullseyeAccelerometerGauge magnitude calculation")
    func magnitudeCalculation() {
        let gauge = BullseyeAccelerometerGauge(
            x: 3.0,
            y: 4.0,
            z: 0.0,
            trailPoints: [],
            trailTimeLimit: 3.5
        )

        // 3-4-5 triangle: sqrt(9 + 16 + 0) = 5
        #expect(gauge.magnitude == 5.0)
    }

    @Test("BullseyeAccelerometerGauge magnitude for zero acceleration")
    func magnitudeZero() {
        let gauge = BullseyeAccelerometerGauge(
            x: 0.0,
            y: 0.0,
            z: 0.0,
            trailPoints: [],
            trailTimeLimit: 3.5
        )

        #expect(gauge.magnitude == 0.0)
    }

    @Test("BullseyeAccelerometerGauge magnitude for unit gravity")
    func magnitudeUnitGravity() {
        let gauge = BullseyeAccelerometerGauge(
            x: 0.0,
            y: 0.0,
            z: 1.0,
            trailPoints: [],
            trailTimeLimit: 3.5
        )

        #expect(gauge.magnitude == 1.0)
    }

    @Test("PitchAngleGauge normalizes extreme values")
    func pitchAngleNormalization() {
        let maxAngle = 30.0

        // Test within range
        let gaugeNormal = PitchAngleGauge(pitch: 15.0)
        #expect(gaugeNormal.normalizedPitch == 15.0)

        // Test above max
        let gaugeHigh = PitchAngleGauge(pitch: 45.0)
        #expect(gaugeHigh.normalizedPitch == maxAngle)

        // Test below min
        let gaugeLow = PitchAngleGauge(pitch: -45.0)
        #expect(gaugeLow.normalizedPitch == -maxAngle)

        // Test at boundaries
        let gaugeMax = PitchAngleGauge(pitch: maxAngle)
        #expect(gaugeMax.normalizedPitch == maxAngle)

        let gaugeMin = PitchAngleGauge(pitch: -maxAngle)
        #expect(gaugeMin.normalizedPitch == -maxAngle)
    }

    @Test("RollAngleGauge normalizes extreme values")
    func rollAngleNormalization() {
        let maxAngle = 45.0

        // Test within range
        let gaugeNormal = RollAngleGauge(roll: 20.0)
        #expect(gaugeNormal.normalizedRoll == 20.0)

        // Test above max
        let gaugeHigh = RollAngleGauge(roll: 60.0)
        #expect(gaugeHigh.normalizedRoll == maxAngle)

        // Test below min
        let gaugeLow = RollAngleGauge(roll: -60.0)
        #expect(gaugeLow.normalizedRoll == -maxAngle)

        // Test at boundaries
        let gaugeMax = RollAngleGauge(roll: maxAngle)
        #expect(gaugeMax.normalizedRoll == maxAngle)

        let gaugeMin = RollAngleGauge(roll: -maxAngle)
        #expect(gaugeMin.normalizedRoll == -maxAngle)
    }
}

// MARK: - Color Constants Tests
struct ColorConstantsTests {

    @Test("NeonColors are defined correctly")
    func neonColorsAreDefined() {
        // Just verify colors can be accessed (no crashes)
        _ = NeonColors.cyan
        _ = NeonColors.blue
        _ = NeonColors.magenta
        _ = NeonColors.purple
        _ = NeonColors.pink
        _ = NeonColors.violet
        _ = NeonColors.darkBackground
        _ = NeonColors.white

        // Verify some color components
        let cyanComponents = NeonColors.cyan
        let darkComponents = NeonColors.darkBackground

        // These should be different colors
        #expect(cyanComponents != darkComponents)
    }
}

// MARK: - SensorControlButton Tests
struct SensorControlButtonTests {

    @Test("Button displays correct state for stopped")
    func buttonStoppedState() {
        let button = SensorControlButton(
            sensorState: .stopped,
            onStart: {},
            onStop: {},
            onCalibrate: {}
        )

        // Verify we can create the button with correct state
        #expect(button.sensorState == .stopped)
    }

    @Test("Button displays correct state for running")
    func buttonRunningState() {
        let button = SensorControlButton(
            sensorState: .running,
            onStart: {},
            onStop: {},
            onCalibrate: {}
        )

        // Verify we can create the button with correct state
        #expect(button.sensorState == .running)
    }

    @Test("Button displays correct state for calibrating")
    func buttonCalibratingState() {
        let button = SensorControlButton(
            sensorState: .calibrating,
            onStart: {},
            onStop: {},
            onCalibrate: {}
        )

        #expect(button.sensorState == .calibrating)
    }
}

// MARK: - Mock Objects for Testing
class MockAccelerometerData: CMAccelerometerData {
    private let _acceleration: CMAcceleration
    private let _timestamp: TimeInterval

    init(acceleration: CMAcceleration, timestamp: TimeInterval) {
        self._acceleration = acceleration
        self._timestamp = timestamp
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceleration: CMAcceleration {
        return _acceleration
    }

    override var timestamp: TimeInterval {
        return _timestamp
    }
}
