// MultitouchManager.swift
import Foundation
import CoreGraphics

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

class MultitouchManager {
    static let shared = MultitouchManager()

    private var device: MTDeviceRef?
    private var lastAverageY: Float?
    private var accumulatedDeltaY: Float = 0
    private var isTracking4Fingers = false

    private var lastAverageX: Float?
    private var accumulatedDeltaX: Float = 0

    func start() {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_NOW) else {
            NSLog("MultitouchSupport framework not available")
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
            guard count > 0 else { return 0 }
            let touches = rawTouches.bindMemory(to: MTTouch.self, capacity: count)
            MultitouchManager.shared.handleTouches(touches: touches, count: count)
            return 0
        }

        MTRegisterContactFrameCallback(device, callback)
        MTDeviceStart(device, 0)
        NSLog("MultitouchManager started successfully")
    }

    private func handleTouches(touches: UnsafeMutablePointer<MTTouch>, count: Int) {
        let settings = GestureSettings.shared
        guard settings.isEnabled else { return }

        // Filter active touching fingers (state 2 = hovering/touching, 3/4/7 = active touch)
        var activeTouches: [MTTouch] = []
        for i in 0..<count {
            let t = touches[i]
            if t.state >= 2 {
                activeTouches.append(t)
            }
        }

        let fingerCount = activeTouches.count

        // --- GESTES A 4 DOIGTS ---
        if fingerCount == 4 {
            let avgY = activeTouches.reduce(0.0) { $0 + $1.normalized.position.y } / 4.0

            if let lastY = lastAverageY {
                let deltaY = avgY - lastY
                accumulatedDeltaY += deltaY

                let threshold: Float = 0.035 // Seuil de déplacement pour déclencher un palier

                if abs(accumulatedDeltaY) >= threshold {
                    let movingUp = accumulatedDeltaY > 0
                    DispatchQueue.main.async {
                        AppDelegate.shared?.executeAction(settings.fourFingerVerticalAction, up: movingUp)
                    }
                    accumulatedDeltaY = 0
                }
            }
            lastAverageY = avgY
            isTracking4Fingers = true
        } else {
            if isTracking4Fingers {
                lastAverageY = nil
                accumulatedDeltaY = 0
                isTracking4Fingers = false
            }
        }

        // --- GESTES A 3 DOIGTS (si activés) ---
        if fingerCount == 3 {
            if settings.threeFingerVerticalAction != .none {
                let avgY = activeTouches.reduce(0.0) { $0 + $1.normalized.position.y } / 3.0
                if let lastY = lastAverageY {
                    let deltaY = avgY - lastY
                    accumulatedDeltaY += deltaY
                    if abs(accumulatedDeltaY) >= 0.05 {
                        let movingUp = accumulatedDeltaY > 0
                        DispatchQueue.main.async {
                            AppDelegate.shared?.executeAction(settings.threeFingerVerticalAction, up: movingUp)
                        }
                        accumulatedDeltaY = 0
                    }
                }
                lastAverageY = avgY
            }

            if settings.threeFingerHorizontalAction != .none {
                let avgX = activeTouches.reduce(0.0) { $0 + $1.normalized.position.x } / 3.0
                if let lastX = lastAverageX {
                    let deltaX = avgX - lastX
                    accumulatedDeltaX += deltaX
                    if abs(accumulatedDeltaX) >= 0.06 {
                        let movingRight = accumulatedDeltaX > 0
                        DispatchQueue.main.async {
                            AppDelegate.shared?.executeAction(settings.threeFingerHorizontalAction, up: movingRight)
                        }
                        accumulatedDeltaX = 0
                    }
                }
                lastAverageX = avgX
            }
        } else if fingerCount != 4 {
            lastAverageX = nil
            accumulatedDeltaX = 0
        }
    }
}
