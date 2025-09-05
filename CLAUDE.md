# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an iOS SwiftUI application called "Sensor Dashboard" that provides real-time visualization of device motion sensor data. The app displays accelerometer data through two custom gauge components: a bullseye-style accelerometer gauge and an aviation-style attitude indicator.

## Build and Development Commands

This is an Xcode project. Common development commands:

- **Build**: Open `src/Sensor Dashboard.xcodeproj` in Xcode and use Cmd+B to build
- **Run**: Use Cmd+R in Xcode to run on simulator or device
- **Test**: Use Cmd+U in Xcode to run the test suite (uses Swift Testing framework)
- **Clean**: Use Shift+Cmd+K in Xcode to clean build artifacts

## Architecture

### Core Components

- **Sensor_DashboardApp.swift**: Main app entry point following SwiftUI App lifecycle
- **ContentView.swift**: Primary view containing the sensor dashboard UI
- **MotionManager**: ObservableObject class that manages CoreMotion accelerometer data
- **BullseyeAccelerometerGauge**: Custom SwiftUI view displaying accelerometer data as a bullseye gauge with motion trails
- **AviationHorizonIndicator**: Custom SwiftUI view displaying attitude (roll/pitch) data as an aviation horizon

### Key Features

- Real-time accelerometer data visualization (30ms update interval)
- Motion trail tracking with automatic cleanup (2-second retention, 20-point limit)
- G-force magnitude calculation and display
- Aviation-style attitude indicator with roll/pitch visualization
- Responsive design using GeometryReader

### Testing Structure

- **Sensor_DashboardTests**: Unit tests using Swift Testing framework
- **Sensor_DashboardUITests**: UI tests for end-to-end testing

### Dependencies

- SwiftUI for UI framework
- CoreMotion for sensor data access
- Swift Testing framework for unit tests

Working directory is `src/` which contains the Xcode project and source files.