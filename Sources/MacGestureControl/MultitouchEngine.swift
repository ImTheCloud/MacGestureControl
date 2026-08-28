// MultitouchEngine.swift
import Foundation
import CoreGraphics
import Combine

// MARK: - MultitouchSupport C Definitions
struct MTPoint {
    var x: Float
    var y: Float
}

struct MTVector {
    var position: MTPoint
    var velocity: MTPoint
}

struct MTTouch {
    var frame: Int32
    var timestamp: Double
    var identifier: Int32
    var state: Int32
    var foo1: Int32
    var foo2: Int32
    var normalized: MTVector
    var size: Float
    var foo3: Int32
    var angle: Float
    var majorAxis: Float
    var minorAxis: Float
    var unknown: MTVector
    var foo4: Int32
    var foo5: Int32
    var foo6: Float
}

typealias MTDeviceRef = OpaquePointer
typealias MTContactCallbackFunction = @convention(c) (MTDeviceRef?, UnsafeMutableRawPointer?, Int32, Double, Int32) -> Int32

// MARK: - Model for Touch Visualizer
struct TrackpadTouch: Identifiable {
    let id: Int
    let normalizedX: CGFloat
    let normalizedY: CGFloat
    let size: CGFloat
}

// MARK: - Multitouch Engine
class MultitouchEngine: ObservableObject {
    static let shared = MultitouchEngine()

    @Published var activeTouches: [TrackpadTouch] = []

    private var device: MTDeviceRef?

    // Tracking states
    private var lastAverageY: Float?
    private var accumulatedDeltaY: Float = 0
    private var lastAverageX: Float?
    private var accumulatedDeltaX: Float = 0

    private var initialPinchDistance: Float?
    private var touchStartTime: Double = 0
    private var touchStartCount: Int = 0
    private var maxMovementDuringTouch: Float = 0

    func start() {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_NOW) else {
            NSLog("MultitouchSupport framework not found")
            return
        }

        guard let createDefaultSym = dlsym(handle, "MTDeviceCreateDefault"),
              let registerCallbackSym = dlsym(handle, "MTRegisterContactFrameCallback"),
              let startSym = dlsym(handle, "MTDeviceStart") else {
            NSLog("Failed to resolve MultitouchSupport symbols")
            return
        }

        let MTDeviceCreateDefault = unsafeBitCast(createDefaultSym, to: (@convention(c) () -> MTDeviceRef?).self)
        let MTRegisterContactFrameCallback = unsafeBitCast(registerCallbackSym, to: (@convention(c) (MTDeviceRef?, MTContactCallbackFunction) -> Void).self)
        let MTDeviceStart = unsafeBitCast(startSym, to: (@convention(c) (MTDeviceRef?, Int32) -> Void).self)

        guard let device = MTDeviceCreateDefault() else {
            NSLog("No Multitouch device found")
            return
        }
        self.device = device

        let callback: MTContactCallbackFunction = { (device, rawTouches, numTouches, timestamp, frame) -> Int32 in
            guard let rawTouches = rawTouches else { return 0 }
            let count = Int(numTouches)
            guard count >= 0 else { return 0 }
            let touches = rawTouches.bindMemory(to: MTTouch.self, capacity: max(1, count))
            MultitouchEngine.shared.handleTouchFrame(touches: touches, count: count, timestamp: timestamp)
            return 0
        }

        MTRegisterContactFrameCallback(device, callback)
        MTDeviceStart(device, 0)
        NSLog("MultitouchEngine started successfully")
    }

    private func handleTouchFrame(touches: UnsafeMutablePointer<MTTouch>, count: Int, timestamp: Double) {
        let settings = AppSettings.shared
        guard settings.isEnabled else {
            if !activeTouches.isEmpty {
                DispatchQueue.main.async { self.activeTouches = [] }
            }
            return
        }

        var touchingFingers: [MTTouch] = []
        for i in 0..<count {
            let t = touches[i]
            if t.state >= 2 { // Active touch
                touchingFingers.append(t)
            }
        }

        let fingerCount = touchingFingers.count

        // Update live touch visualizer (radar)
        var visualTouches: [TrackpadTouch] = []
        for t in touchingFingers {
            let item = TrackpadTouch(
                id: Int(t.identifier),
                normalizedX: CGFloat(t.normalized.position.x),
                normalizedY: CGFloat(1.0 - t.normalized.position.y),
                size: CGFloat(t.size)
            )
            visualTouches.append(item)
        }
        DispatchQueue.main.async {
            self.activeTouches = visualTouches
        }

        // --- Touch State Machine ---
        if fingerCount > 0 {
            if touchStartCount == 0 {
                touchStartTime = timestamp
                touchStartCount = fingerCount
                maxMovementDuringTouch = 0
                initialPinchDistance = calculatePinchDistance(touchingFingers)
            } else {
                touchStartCount = max(touchStartCount, fingerCount)
            }
        }

        // ==========================================
        // 4-FINGER GESTURES
        // ==========================================
        if fingerCount == 4 {
            let avgY = touchingFingers.reduce(0.0) { $0 + $1.normalized.position.y } / 4.0
            let avgX = touchingFingers.reduce(0.0) { $0 + $1.normalized.position.x } / 4.0

            // 4-Finger Vertical (VOLUME DEFAULT)
            if settings.fourFingerVerticalAction != .none {
                if let lastY = lastAverageY {
                    let deltaY = avgY - lastY
                    accumulatedDeltaY += deltaY
                    maxMovementDuringTouch += abs(deltaY)

                    let threshold: Float = 0.032
                    if abs(accumulatedDeltaY) >= threshold {
                        let movingUp = accumulatedDeltaY > 0
                        DispatchQueue.main.async {
                            SystemController.shared.execute(settings.fourFingerVerticalAction, up: movingUp)
                        }
                        accumulatedDeltaY = 0
                    }
                }
                lastAverageY = avgY
            }

            // 4-Finger Horizontal
            if settings.fourFingerHorizontalAction != .none {
                if let lastX = lastAverageX {
                    let deltaX = avgX - lastX
                    accumulatedDeltaX += deltaX
                    maxMovementDuringTouch += abs(deltaX)

                    let threshold: Float = 0.045
                    if abs(accumulatedDeltaX) >= threshold {
                        let movingRight = accumulatedDeltaX > 0
                        DispatchQueue.main.async {
                            SystemController.shared.execute(settings.fourFingerHorizontalAction, up: movingRight)
                        }
                        accumulatedDeltaX = 0
                    }
                }
                lastAverageX = avgX
            }

            // 4-Finger Pinch
            handlePinch(touches: touchingFingers,
                        pinchInAction: settings.fourFingerPinchInAction,
                        pinchOutAction: settings.fourFingerPinchOutAction)
        }

        // ==========================================
        // 3-FINGER GESTURES
        // ==========================================
        else if fingerCount == 3 {
            let avgY = touchingFingers.reduce(0.0) { $0 + $1.normalized.position.y } / 3.0
            let avgX = touchingFingers.reduce(0.0) { $0 + $1.normalized.position.x } / 3.0

            // 3-Finger Vertical
            if settings.threeFingerVerticalAction != .none {
                if let lastY = lastAverageY {
                    let deltaY = avgY - lastY
                    accumulatedDeltaY += deltaY
                    maxMovementDuringTouch += abs(deltaY)

                    let threshold: Float = 0.040
                    if abs(accumulatedDeltaY) >= threshold {
                        let movingUp = accumulatedDeltaY > 0
                        DispatchQueue.main.async {
                            SystemController.shared.execute(settings.threeFingerVerticalAction, up: movingUp)
                        }
                        accumulatedDeltaY = 0
                    }
                }
                lastAverageY = avgY
            }

            // 3-Finger Horizontal
            if settings.threeFingerHorizontalAction != .none {
                if let lastX = lastAverageX {
                    let deltaX = avgX - lastX
                    accumulatedDeltaX += deltaX
                    maxMovementDuringTouch += abs(deltaX)

                    let threshold: Float = 0.050
                    if abs(accumulatedDeltaX) >= threshold {
                        let movingRight = accumulatedDeltaX > 0
                        DispatchQueue.main.async {
                            SystemController.shared.execute(settings.threeFingerHorizontalAction, up: movingRight)
                        }
                        accumulatedDeltaX = 0
                    }
                }
                lastAverageX = avgX
            }

            // 3-Finger Pinch
            handlePinch(touches: touchingFingers,
                        pinchInAction: settings.threeFingerPinchInAction,
                        pinchOutAction: settings.threeFingerPinchOutAction)
        }

        // ==========================================
        // 1-FINGER CORNER TAPS
        // ==========================================
        else if fingerCount == 1 {
            let touch = touchingFingers[0]
            maxMovementDuringTouch += abs(touch.normalized.velocity.x) + abs(touch.normalized.velocity.y)
        }

        // ==========================================
        // FINGERS RELEASED (TAP DETECTION)
        // ==========================================
        if fingerCount == 0 && touchStartCount > 0 {
            let duration = timestamp - touchStartTime

            // Only consider it a tap if duration is short (< 0.35s) and little movement occurred
            if duration < 0.35 && maxMovementDuringTouch < 0.035 {
                switch touchStartCount {
                case 4:
                    if settings.fourFingerTapAction != .none {
                        DispatchQueue.main.async {
                            SystemController.shared.execute(settings.fourFingerTapAction)
                        }
                    }
                case 3:
                    if settings.threeFingerTapAction != .none {
                        DispatchQueue.main.async {
                            SystemController.shared.execute(settings.threeFingerTapAction)
                        }
                    }
                case 2:
                    if settings.twoFingerTapAction != .none {
                        DispatchQueue.main.async {
                            SystemController.shared.execute(settings.twoFingerTapAction)
                        }
                    }
                case 1:
                    // Check corner taps if single touch
                    if count > 0 {
                        let lastT = touches[0]
                        let x = lastT.normalized.position.x
                        let y = lastT.normalized.position.y
                        if x < 0.18 && y > 0.82 && settings.cornerTopLeftAction != .none {
                            DispatchQueue.main.async { SystemController.shared.execute(settings.cornerTopLeftAction) }
                        } else if x > 0.82 && y > 0.82 && settings.cornerTopRightAction != .none {
                            DispatchQueue.main.async { SystemController.shared.execute(settings.cornerTopRightAction) }
                        } else if x < 0.18 && y < 0.18 && settings.cornerBottomLeftAction != .none {
                            DispatchQueue.main.async { SystemController.shared.execute(settings.cornerBottomLeftAction) }
                        } else if x > 0.82 && y < 0.18 && settings.cornerBottomRightAction != .none {
                            DispatchQueue.main.async { SystemController.shared.execute(settings.cornerBottomRightAction) }
                        }
                    }
                default:
                    break
                }
            }

            // Reset tracking states
            touchStartCount = 0
            lastAverageY = nil
            lastAverageX = nil
            accumulatedDeltaY = 0
            accumulatedDeltaX = 0
            initialPinchDistance = nil
            maxMovementDuringTouch = 0
        }
    }

    private func calculatePinchDistance(_ touches: [MTTouch]) -> Float? {
        guard touches.count >= 2 else { return nil }
        let t1 = touches[0].normalized.position
        let t2 = touches[1].normalized.position
        let dx = Double(t1.x - t2.x)
        let dy = Double(t1.y - t2.y)
        return Float(sqrt(dx * dx + dy * dy))
    }

    private func handlePinch(touches: [MTTouch], pinchInAction: GestureAction, pinchOutAction: GestureAction) {
        guard pinchInAction != .none || pinchOutAction != .none else { return }
        guard let currentDist = calculatePinchDistance(touches), let startDist = initialPinchDistance else { return }

        let deltaDist = currentDist - startDist
        let threshold: Float = 0.12

        if deltaDist > threshold && pinchOutAction != .none {
            DispatchQueue.main.async {
                SystemController.shared.execute(pinchOutAction)
            }
            initialPinchDistance = currentDist
        } else if deltaDist < -threshold && pinchInAction != .none {
            DispatchQueue.main.async {
                SystemController.shared.execute(pinchInAction)
            }
            initialPinchDistance = currentDist
        }
    }
}
