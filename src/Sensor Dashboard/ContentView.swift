//
//  ContentView.swift
//  Sensor Dashboard
//
//  Created by Annalise Arnold on 9/5/25.
//

import SwiftUI
import CoreMotion

struct TrailPoint: Identifiable {
    let id = UUID()
    let x: Double
    let y: Double
    let timestamp: Date
}

struct AdjustedAccelerometerData {
    let acceleration: CMAcceleration
    let timestamp: TimeInterval
    
    init(from data: CMAccelerometerData, offset: CMAcceleration) {
        self.acceleration = CMAcceleration(
            x: data.acceleration.x - offset.x,
            y: data.acceleration.y - offset.y,
            z: data.acceleration.z - offset.z
        )
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
    private let maxTrailPoints = 50
    private var calibrationOffset = CMAcceleration(x: 0, y: 0, z: 0)
    
    init() {
        // Don't start automatically - wait for user to press start
    }
    
    func startSensor() {
        guard motion.isAccelerometerAvailable else { return }
        sensorState = .running
        motion.accelerometerUpdateInterval = 0.03
        motion.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            guard let self = self, let data = data else { return }
            
            let adjustedData = AdjustedAccelerometerData(from: data, offset: self.calibrationOffset)
            
            self.accelerometerData = adjustedData
            self.updateTrail(x: adjustedData.acceleration.x, y: adjustedData.acceleration.y)
        }
    }
    
    func stopSensor() {
        motion.stopAccelerometerUpdates()
        sensorState = .stopped
        accelerometerData = nil
        trailPoints.removeAll()
    }
    
    func calibrateSensor() {
        guard motion.isAccelerometerAvailable else { return }
        sensorState = .calibrating
        
        motion.accelerometerUpdateInterval = 0.1
        var calibrationSamples: [CMAcceleration] = []
        let sampleCount = 10
        
        motion.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            guard let self = self, let data = data else { return }
            
            calibrationSamples.append(data.acceleration)
            
            if calibrationSamples.count >= sampleCount {
                self.motion.stopAccelerometerUpdates()
                
                let avgX = calibrationSamples.reduce(0) { $0 + $1.x } / Double(sampleCount)
                let avgY = calibrationSamples.reduce(0) { $0 + $1.y } / Double(sampleCount)
                let avgZ = calibrationSamples.reduce(0) { $0 + $1.z } / Double(sampleCount)
                
                self.calibrationOffset = CMAcceleration(x: avgX, y: avgY, z: avgZ - 1.0)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.startSensor()
                }
            }
        }
    }
    
    private func updateTrail(x: Double, y: Double) {
        let newPoint = TrailPoint(x: x, y: y, timestamp: Date())
        trailPoints.append(newPoint)
        
        if trailPoints.count > maxTrailPoints {
            trailPoints.removeFirst()
        }
        
        let cutoffTime = Date().addingTimeInterval(-5.0)
        trailPoints.removeAll { $0.timestamp < cutoffTime }
    }
}

struct BullseyeAccelerometerGauge: View {
    let x: Double
    let y: Double
    let z: Double
    let trailPoints: [TrailPoint]
    
    var magnitude: Double {
        sqrt(x*x + y*y + z*z)
    }
    
    private let gaugeSize: CGFloat = 320
    private let maxRange: Double = 1.75
    
    var body: some View {
        VStack(spacing: 8) {
            
            Text("G-FORCE")
                .font(.system(size: 28))
                .fontWeight(.black)
                .foregroundColor(Color(red: 0.0, green: 1.0, blue: 1.0))
                .shadow(color: Color(red: 0.0, green: 1.0, blue: 1.0), radius: 2.5)

            ZStack {
                
                Text(String(format: "%.2f", magnitude))
                    .font(.system(size: 28))
                    .fontWeight(.black)
                    .foregroundColor(Color(red: 1.0, green: 0.0, blue: 0.5))
                    .shadow(color: Color(red: 1.0, green: 0.0, blue: 0.5), radius: 4)
                    .offset(y: gaugeSize * 0.55)
                
                ZStack {
                    Circle()
                .fill(Color(red: 0.05, green: 0.0, blue: 0.15))
                .frame(width: gaugeSize, height: gaugeSize)
            
            ForEach([0.5, 1.0, 1.5, 2.0], id: \.self) { ring in
                Circle()
                    .stroke(
                        ring == 2.0 ? Color(red: 1.0, green: 0.0, blue: 0.4) :
                        ring == 1.5 ? Color(red: 1.0, green: 0.2, blue: 0.8) :
                        ring == 1.0 ? Color(red: 0.0, green: 0.8, blue: 1.0) :
                        Color(red: 0.8, green: 0.0, blue: 1.0),
                        lineWidth: ring == 2.0 ? 6 : 3
                    )
                    .frame(
                        width: gaugeSize * (ring / maxRange) * 0.8,
                        height: gaugeSize * (ring / maxRange) * 0.8
                    )
                    .shadow(color: ring == 2.0 ? Color(red: 1.0, green: 0.0, blue: 0.4) :
                           ring == 1.5 ? Color(red: 1.0, green: 0.2, blue: 0.8) :
                           ring == 1.0 ? Color(red: 0.0, green: 0.8, blue: 1.0) :
                           Color(red: 0.8, green: 0.0, blue: 1.0), radius: 3)
            }
            
            Path { path in
                path.move(to: CGPoint(x: gaugeSize/2, y: 15))
                path.addLine(to: CGPoint(x: gaugeSize/2, y: gaugeSize - 15))
                path.move(to: CGPoint(x: 15, y: gaugeSize/2))
                path.addLine(to: CGPoint(x: gaugeSize - 15, y: gaugeSize/2))
            }
            .stroke(Color(red: 0.0, green: 1.0, blue: 1.0), lineWidth: 3)
            
            ForEach(Array(trailPoints.enumerated()), id: \.element.id) { index, point in
                let opacity = Double(index) / Double(max(trailPoints.count - 1, 1))
                let size = 4.0 + (opacity * 8.0)
                
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.0, green: 1.0, blue: 1.0),
                                Color(red: 1.0, green: 0.0, blue: 1.0)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: size/2
                        )
                    )
                    .frame(width: size, height: size)
                    .opacity(opacity)
                    .shadow(color: Color(red: 0.0, green: 1.0, blue: 1.0), radius: 2)
                    .offset(
                        x: min(max(point.x / maxRange * (gaugeSize * 0.35), -gaugeSize * 0.35), gaugeSize * 0.35),
                        y: min(max(-point.y / maxRange * (gaugeSize * 0.35), -gaugeSize * 0.35), gaugeSize * 0.35)
                    )
            }
            
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1.0, green: 1.0, blue: 1.0),
                            Color(red: 1.0, green: 0.0, blue: 0.5)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 10
                    )
                )
                .frame(width: 16, height: 16)
                .offset(
                    x: min(max(x / maxRange * (gaugeSize * 0.35), -gaugeSize * 0.35), gaugeSize * 0.35),
                    y: min(max(-y / maxRange * (gaugeSize * 0.35), -gaugeSize * 0.35), gaugeSize * 0.35)
                )
                .shadow(color: Color(red: 1.0, green: 0.0, blue: 0.5), radius: 8)
                }
                .frame(width: gaugeSize, height: gaugeSize)
            }
        }
    }
}

struct PitchAngleGauge: View {
    let pitch: Double
    
    private let gaugeSize: CGFloat = 120
    private let maxAngle: Double = 90.0
    
    var normalizedPitch: Double {
        min(max(pitch, -maxAngle), maxAngle)
    }
    
    var fillHeight: Double {
        (normalizedPitch + maxAngle) / (2 * maxAngle)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Text("PITCH")
                .font(.system(size: 18))
                .fontWeight(.heavy)
                .foregroundColor(Color(red: 1.0, green: 0.2, blue: 0.8))
                .shadow(color: Color(red: 1.0, green: 0.2, blue: 0.8), radius: 2)
            
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.8))
                    .frame(width: gaugeSize, height: gaugeSize)
                
                Circle()
                    .stroke(Color(red: 1.0, green: 0.2, blue: 0.8), lineWidth: 3)
                    .frame(width: gaugeSize, height: gaugeSize)
                    .shadow(color: Color(red: 1.0, green: 0.2, blue: 0.8), radius: 2)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: pitch > 0 ? [Color.orange, Color.red] : [Color.blue, Color.cyan],
                            center: .center,
                            startRadius: 0,
                            endRadius: gaugeSize/2
                        )
                    )
                    .frame(width: gaugeSize * abs(fillHeight), height: gaugeSize * abs(fillHeight))
                    .shadow(color: pitch > 0 ? Color(red: 0.8, green: 0.0, blue: 1.0) : Color(red: 0.0, green: 1.0, blue: 0.8), radius: 5)
                    .animation(.easeInOut(duration: 0.2), value: pitch)
                
//                ForEach([-45, -30, -15, 0, 15, 30, 45], id: \.self) { angle in
//                    Rectangle()
//                        .fill(Color.white.opacity(angle == 0 ? 0.8 : 0.4))
//                        .frame(width: angle == 0 ? 25 : 15, height: angle == 0 ? 2 : 1)
//                        .offset(y: -gaugeSize * 0.35)
//                        .rotationEffect(.degrees(Double(angle)))
//                }
                
                Circle()
                    .fill(Color(red: 1.0, green: 1.0, blue: 1.0))
                    .frame(width: 6, height: 6)
                    .shadow(color: Color(red: 1.0, green: 1.0, blue: 1.0), radius: 2)
            }
            .clipShape(Circle())
            
            Text("\(String(format: "%.1f", pitch))°")
                .font(.system(size: 19))
                .fontWeight(.bold)
                .foregroundColor(Color(red: 1.0, green: 0.2, blue: 0.8))
                .shadow(color: Color(red: 1.0, green: 0.2, blue: 0.8), radius: 2)
        }
    }
}

struct RollAngleGauge: View {
    let roll: Double
    
    private let gaugeSize: CGFloat = 120
    private let maxAngle: Double = 90.0
    
    var normalizedRoll: Double {
        min(max(roll, -maxAngle), maxAngle)
    }
    
    var fillHeight: Double {
        (normalizedRoll + maxAngle) / (2 * maxAngle)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Text("ROLL")
                .font(.system(size: 18))
                .fontWeight(.black)
                .foregroundColor(Color(red: 0.9, green: 0.4, blue: 1.0))
                .shadow(color: Color(red: 0.8, green: 0.1, blue: 0.9), radius: 2)
            
            ZStack {
                Circle()
                    .fill(Color(red: 0.05, green: 0.0, blue: 0.15))
                    .frame(width: gaugeSize, height: gaugeSize)
                
                Circle()
                    .stroke(Color(red: 0.8, green: 0.0, blue: 1.0), lineWidth: 4)
                    .frame(width: gaugeSize, height: gaugeSize)
                    .shadow(color: Color(red: 0.8, green: 0.0, blue: 1.0), radius: 3)
                
                Circle()
                    .fill(
                        RadialGradient(
                            colors: roll > 0 ? 
                                [Color(red: 0.8, green: 0.0, blue: 1.0), Color(red: 1.0, green: 0.0, blue: 0.8)] :
                                [Color(red: 0.0, green: 1.0, blue: 0.8), Color(red: 0.2, green: 1.0, blue: 0.2)],
                            center: .center,
                            startRadius: 0,
                            endRadius: gaugeSize/2
                        )
                    )
                    .frame(width: gaugeSize * abs(fillHeight), height: gaugeSize * abs(fillHeight))
                    .shadow(color: roll > 0 ? Color(red: 0.8, green: 0.0, blue: 1.0) : Color(red: 0.0, green: 1.0, blue: 0.8), radius: 5)
                    .animation(.easeInOut(duration: 0.2), value: roll)
//                
//                ForEach([-45, -30, -15, 0, 15, 30, 45], id: \.self) { angle in
//                    Rectangle()
//                        .fill(Color(red: 0.0, green: 1.0, blue: 1.0).opacity(angle == 0 ? 1.0 : 0.7))
//                        .frame(width: angle == 0 ? 30 : 20, height: angle == 0 ? 4 : 2)
//                        .offset(y: -gaugeSize * 0.35)
//                        .rotationEffect(.degrees(Double(angle)))
//                        .shadow(color: Color(red: 0.0, green: 1.0, blue: 1.0), radius: 1)
//                }
                
                Circle()
                    .fill(Color(red: 1.0, green: 1.0, blue: 1.0))
                    .frame(width: 6, height: 6)
                    .shadow(color: Color(red: 1.0, green: 1.0, blue: 1.0), radius: 2)
            }
            .clipShape(Circle())
            
            Text("\(String(format: "%.1f", roll))°")
                .font(.system(size: 19))
                .fontWeight(.bold)
                .foregroundColor(Color(red: 0.9, green: 0.4, blue: 1.0))
                .shadow(color: Color(red: 0.8, green: 0.1, blue: 0.9), radius: 2)
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
            .foregroundColor(Color(red: 0.05, green: 0.0, blue: 0.15))
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(buttonColor)
                    .shadow(color: buttonColor, radius: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(red: 0.0, green: 1.0, blue: 1.0), lineWidth: 3)
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
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 10) {
                
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        SensorControlButton(
                            sensorState: motionManager.sensorState,
                            onStart: { motionManager.startSensor() },
                            onStop: { motionManager.stopSensor() },
                            onCalibrate: { motionManager.calibrateSensor() }
                        )
                        
                        Group {
                            if motionManager.sensorState == .running {
                                Button("RECALIBRATE") {
                                    motionManager.calibrateSensor()
                                }
                                .font(.system(size: 16))
                                .fontWeight(.black)
                                .foregroundColor(Color(red: 0.0, green: 1.0, blue: 1.0))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color(red: 0.05, green: 0.0, blue: 0.15))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color(red: 0.0, green: 1.0, blue: 1.0), lineWidth: 2)
                                )
                                .shadow(color: Color(red: 0.0, green: 1.0, blue: 1.0), radius: 4)
                            } else {
                                Color.clear
                                    .frame(height: 32)
                            }
                        }
                    }
                    Spacer()
                }
                .frame(height: 120)
                .padding(.top, 20)
                
                HStack {
                    Spacer()
                    if let data = motionManager.accelerometerData {
                        BullseyeAccelerometerGauge(
                            x: data.acceleration.x,
                            y: data.acceleration.y,
                            z: data.acceleration.z,
                            trailPoints: motionManager.trailPoints
                        )
                    } else {
                        BullseyeAccelerometerGauge(
                            x: 0, y: 0, z: 1,
                            trailPoints: []
                        )
                        .opacity(0.5)
                    }
                    Spacer()
                }
                .frame(height: geometry.size.height * 0.5)
                
                Spacer()
                
                HStack(spacing: 35) {
                    Spacer()
                    if let data = motionManager.accelerometerData {
                        PitchAngleGauge(pitch: data.acceleration.y * 45)
                        RollAngleGauge(roll: data.acceleration.x * 45)
                    } else {
                        PitchAngleGauge(pitch: 0)
                            .opacity(0.5)
                        RollAngleGauge(roll: 0)
                            .opacity(0.5)
                    }
                    Spacer()
                }
                
                Spacer()
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.0, blue: 0.15),
                        Color(red: 0.1, green: 0.0, blue: 0.2),
                        Color(red: 0.05, green: 0.0, blue: 0.15)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }
}

#Preview {
    ContentView()
}
