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

class MotionManager: ObservableObject {
    private let motion = CMMotionManager()
    @Published var accelerometerData: CMAccelerometerData?
    @Published var trailPoints: [TrailPoint] = []
    private let maxTrailPoints = 20
    
    init() {
        startAccelerometerUpdates()
    }
    
    func startAccelerometerUpdates() {
        if motion.isAccelerometerAvailable {
            motion.accelerometerUpdateInterval = 0.03
            motion.startAccelerometerUpdates(to: .main) { [weak self] data, error in
                if let data = data {
                    self?.accelerometerData = data
                    self?.updateTrail(x: data.acceleration.x, y: data.acceleration.y)
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
        
        let cutoffTime = Date().addingTimeInterval(-2.0)
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
    
    private let gaugeSize: CGFloat = 300
    private let maxRange: Double = 2.0
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.8))
                .frame(width: gaugeSize, height: gaugeSize)
            
            ForEach([0.5, 1.0, 1.5, 2.0], id: \.self) { ring in
                Circle()
                    .stroke(
                        ring == 2.0 ? Color.red.opacity(0.6) :
                        ring == 1.5 ? Color.orange.opacity(0.4) :
                        ring == 1.0 ? Color.yellow.opacity(0.3) :
                        Color.green.opacity(0.2),
                        lineWidth: ring == 2.0 ? 3 : 1
                    )
                    .frame(
                        width: gaugeSize * (ring / maxRange) * 0.8,
                        height: gaugeSize * (ring / maxRange) * 0.8
                    )
            }
            
            Path { path in
                path.move(to: CGPoint(x: gaugeSize/2, y: 10))
                path.addLine(to: CGPoint(x: gaugeSize/2, y: gaugeSize - 10))
                path.move(to: CGPoint(x: 10, y: gaugeSize/2))
                path.addLine(to: CGPoint(x: gaugeSize - 10, y: gaugeSize/2))
            }
            .stroke(Color.white.opacity(0.3), lineWidth: 1)
            
            ForEach(Array(trailPoints.enumerated()), id: \.element.id) { index, point in
                let opacity = Double(index) / Double(max(trailPoints.count - 1, 1))
                let size = 3.0 + (opacity * 5.0)
                
                Circle()
                    .fill(
                        Color.cyan.opacity(opacity * 0.8)
                    )
                    .frame(width: size, height: size)
                    .offset(
                        x: min(max(point.x / maxRange * (gaugeSize * 0.35), -gaugeSize * 0.35), gaugeSize * 0.35),
                        y: min(max(-point.y / maxRange * (gaugeSize * 0.35), -gaugeSize * 0.35), gaugeSize * 0.35)
                    )
            }
            
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white, .cyan],
                        center: .center,
                        startRadius: 0,
                        endRadius: 8
                    )
                )
                .frame(width: 12, height: 12)
                .offset(
                    x: min(max(x / maxRange * (gaugeSize * 0.35), -gaugeSize * 0.35), gaugeSize * 0.35),
                    y: min(max(-y / maxRange * (gaugeSize * 0.35), -gaugeSize * 0.35), gaugeSize * 0.35)
                )
                .shadow(color: .cyan, radius: 3)
            
            VStack {
                Text("G-FORCE")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(String(format: "%.2f", magnitude))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.cyan)
            }
            .offset(y: gaugeSize * 0.3)
        }
        .frame(width: gaugeSize, height: gaugeSize)
    }
}

struct AviationHorizonIndicator: View {
    let roll: Double
    let pitch: Double
    
    private let gaugeSize: CGFloat = 200
    private let maxAngle: Double = 45.0
    
    var body: some View {
        VStack(spacing: 12) {
            Text("ATTITUDE")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            ZStack {
                Circle()
                    .fill(Color.black)
                    .frame(width: gaugeSize, height: gaugeSize)
                
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                    .frame(width: gaugeSize, height: gaugeSize)
                
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.8), Color.brown.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: gaugeSize * 1.5, height: gaugeSize * 1.5)
                    .offset(y: min(max(pitch / maxAngle * (gaugeSize * 0.3), -gaugeSize * 0.3), gaugeSize * 0.3))
                    .rotationEffect(.degrees(roll * 2))
                    .clipShape(Circle())
                    .animation(.easeInOut(duration: 0.15), value: pitch)
                    .animation(.easeInOut(duration: 0.15), value: roll)
                
                ForEach([-30, -15, 15, 30], id: \.self) { angle in
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 30, height: 2)
                        .offset(y: -gaugeSize * 0.35)
                        .rotationEffect(.degrees(Double(angle)))
                }
                
                ForEach([-60, -45, 45, 60], id: \.self) { angle in
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 15, height: 1)
                        .offset(y: -gaugeSize * 0.35)
                        .rotationEffect(.degrees(Double(angle)))
                }
                
                Path { path in
                    path.move(to: CGPoint(x: gaugeSize * 0.15, y: gaugeSize/2))
                    path.addLine(to: CGPoint(x: gaugeSize * 0.35, y: gaugeSize/2))
                    path.move(to: CGPoint(x: gaugeSize * 0.65, y: gaugeSize/2))
                    path.addLine(to: CGPoint(x: gaugeSize * 0.85, y: gaugeSize/2))
                }
                .stroke(Color.orange, lineWidth: 3)
                
                Circle()
                    .fill(Color.orange)
                    .frame(width: 8, height: 8)
                
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 2, height: 20)
                    .offset(y: -gaugeSize * 0.4)
                    .rotationEffect(.degrees(roll * 2))
                    .animation(.easeInOut(duration: 0.15), value: roll)
            }
            .clipShape(Circle())
            
            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("ROLL")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text("\(String(format: "%.1f", roll))°")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                }
                
                VStack(spacing: 4) {
                    Text("PITCH")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text("\(String(format: "%.1f", pitch))°")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                }
            }
        }
        .frame(width: gaugeSize)
    }
}

struct ContentView: View {
    @StateObject private var motionManager = MotionManager()
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 30) {
                Spacer()
                
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
                
                HStack {
                    Spacer()
                    if let data = motionManager.accelerometerData {
                        AviationHorizonIndicator(
                            roll: data.acceleration.x * 30,
                            pitch: data.acceleration.y * 30
                        )
                    } else {
                        AviationHorizonIndicator(roll: 0, pitch: 0)
                            .opacity(0.5)
                    }
                    Spacer()
                }
                
                Spacer()
            }
            .padding()
            .background(Color.black)
        }
    }
}

#Preview {
    ContentView()
}
