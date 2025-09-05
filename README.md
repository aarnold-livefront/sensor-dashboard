# Sensor Dashboard

Sensor Dashboard is an iOS SwiftUI application that provides real-time visualization of device motion sensor data. The app displays accelerometer data through custom gauge components and attitude indicators.

## Features

- Real-time accelerometer data visualization (30ms update interval)
- Bullseye-style accelerometer gauge with motion trails
- Aviation-style attitude indicator for roll and pitch
- G-force magnitude calculation and display
- Calibration and recalibration controls
- Responsive Retrowave design for all device sizes

## Architecture

- **Main App**: [`Sensor_DashboardApp`](src/Sensor%20Dashboard/Sensor_DashboardApp.swift)
- **Primary View**: [`ContentView`](src/Sensor%20Dashboard/ContentView.swift)
- **Motion Manager**: Handles CoreMotion accelerometer data
- **Custom Gauges**: BullseyeAccelerometerGauge, PitchAngleGauge, RollAngleGauge

## Getting Started

### Prerequisites

- Xcode 16.4 or later
- iOS 18.5 SDK or later

### Build & Run

1. Open [`src/Sensor Dashboard.xcodeproj`](src/Sensor%20Dashboard.xcodeproj) in Xcode.
2. Select a simulator or device.
3. Press **Cmd+B** to build.
4. Press **Cmd+R** to run.

### Testing

- Unit tests: [`Sensor_DashboardTests`](src/Sensor%20DashboardTests/Sensor_DashboardTests.swift)
- UI tests: [`Sensor_DashboardUITests`](src/Sensor%20DashboardUITests/Sensor_DashboardUITests.swift), [`Sensor_DashboardUITestsLaunchTests`](src/Sensor%20DashboardUITests/Sensor_DashboardUITestsLaunchTests.swift)
- Run all tests with **Cmd+U** in Xcode.

## Project Structure

```
src/
  Sensor Dashboard/           # App source code
  Sensor DashboardTests/      # Unit tests
  Sensor DashboardUITests/    # UI tests
  Sensor Dashboard.xcodeproj/ # Xcode project
```

## Dependencies

- [SwiftUI](https://developer.apple.com/xcode/swiftui/)
- [CoreMotion](https://developer.apple.com/documentation/coremotion)
- [Swift Testing framework](https://github.com/apple/swift-testing)

## License

This project is licensed under the MIT License.

---

For more details, see [CLAUDE.md](CLAUDE.md)