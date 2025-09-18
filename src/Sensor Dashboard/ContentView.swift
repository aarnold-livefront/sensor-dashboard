//
//  ContentView.swift
//  Sensor Dashboard
//
//  Created by Annalise Arnold on 9/5/25.
//

import SwiftUI
import CoreMotion

// MARK: - Color Constants
struct NeonColors {
    static let cyan = Color(red: 0.0, green: 1.0, blue: 1.0)
    static let blue = Color(red: 0.1, green: 0.7, blue: 1.0)
    static let magenta = Color(red: 1.0, green: 0.0, blue: 1.0)
    static let purple = Color(red: 0.5, green: 0.0, blue: 1.0)
    static let pink = Color(red: 1.0, green: 0.4, blue: 0.8)
    static let violet = Color(red: 0.9, green: 0.0, blue: 1.0)
    static let darkBackground = Color(red: 0.05, green: 0.05, blue: 0.1)
    static let white = Color.white
}

struct TrailPoint: Identifiable {
    let id = UUID()
    let x: Double
    let y: Double
    let timestamp: Date
}

struct AdjustedAccelerometerData {
    let acceleration: CMAcceleration
    let timestamp: TimeInterval

    init(from data: CMAccelerometerData, offset: CMAcceleration, smoothed: CMAcceleration? = nil) {
        if let smoothed = smoothed {
            self.acceleration = smoothed
        } else {
            self.acceleration = CMAcceleration(
                x: data.acceleration.x - offset.x,
                y: data.acceleration.y - offset.y,
                z: data.acceleration.z - offset.z
            )
        }
        self.timestamp = data.timestamp
    }
}

enum SensorState {
    case stopped
    case running
    case calibrating
}

class MotionManager: ObservableObject {
    private let motion = CMMotionManager()
    @Published var accelerometerData: AdjustedAccelerometerData?
    @Published var trailPoints: [TrailPoint] = []
    @Published var sensorState: SensorState = .stopped
    private let maxTrailPoints = 200
    let trailTimeLimit: TimeInterval = 3.5
    private var calibrationOffset = CMAcceleration(x: 0, y: 0, z: 0)

    // Smoothing filter properties
    private var previousSmoothedAcceleration = CMAcceleration(x: 0, y: 0, z: 0)
    private let smoothingFactor: Double = 0.15  // Lower values = more smoothing
    
    // Attitude-based angle tracking with gyroscope fusion
    @Published var currentPitch: Double = 0.0
    @Published var currentRoll: Double = 0.0
    private var lastGyroTimestamp: TimeInterval = 0
    
    private var pitchCalibrationOffset: Double = 0.0
    private var rollCalibrationOffset: Double = 0.0
    
    private static let radiansToDegreesMultiplier = 180.0 / Double.pi
    
    func radiansToDegrees(_ radians: Double) -> Double {
        return radians * Self.radiansToDegreesMultiplier
    }

    private func applySmoothingFilter(to newAcceleration: CMAcceleration) -> CMAcceleration {
        // Low-pass filter (exponential moving average)
        let smoothedX = previousSmoothedAcceleration.x + smoothingFactor * (newAcceleration.x - previousSmoothedAcceleration.x)
        let smoothedY = previousSmoothedAcceleration.y + smoothingFactor * (newAcceleration.y - previousSmoothedAcceleration.y)
        let smoothedZ = previousSmoothedAcceleration.z + smoothingFactor * (newAcceleration.z - previousSmoothedAcceleration.z)

        let smoothedAcceleration = CMAcceleration(x: smoothedX, y: smoothedY, z: smoothedZ)
        previousSmoothedAcceleration = smoothedAcceleration

        return smoothedAcceleration
    }
    
    func calculatePitchAngleFromQuaternion(_ quaternion: CMQuaternion) -> Double {
        // Calculate pitch angle using quaternion attitude data for better forward/backward distinction
        // This method provides clearer differentiation between forward and backward tilts
        let pitchRadians = atan2(2 * (quaternion.x * quaternion.w + quaternion.y * quaternion.z), 
                                1 - 2 * quaternion.x * quaternion.x - 2 * quaternion.z * quaternion.z)
        return radiansToDegrees(pitchRadians)
    }
    
    
    func calculateLateralRollAngle(from gravity: CMAcceleration) -> Double {
        // Calculate lateral roll angle independent of pitch
        // Use standard roll calculation: atan2(x, sqrt(y^2 + z^2))
        // This gives consistent left/right tilt detection regardless of pitch
        let verticalMagnitude = sqrt(gravity.y * gravity.y + gravity.z * gravity.z)
        
        // Handle edge case where vertical magnitude is very small
        guard verticalMagnitude > 0.01 else { return 0.0 }
        
        // Calculate roll angle using lateral X component relative to vertical plane
        let rollRadians = atan2(gravity.x, verticalMagnitude)
        let rollDegrees = rollRadians * 180.0 / .pi
        
        return rollDegrees
    }
    
    func updateAnglesFromMotion(_ motionData: CMDeviceMotion) {
        // Use quaternion attitude data for primary pitch calculation
        let quaternionPitch = calculatePitchAngleFromQuaternion(motionData.attitude.quaternion)
        
        // Use gravity-based lateral roll calculation (independent of pitch)
        let lateralRoll = calculateLateralRollAngle(from: motionData.gravity)
        
        // Get gyroscope data for sensor fusion
        let pitchVelocity = motionData.rotationRate.x // Rotation around X-axis (pitch)
        let rollVelocity = motionData.rotationRate.y  // Rotation around Y-axis (roll)
        
        // Calculate time delta for gyro integration
        let currentTime = motionData.timestamp
        if lastGyroTimestamp == 0 {
            lastGyroTimestamp = currentTime
            currentPitch = quaternionPitch - pitchCalibrationOffset
            currentRoll = lateralRoll - rollCalibrationOffset
            return
        }
        
        let deltaTime = currentTime - lastGyroTimestamp
        lastGyroTimestamp = currentTime
        
        // Convert gyro rates to degrees and integrate over time
        let pitchDelta = pitchVelocity * deltaTime * 180.0 / .pi
        let rollDelta = rollVelocity * deltaTime * 180.0 / .pi
        
        // Apply complementary filter with reduced gyroscope weighting
        // Pitch: Use quaternion attitude with minimal gyro influence (15% gyro, 85% attitude)
        let rawPitch = 0.15 * (currentPitch + pitchCalibrationOffset + pitchDelta) + 0.85 * quaternionPitch
        currentPitch = rawPitch - pitchCalibrationOffset
        
        // Roll: Use more gyro influence to smooth out gravity noise (40% gyro, 60% gravity)
        let rawRoll = 0.4 * (currentRoll + rollCalibrationOffset + rollDelta) + 0.6 * lateralRoll
        var filteredRoll = rawRoll - rollCalibrationOffset
        
        // Apply deadband filter to reduce small movements/noise
        let deadband = 1.0 // degrees
        if abs(filteredRoll) < deadband {
            filteredRoll = 0.0
        }
        
        currentRoll = filteredRoll
        
        // Clamp angles to reasonable ranges
        currentPitch = max(-90, min(90, currentPitch))
        currentRoll = max(-45, min(45, currentRoll))
    }
    
    init() {
        // Don't start automatically - wait for user to press start
    }
    
    func startSensor() {
        guard motion.isAccelerometerAvailable && motion.isDeviceMotionAvailable else { return }
        sensorState = .running
        
        // Reset all sensor readings to zero for fresh start
        lastGyroTimestamp = 0
        currentPitch = 0.0
        currentRoll = 0.0
        accelerometerData = nil
        trailPoints.removeAll()

        // Reset smoothing filter
        previousSmoothedAcceleration = CMAcceleration(x: 0, y: 0, z: 0)
        
        // Start accelerometer updates for trail visualization
        motion.accelerometerUpdateInterval = 0.02
        motion.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            guard let self = self, let data = data else { return }

            // Apply calibration offset first
            let offsetAdjustedAcceleration = CMAcceleration(
                x: data.acceleration.x - self.calibrationOffset.x,
                y: data.acceleration.y - self.calibrationOffset.y,
                z: data.acceleration.z - self.calibrationOffset.z
            )

            // Apply smoothing filter
            let smoothedAcceleration = self.applySmoothingFilter(to: offsetAdjustedAcceleration)

            // Create adjusted data with smoothed values
            let adjustedData = AdjustedAccelerometerData(from: data, offset: self.calibrationOffset, smoothed: smoothedAcceleration)

            self.accelerometerData = adjustedData
            self.updateTrail(x: adjustedData.acceleration.x, y: adjustedData.acceleration.y)
        }
        
        // Start device motion updates for attitude and gyroscope data
        motion.deviceMotionUpdateInterval = 0.05
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, error in
            guard let self = self, let data = data else { return }
            self.updateAnglesFromMotion(data)
        }
    }
    
    func stopSensor() {
        motion.stopAccelerometerUpdates()
        motion.stopDeviceMotionUpdates()
        sensorState = .stopped
        accelerometerData = nil
        trailPoints.removeAll()
        currentPitch = 0.0
        currentRoll = 0.0
        lastGyroTimestamp = 0

        // Reset smoothing filter
        previousSmoothedAcceleration = CMAcceleration(x: 0, y: 0, z: 0)
    }
    
    func calibrateSensor() {
        guard motion.isAccelerometerAvailable && motion.isDeviceMotionAvailable else { return }
        sensorState = .calibrating
        
        motion.accelerometerUpdateInterval = 0.1
        motion.deviceMotionUpdateInterval = 0.1
        
        var accelerometerSamples: [CMAcceleration] = []
        var pitchSamples: [Double] = []
        var rollSamples: [Double] = []
        let sampleCount = 10
        
        // Start both accelerometer and device motion updates for calibration
        motion.startAccelerometerUpdates(to: .main) { data, error in
            guard let data = data else { return }
            accelerometerSamples.append(data.acceleration)
        }
        
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, error in
            guard let self = self, let motionData = data else { return }
            
            // Collect quaternion-based pitch and gravity-based lateral roll samples
            let quaternionPitch = self.calculatePitchAngleFromQuaternion(motionData.attitude.quaternion)
            let lateralRoll = self.calculateLateralRollAngle(from: motionData.gravity)
            
            pitchSamples.append(quaternionPitch)
            rollSamples.append(lateralRoll)
            
            // Check if we have enough samples from both sensors
            if accelerometerSamples.count >= sampleCount && 
               pitchSamples.count >= sampleCount && 
               rollSamples.count >= sampleCount {
                
                self.motion.stopAccelerometerUpdates()
                self.motion.stopDeviceMotionUpdates()
                
                // Calculate accelerometer calibration offset
                let avgX = accelerometerSamples.reduce(0) { $0 + $1.x } / Double(sampleCount)
                let avgY = accelerometerSamples.reduce(0) { $0 + $1.y } / Double(sampleCount)
                let avgZ = accelerometerSamples.reduce(0) { $0 + $1.z } / Double(sampleCount)
                
                self.calibrationOffset = CMAcceleration(x: avgX, y: avgY, z: avgZ - 1.0)
                
                // Calculate pitch and roll calibration offsets from quaternion attitude
                // These represent the device's current orientation when calibration was initiated
                self.pitchCalibrationOffset = pitchSamples.reduce(0, +) / Double(sampleCount)
                self.rollCalibrationOffset = rollSamples.reduce(0, +) / Double(sampleCount)
                
                // Reset current angles to zero (they will be offset-corrected in updateAnglesFromMotion)
                self.currentPitch = 0.0
                self.currentRoll = 0.0
                self.lastGyroTimestamp = 0

                // Reset smoothing filter
                self.previousSmoothedAcceleration = CMAcceleration(x: 0, y: 0, z: 0)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.startSensor()
                }
            }
        }
    }
    
    private func updateTrail(x: Double, y: Double) {
        let newPoint = TrailPoint(x: x, y: y, timestamp: Date())
        trailPoints.append(newPoint)

        // More aggressive cleanup to maintain smooth performance
        let cutoffTime = Date().addingTimeInterval(-trailTimeLimit)
        trailPoints.removeAll { $0.timestamp < cutoffTime }

        // Ensure we don't exceed max points (for performance)
        if trailPoints.count > maxTrailPoints {
            let pointsToRemove = trailPoints.count - maxTrailPoints
            trailPoints.removeFirst(pointsToRemove)
        }
    }
}

struct BullseyeAccelerometerGauge: View {
    let x: Double
    let y: Double
    let z: Double
    let trailPoints: [TrailPoint]
    let trailTimeLimit: TimeInterval
    
    private let gaugeSize: CGFloat = 320
    private let maxRange: Double = 1.5
    private let gaugeRadius: CGFloat = 160 // gaugeSize / 2
    private let scaleFactor: CGFloat = 112 // gaugeSize * 0.35
    
    var magnitude: Double {
        sqrt(x*x + y*y + z*z)
    }
    
    private func clampPosition(_ value: Double) -> CGFloat {
        let scaled = CGFloat(value / maxRange) * scaleFactor
        return min(max(scaled, -scaleFactor), scaleFactor)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            
            Text("G-FORCE")
                .font(.system(size: 28))
                .fontWeight(.black)
                .foregroundColor(NeonColors.cyan)
                .shadow(color: NeonColors.cyan, radius: 2.5)

            ZStack {
                
                Text(String(format: "%.2f", magnitude))
                    .font(.system(size: 28))
                    .fontWeight(.black)
                    .foregroundColor(NeonColors.magenta)
                    .shadow(color: NeonColors.magenta, radius: 4)
                    .offset(y: gaugeSize * 0.55)
                
                ZStack {
                    Circle()
                .fill(NeonColors.darkBackground)
                .frame(width: gaugeSize, height: gaugeSize)
            
            ForEach([0.5, 1.0, 1.5], id: \.self) { ring in
                let ringColor = ring == 1.5 ? NeonColors.magenta :
                               ring == 1.0 ? NeonColors.cyan :
                               NeonColors.purple
                let ringSize = gaugeSize * (ring / maxRange) * 0.8
                
                Circle()
                    .stroke(ringColor, lineWidth: ring == 1.5 ? 6 : 3)
                    .frame(width: ringSize, height: ringSize)
                    .shadow(color: ringColor, radius: 3)
            }
            
            Path { path in
                let margin: CGFloat = 15
                path.move(to: CGPoint(x: gaugeRadius, y: margin))
                path.addLine(to: CGPoint(x: gaugeRadius, y: gaugeSize - margin))
                path.move(to: CGPoint(x: margin, y: gaugeRadius))
                path.addLine(to: CGPoint(x: gaugeSize - margin, y: gaugeRadius))
            }
            .stroke(NeonColors.blue, lineWidth: 3)
            
            // Continuous trail path with multiple segments for blur effect
            if trailPoints.count >= 2 {
                ForEach(1..<min(6, trailPoints.count), id: \.self) { layer in
                    Path { path in
                        let segmentSize = max(1, trailPoints.count / 6)
                        let startIndex = max(0, trailPoints.count - layer * segmentSize)
                        let endIndex = trailPoints.count - (layer - 1) * segmentSize

                        if startIndex < endIndex {
                            let firstPoint = trailPoints[startIndex]
                            path.move(to: CGPoint(
                                x: gaugeRadius + clampPosition(firstPoint.x),
                                y: gaugeRadius + clampPosition(-firstPoint.y)
                            ))

                            for i in (startIndex + 1)..<min(endIndex, trailPoints.count) {
                                let point = trailPoints[i]
                                path.addLine(to: CGPoint(
                                    x: gaugeRadius + clampPosition(point.x),
                                    y: gaugeRadius + clampPosition(-point.y)
                                ))
                            }
                        }
                    }
                    .stroke(
                        LinearGradient(
                            colors: [
                                NeonColors.purple.opacity(0.7 - Double(layer) * 0.1),
                                NeonColors.magenta.opacity(0.8 - Double(layer) * 0.1),
                                NeonColors.cyan.opacity(0.5 - Double(layer) * 0.1)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(
                            lineWidth: CGFloat(12 - layer),
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                    .blur(radius: CGFloat(layer * 2) * 0.75)
                    .opacity(0.9 - Double(layer) * 0.15)
                }

                // Most recent trail points as individual circles for definition
                ForEach(Array(trailPoints.suffix(20).enumerated()), id: \.element.id) { index, point in
                    let totalPoints = min(20, trailPoints.count)
                    let ageBasedOpacity = Double(index) / Double(max(totalPoints - 1, 1))
                    let timeBasedOpacity = max(0.0, 1.0 - (Date().timeIntervalSince(point.timestamp) / trailTimeLimit))
                    let combinedOpacity = min(ageBasedOpacity, timeBasedOpacity) * 0.8
                    let size = 3.0 + (combinedOpacity * 5.0)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    NeonColors.white.opacity(combinedOpacity),
                                    NeonColors.cyan.opacity(combinedOpacity * 0.8),
                                    NeonColors.purple.opacity(combinedOpacity * 0.6)
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: size/2
                            )
                        )
                        .frame(width: size, height: size)
                        .opacity(combinedOpacity)
                        .shadow(color: NeonColors.cyan.opacity(combinedOpacity), radius: 1.5)
                        .offset(
                            x: clampPosition(point.x),
                            y: clampPosition(-point.y)
                        )
                }
            }
            
            Circle()
                .fill(
                    RadialGradient(
                        colors: [NeonColors.white, NeonColors.magenta],
                        center: .center,
                        startRadius: 0,
                        endRadius: 10
                    )
                )
                .frame(width: 16, height: 16)
                .offset(
                    x: clampPosition(x),
                    y: clampPosition(-y)
                )
                .shadow(color: NeonColors.magenta, radius: 8)
                }
                .frame(width: gaugeSize, height: gaugeSize)
            }
        }
    }
}

struct PitchAngleGauge: View {
    let pitch: Double
    
    private let gaugeSize: CGFloat = 120
    private let maxAngle: Double = 30.0
    private let offsetMultiplier: Double = 36.0
    
    var normalizedPitch: Double {
        min(max(pitch, -maxAngle), maxAngle)
    }
    
    var tiltOffset: Double {
        normalizedPitch / maxAngle * (gaugeSize * 0.3)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Text("PITCH")
                .font(.system(size: 18))
                .fontWeight(.heavy)
                .foregroundColor(NeonColors.pink)
                .shadow(color: NeonColors.pink, radius: 2)
            
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.8))
                    .frame(width: gaugeSize, height: gaugeSize)
                
                Circle()
                    .stroke(NeonColors.pink, lineWidth: 3)
                    .frame(width: gaugeSize, height: gaugeSize)
                    .shadow(color: NeonColors.pink, radius: 2)

                Rectangle()
                    .fill(NeonColors.white.opacity(0.3))
                    .frame(width: gaugeSize * 0.8, height: 2)
                    .shadow(color: NeonColors.white, radius: 1)
                
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: pitch > 0 ? 
                                [Color.orange, Color.red] : 
                                [Color.blue, Color.cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: gaugeSize * 0.8, height: 4)
                    .offset(y: tiltOffset)
                    .shadow(color: pitch > 0 ? NeonColors.purple : Color(red: 0.0, green: 1.0, blue: 0.8), radius: 3)
                    .animation(.easeInOut(duration: 0.2), value: pitch)
                
                ForEach([-30, -15, 0, 15, 30], id: \.self) { angle in
                    Rectangle()
                        .fill(NeonColors.white.opacity(angle == 0 ? 0.8 : 0.4))
                        .frame(width: angle == 0 ? 30 : 15, height: 1)
                        .offset(y: CGFloat(angle) / CGFloat(maxAngle) * offsetMultiplier)
                }
                
                Circle()
                    .fill(NeonColors.white)
                    .frame(width: 6, height: 6)
                    .shadow(color: NeonColors.white, radius: 2)
            }
            .clipShape(Circle())
            
            Text("\(String(format: "%.1f", pitch))°")
                .font(.system(size: 19))
                .fontWeight(.bold)
                .foregroundColor(NeonColors.pink)
                .shadow(color: NeonColors.pink, radius: 2)
        }
    }
}

struct RollAngleGauge: View {
    let roll: Double
    
    private let gaugeSize: CGFloat = 120
    private let maxAngle: Double = 45.0
    private let offsetMultiplier: Double = 27.0
    
    var normalizedRoll: Double {
        min(max(roll, -maxAngle), maxAngle)
    }
    
    
    var body: some View {
        VStack(spacing: 8) {
            Text("ROLL")
                .font(.system(size: 18))
                .fontWeight(.black)
                .foregroundColor(NeonColors.violet)
                .shadow(color: NeonColors.purple, radius: 2)
            
            ZStack {
                Circle()
                    .fill(NeonColors.darkBackground)
                    .frame(width: gaugeSize, height: gaugeSize)
                
                Circle()
                    .stroke(NeonColors.purple, lineWidth: 4)
                    .frame(width: gaugeSize, height: gaugeSize)
                    .shadow(color: NeonColors.purple, radius: 3)
                
                Rectangle()
                    .fill(NeonColors.white.opacity(0.3))
                    .frame(width: gaugeSize * 0.8, height: 2)
                    .shadow(color: NeonColors.white, radius: 1)
                
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: roll > 0 ? 
                                [NeonColors.purple, Color(red: 1.0, green: 0.0, blue: 0.8)] :
                                [Color(red: 0.0, green: 1.0, blue: 0.8), Color(red: 0.2, green: 1.0, blue: 0.2)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: gaugeSize * 0.8, height: 4)
                    .rotationEffect(.degrees(normalizedRoll))
                    .shadow(color: roll > 0 ? NeonColors.purple : Color(red: 0.0, green: 1.0, blue: 0.8), radius: 3)
                    .animation(.easeInOut(duration: 0.2), value: roll)
                
                ForEach([-45, -22, 0, 22, 45], id: \.self) { angle in
                    Rectangle()
                        .fill(NeonColors.cyan.opacity(angle == 0 ? 1.0 : 0.7))
                        .frame(width: angle == 0 ? 30 : 20, height: angle == 0 ? 2 : 1)
                        .offset(y: CGFloat(angle) / CGFloat(maxAngle) * offsetMultiplier)
                        .rotationEffect(.degrees(normalizedRoll))
                        .shadow(color: NeonColors.cyan, radius: 1)
                }
                
                Circle()
                    .fill(NeonColors.white)
                    .frame(width: 6, height: 6)
                    .shadow(color: NeonColors.white, radius: 2)
            }
            .clipShape(Circle())
            
            Text("\(String(format: "%.1f", roll))°")
                .font(.system(size: 19))
                .fontWeight(.bold)
                .foregroundColor(NeonColors.violet)
                .shadow(color: NeonColors.purple, radius: 2)
        }
    }
}

struct SensorControlButton: View {
    let sensorState: SensorState
    let onStart: () -> Void
    let onStop: () -> Void
    let onCalibrate: () -> Void
    
    var body: some View {
        Button(action: buttonAction) {
            HStack(spacing: 8) {
                Image(systemName: buttonIcon)
                    .font(.system(size: 18, weight: .black))
                Text(buttonTitle)
                    .font(.system(size: 18, weight: .black))
            }
            .foregroundColor(NeonColors.darkBackground)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(buttonColor)
                    .shadow(color: buttonColor, radius: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(NeonColors.cyan, lineWidth: 3)
            )
        }
        .disabled(sensorState == .calibrating)
    }
    
    private var buttonIcon: String {
        switch sensorState {
        case .stopped: return "play.fill"
        case .running: return "stop.fill"
        case .calibrating: return "arrow.clockwise"
        }
    }
    
    private var buttonTitle: String {
        switch sensorState {
        case .stopped: return "START"
        case .running: return "STOP"
        case .calibrating: return "CALIBRATING..."
        }
    }
    
    private var buttonColor: Color {
        switch sensorState {
        case .stopped: return Color(red: 0.0, green: 1.0, blue: 0.7)
        case .running: return Color(red: 1.0, green: 0.0, blue: 0.4)
        case .calibrating: return Color(red: 1.0, green: 0.5, blue: 0.0)
        }
    }
    
    private func buttonAction() {
        switch sensorState {
        case .stopped: onStart()
        case .running: onStop()
        case .calibrating: break
        }
    }
}

struct ContentView: View {
    @StateObject private var motionManager = MotionManager()
    
    private var isRunning: Bool {
        motionManager.sensorState == .running
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 10) {
                
                VStack(spacing: 12) {
                    SensorControlButton(
                        sensorState: motionManager.sensorState,
                        onStart: { motionManager.calibrateSensor() },
                        onStop: { motionManager.stopSensor() },
                        onCalibrate: { motionManager.calibrateSensor() }
                    )
                    
                    if isRunning {
                        Button("RECALIBRATE") {
                            motionManager.calibrateSensor()
                        }
                        .font(.system(size: 16))
                        .fontWeight(.black)
                        .foregroundColor(NeonColors.cyan)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(NeonColors.darkBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(NeonColors.cyan, lineWidth: 2)
                        )
                        .shadow(color: NeonColors.cyan, radius: 4)
                    }
                }
                .frame(height: 120)
                .padding(.top, 20)
                
                Group {
                    if let data = motionManager.accelerometerData {
                        BullseyeAccelerometerGauge(
                            x: data.acceleration.x,
                            y: data.acceleration.y,
                            z: data.acceleration.z,
                            trailPoints: motionManager.trailPoints,
                            trailTimeLimit: motionManager.trailTimeLimit
                        )
                    } else {
                        BullseyeAccelerometerGauge(
                            x: 0, y: 0, z: 1,
                            trailPoints: [],
                            trailTimeLimit: motionManager.trailTimeLimit
                        )
                        .opacity(0.5)
                    }
                }
                .frame(height: geometry.size.height * 0.5)
                
                Spacer()
                
                HStack(spacing: 35) {
                    if isRunning {
                        PitchAngleGauge(pitch: motionManager.currentPitch)
                        RollAngleGauge(roll: motionManager.currentRoll)
                    } else {
                        PitchAngleGauge(pitch: 0)
                            .opacity(0.5)
                        RollAngleGauge(roll: 0)
                            .opacity(0.5)
                    }
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .background(
                LinearGradient(
                    colors: [
                        NeonColors.darkBackground,
                        Color(red: 0.1, green: 0.0, blue: 0.2),
                        NeonColors.darkBackground
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        .ignoresSafeArea()
    }
}

#Preview {
    ContentView()
}
