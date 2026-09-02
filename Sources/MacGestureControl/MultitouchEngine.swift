// MultitouchEngine.swift
// Reads the trackpad directly through the private MultitouchSupport framework
// and turns raw finger frames into the gestures configured in AppSettings.
import Foundation
import AppKit

// MARK: - MultitouchSupport C layout

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
    var fingerID: Int32
    var handID: Int32
    var normalized: MTVector
    var size: Float
    var pressure: Int32
    var angle: Float
    var majorAxis: Float
    var minorAxis: Float
    var absolute: MTVector
    var reserved1: Int32
    var reserved2: Int32
    var density: Float
}

/// Touch phases reported by the framework. Only 3 (making contact) and
/// 4 (touching) mean a finger is actually resting on the glass — 2 is a hover
/// and 5/6/7 are lift-off and out-of-range, and counting those made the finger
/// count flicker mid-gesture.
private let touchingStates: ClosedRange<Int32> = 3...4

typealias MTDeviceRef = OpaquePointer
typealias MTContactCallbackFunction = @convention(c) (MTDeviceRef?, UnsafeMutableRawPointer?, Int32, Double, Int32) -> Int32

// MARK: - Live radar model

struct TrackpadTouch: Identifiable {
    let id: Int
    let normalizedX: CGFloat
    let normalizedY: CGFloat
}

// MARK: - Engine

final class MultitouchEngine: ObservableObject {
    static let shared = MultitouchEngine()

    /// Finger positions for the settings radar. Only produced while the
    /// settings popover is actually on screen.
    @Published var activeTouches: [TrackpadTouch] = []
    /// Slot that fired most recently, so its row can flash in the UI.
    @Published var lastTriggeredSlot: GestureSlot?

    // MARK: Framework handles
    private var deviceList: CFArray?
    private var devices: [MTDeviceRef] = []
    private var isRunning = false
    private var hasWakeObserver = false

    private var mtDeviceStart: (@convention(c) (MTDeviceRef?, Int32) -> Void)?
    private var mtDeviceStop: (@convention(c) (MTDeviceRef?) -> Void)?
    private var mtRegisterCallback: (@convention(c) (MTDeviceRef?, MTContactCallbackFunction) -> Void)?
    private var mtUnregisterCallback: (@convention(c) (MTDeviceRef?, MTContactCallbackFunction) -> Void)?

    /// Frames from two trackpads arrive on separate threads, so recognition is
    /// serialised rather than left to race over the session state.
    private let frameLock = NSLock()

    // MARK: Radar gating (touched from the multitouch thread)
    private let stateLock = NSLock()
    private var radarObservers = 0
    private var lastRadarPublish: Double = 0

    // MARK: Recognition tuning
    /// Time the finger count must hold steady before movement counts. Fingers
    /// never land together, and the centroid lurches while they arrive — the
    /// old code read that lurch as a swipe, which both nudged the volume and
    /// disqualified the tap that followed.
    private let settleDuration: Double = 0.09
    private let maxTapDuration: Double = 0.40
    private let maxTapDrift: Float = 0.055
    private let baseVerticalThreshold: Float = 0.030
    private let baseHorizontalThreshold: Float = 0.045
    private let basePinchThreshold: Float = 0.050
    /// Discrete actions need a more deliberate swipe than continuous ones.
    private let discreteThresholdFactor: Float = 1.6

    // MARK: Session state (multitouch thread only)
    private enum AxisLock { case none, vertical, horizontal, pinch }

    private var sessionActive = false
    private var sessionDevice: MTDeviceRef?
    private var sessionStart: Double = 0
    private var sessionMaxFingers = 0
    private var frameFingerCount = 0
    private var settleUntil: Double = 0
    private var originX: Float = 0
    private var originY: Float = 0
    private var lastX: Float?
    private var lastY: Float?
    private var accumulatedX: Float = 0
    private var accumulatedY: Float = 0
    private var maxDrift: Float = 0
    private var touchOrigins: [Int32: MTPoint] = [:]
    private var maxFingerDrift: Float = 0
    private var pinchReference: Float?
    private var axisLock: AxisLock = .none
    private var didTriggerMotion = false
    private var firedDiscrete: Set<String> = []

    // MARK: Injection points
    //
    // Two seams keep the recogniser testable without it reaching into the app:
    // recognition is a pure function of the frames it is fed plus the settings
    // it reads, so a test can supply both.

    /// Settings used while recognising. Replaced in tests.
    var settingsProvider: () -> SettingsSnapshot = { AppSettings.shared.snapshot }
    /// Receives recognised gestures. When nil they are performed for real.
    var actionSink: ((GestureAction, GestureSlot, Bool) -> Void)?

    private init() {}

    // MARK: - Lifecycle

    func start() {
        guard !isRunning else { return }

        guard let handle = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_NOW) else {
            NSLog("[MultitouchEngine] MultitouchSupport framework not available")
            return
        }

        guard let startSym = dlsym(handle, "MTDeviceStart"),
              let stopSym = dlsym(handle, "MTDeviceStop"),
              let registerSym = dlsym(handle, "MTRegisterContactFrameCallback"),
              let unregisterSym = dlsym(handle, "MTUnregisterContactFrameCallback") else {
            NSLog("[MultitouchEngine] Failed to resolve MultitouchSupport symbols")
            return
        }

        mtDeviceStart = unsafeBitCast(startSym, to: (@convention(c) (MTDeviceRef?, Int32) -> Void).self)
        mtDeviceStop = unsafeBitCast(stopSym, to: (@convention(c) (MTDeviceRef?) -> Void).self)
        mtRegisterCallback = unsafeBitCast(registerSym, to: (@convention(c) (MTDeviceRef?, MTContactCallbackFunction) -> Void).self)
        mtUnregisterCallback = unsafeBitCast(unregisterSym, to: (@convention(c) (MTDeviceRef?, MTContactCallbackFunction) -> Void).self)

        devices = resolveDevices(handle: handle)
        guard !devices.isEmpty else {
            NSLog("[MultitouchEngine] No multitouch device found")
            return
        }

        for device in devices {
            mtRegisterCallback?(device, MultitouchEngine.frameCallback)
            mtDeviceStart?(device, 0)
        }
        isRunning = true
        NSLog("[MultitouchEngine] Started with \(devices.count) device(s)")

        observeWake()
    }

    func stop() {
        guard isRunning else { return }
        for device in devices {
            mtDeviceStop?(device)
            mtUnregisterCallback?(device, MultitouchEngine.frameCallback)
        }
        isRunning = false
        resetSession()
    }

    /// Every trackpad and Magic Trackpad attached to the Mac, so an external
    /// trackpad works exactly like the built-in one.
    private func resolveDevices(handle: UnsafeMutableRawPointer) -> [MTDeviceRef] {
        if let listSym = dlsym(handle, "MTDeviceCreateList") {
            let createList = unsafeBitCast(listSym, to: (@convention(c) () -> Unmanaged<CFArray>?).self)
            if let list = createList()?.takeRetainedValue() {
                // Held for the lifetime of the engine: the array owns the devices.
                deviceList = list
                let count = CFArrayGetCount(list)
                let found = (0..<count).compactMap { index -> MTDeviceRef? in
                    guard let raw = CFArrayGetValueAtIndex(list, index) else { return nil }
                    return MTDeviceRef(raw)
                }
                if !found.isEmpty { return found }
            }
        }

        if let defaultSym = dlsym(handle, "MTDeviceCreateDefault") {
            let createDefault = unsafeBitCast(defaultSym, to: (@convention(c) () -> MTDeviceRef?).self)
            if let device = createDefault() { return [device] }
        }
        return []
    }

    /// The framework stops delivering frames after the Mac sleeps, so the
    /// devices have to be restarted on wake or gestures silently stop working.
    private func observeWake() {
        guard !hasWakeObserver else { return }
        hasWakeObserver = true
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.isRunning else { return }
            for device in self.devices {
                self.mtDeviceStop?(device)
                self.mtDeviceStart?(device, 0)
            }
            self.resetSession()
        }
    }

    // MARK: - Radar gating

    func beginRadarUpdates() {
        stateLock.lock()
        radarObservers += 1
        stateLock.unlock()
    }

    func endRadarUpdates() {
        stateLock.lock()
        radarObservers = max(0, radarObservers - 1)
        let stillObserved = radarObservers > 0
        stateLock.unlock()
        if !stillObserved {
            DispatchQueue.main.async { self.activeTouches = [] }
        }
    }

    private var radarIsObserved: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return radarObservers > 0
    }

    func flash(_ slot: GestureSlot) {
        lastTriggeredSlot = slot
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self, self.lastTriggeredSlot == slot else { return }
            self.lastTriggeredSlot = nil
        }
    }

    // MARK: - Frame handling

    private static let frameCallback: MTContactCallbackFunction = { device, rawTouches, numTouches, timestamp, _ in
        let count = Int(numTouches)
        guard count > 0, let rawTouches else {
            MultitouchEngine.shared.handleFrame(device: device, touches: [], timestamp: timestamp)
            return 0
        }
        let buffer = rawTouches.bindMemory(to: MTTouch.self, capacity: count)
        MultitouchEngine.shared.handleFrame(
            device: device,
            touches: (0..<count).map { buffer[$0] },
            timestamp: timestamp
        )
        return 0
    }

    /// Entry point for one frame of touches. Everything downstream is driven
    /// only by these arguments and `settingsProvider`.
    func handleFrame(device: MTDeviceRef?, touches rawTouches: [MTTouch], timestamp: Double) {
        frameLock.lock()
        defer { frameLock.unlock() }

        // Hovering and lifting contacts are discarded here rather than at the
        // C callback, so this stays the single boundary where a raw frame
        // becomes a finger count.
        let touches = rawTouches.filter { touchingStates.contains($0.state) }
        let settings = settingsProvider()

        guard settings.isEnabled else {
            if sessionActive { resetSession() }
            publishRadar([], timestamp: timestamp, force: true)
            return
        }

        // A second trackpad must not interfere with a gesture already in flight.
        if sessionActive, let device, let sessionDevice, device != sessionDevice, !touches.isEmpty {
            return
        }

        publishRadar(touches, timestamp: timestamp, force: touches.isEmpty)

        let fingerCount = touches.count

        if fingerCount == 0 {
            if sessionActive { finishSession(at: timestamp, settings: settings) }
            return
        }

        trackFingerDrift(touches)

        let centroidX = touches.reduce(Float(0)) { $0 + $1.normalized.position.x } / Float(fingerCount)
        let centroidY = touches.reduce(Float(0)) { $0 + $1.normalized.position.y } / Float(fingerCount)

        if !sessionActive {
            sessionActive = true
            sessionDevice = device
            sessionStart = timestamp
            sessionMaxFingers = fingerCount
            frameFingerCount = fingerCount
            axisLock = .none
            didTriggerMotion = false
            firedDiscrete.removeAll(keepingCapacity: true)
            maxDrift = 0
            rebase(x: centroidX, y: centroidY, at: timestamp)
            return
        }

        // Finger count changed: fingers are still arriving or leaving, so the
        // centroid is meaningless right now. Re-anchor and wait for it to settle.
        if fingerCount != frameFingerCount {
            frameFingerCount = fingerCount
            sessionMaxFingers = max(sessionMaxFingers, fingerCount)
            rebase(x: centroidX, y: centroidY, at: timestamp)
            return
        }

        if timestamp < settleUntil {
            originX = centroidX
            originY = centroidY
            lastX = nil
            lastY = nil
            pinchReference = nil
            return
        }

        let drift = hypot(centroidX - originX, centroidY - originY)
        maxDrift = max(maxDrift, drift)

        let spread = averageSpread(touches, centroidX: centroidX, centroidY: centroidY)

        guard let previousX = lastX, let previousY = lastY else {
            lastX = centroidX
            lastY = centroidY
            pinchReference = spread
            return
        }

        accumulatedX += centroidX - previousX
        accumulatedY += centroidY - previousY
        lastX = centroidX
        lastY = centroidY

        evaluatePinch(fingerCount: fingerCount, spread: spread, settings: settings)
        evaluateSwipe(fingerCount: fingerCount, settings: settings)
    }

    /// Restart movement tracking from the current position without ending the session.
    private func rebase(x: Float, y: Float, at timestamp: Double) {
        originX = x
        originY = y
        lastX = nil
        lastY = nil
        accumulatedX = 0
        accumulatedY = 0
        pinchReference = nil
        settleUntil = timestamp + settleDuration
    }

    /// How far the fingers themselves have travelled since they landed.
    ///
    /// The centroid cannot answer that: it is re-anchored every time the finger
    /// count changes and ignored during the settle window, so a quick flick —
    /// fingers down, scroll, up, all inside 150 ms — used to reach
    /// lift-off with a drift of zero and be reported as a tap. Each contact
    /// keeps its own landing point instead, which no re-anchoring touches.
    private func trackFingerDrift(_ touches: [MTTouch]) {
        for touch in touches {
            let position = touch.normalized.position
            guard let origin = touchOrigins[touch.identifier] else {
                touchOrigins[touch.identifier] = position
                continue
            }
            maxFingerDrift = max(maxFingerDrift, hypot(position.x - origin.x, position.y - origin.y))
        }
    }

    /// Mean distance from the centroid. Unlike the distance between the first
    /// two touches in the buffer, this does not jump when the framework
    /// reorders contacts between frames, and it works for 3 and 4 fingers.
    private func averageSpread(_ touches: [MTTouch], centroidX: Float, centroidY: Float) -> Float {
        guard touches.count >= 2 else { return 0 }
        let total = touches.reduce(Float(0)) {
            $0 + hypot($1.normalized.position.x - centroidX, $1.normalized.position.y - centroidY)
        }
        return total / Float(touches.count)
    }

    // MARK: - Recognition

    private func slot(_ kind: GestureKind, fingers: Int) -> GestureSlot? {
        GestureSlot.allCases.first { $0.kind == kind && $0.fingerCount == fingers }
    }

    private func evaluatePinch(fingerCount: Int, spread: Float, settings: SettingsSnapshot) {
        guard axisLock == .none || axisLock == .pinch else { return }
        guard let inSlot = slot(.pinchIn, fingers: fingerCount),
              let outSlot = slot(.pinchOut, fingers: fingerCount) else { return }

        let pinchIn = settings.action(for: inSlot)
        let pinchOut = settings.action(for: outSlot)
        guard pinchIn != .none || pinchOut != .none else { return }
        guard let reference = pinchReference else { return }

        let threshold = basePinchThreshold * settings.thresholdScale
        let delta = spread - reference

        if delta > threshold, pinchOut != .none {
            axisLock = .pinch
            pinchReference = spread
            fire(pinchOut, slot: outSlot, direction: 1, once: true)
        } else if delta < -threshold, pinchIn != .none {
            axisLock = .pinch
            pinchReference = spread
            fire(pinchIn, slot: inSlot, direction: -1, once: true)
        }
    }

    private func evaluateSwipe(fingerCount: Int, settings: SettingsSnapshot) {
        guard let verticalSlot = slot(.swipeVertical, fingers: fingerCount),
              let horizontalSlot = slot(.swipeHorizontal, fingers: fingerCount) else { return }

        let vertical = settings.action(for: verticalSlot)
        let horizontal = settings.action(for: horizontalSlot)

        let verticalThreshold = threshold(baseVerticalThreshold, for: vertical, settings: settings)
        let horizontalThreshold = threshold(baseHorizontalThreshold, for: horizontal, settings: settings)

        // Pick the dominant axis once, so a diagonal swipe cannot fire both.
        if axisLock == .none {
            let verticalRatio = vertical == .none ? 0 : abs(accumulatedY) / verticalThreshold
            let horizontalRatio = horizontal == .none ? 0 : abs(accumulatedX) / horizontalThreshold
            guard verticalRatio >= 1 || horizontalRatio >= 1 else { return }
            axisLock = verticalRatio >= horizontalRatio ? .vertical : .horizontal
        }

        switch axisLock {
        case .vertical:
            guard vertical != .none, abs(accumulatedY) >= verticalThreshold else { return }
            let forward = (accumulatedY > 0) != settings.invertDirection
            accumulatedY -= (accumulatedY > 0 ? verticalThreshold : -verticalThreshold)
            accumulatedX = 0
            fire(forward ? vertical : vertical.inverse,
                 slot: verticalSlot,
                 direction: forward ? 1 : -1,
                 once: !vertical.isContinuous,
                 continuousUp: forward)
        case .horizontal:
            guard horizontal != .none, abs(accumulatedX) >= horizontalThreshold else { return }
            let forward = (accumulatedX > 0) != settings.invertDirection
            accumulatedX -= (accumulatedX > 0 ? horizontalThreshold : -horizontalThreshold)
            accumulatedY = 0
            fire(forward ? horizontal : horizontal.inverse,
                 slot: horizontalSlot,
                 direction: forward ? 1 : -1,
                 once: !horizontal.isContinuous,
                 continuousUp: forward)
        case .pinch, .none:
            return
        }
    }

    private func threshold(_ base: Float, for action: GestureAction, settings: SettingsSnapshot) -> Float {
        let scaled = base * settings.thresholdScale
        return action.isContinuous ? scaled : scaled * discreteThresholdFactor
    }

    private func finishSession(at timestamp: Double, settings: SettingsSnapshot) {
        let duration = timestamp - sessionStart
        let fingers = sessionMaxFingers

        // A tap is a touch that never became a swipe or a pinch, stayed brief,
        // and barely moved — neither the hand as a whole nor any single finger.
        let isTap = !didTriggerMotion
            && duration < maxTapDuration
            && maxDrift < maxTapDrift
            && maxFingerDrift < maxTapDrift

        if isTap {
            if fingers == 1 {
                fireCornerTap(settings: settings)
            } else if let tapSlot = slot(.tap, fingers: fingers) {
                let action = settings.action(for: tapSlot)
                if action != .none {
                    fire(action, slot: tapSlot, direction: 0, once: true)
                }
            }
        }

        resetSession()
    }

    private func fireCornerTap(settings: SettingsSnapshot) {
        // Normalized coordinates put (0, 0) at the bottom-left of the trackpad.
        let slot: GestureSlot?
        switch (originX, originY) {
        case let (x, y) where x < 0.18 && y > 0.82: slot = .cornerTopLeft
        case let (x, y) where x > 0.82 && y > 0.82: slot = .cornerTopRight
        case let (x, y) where x < 0.18 && y < 0.18: slot = .cornerBottomLeft
        case let (x, y) where x > 0.82 && y < 0.18: slot = .cornerBottomRight
        default: slot = nil
        }
        guard let slot else { return }
        let action = settings.action(for: slot)
        guard action != .none else { return }
        fire(action, slot: slot, direction: 0, once: true)
    }

    private func fire(_ action: GestureAction,
                      slot: GestureSlot,
                      direction: Int,
                      once: Bool,
                      continuousUp: Bool = true) {
        if once {
            let key = "\(slot.rawValue)#\(direction)"
            guard !firedDiscrete.contains(key) else { return }
            firedDiscrete.insert(key)
        }
        didTriggerMotion = true

        if let actionSink {
            actionSink(action, slot, continuousUp)
            return
        }
        DispatchQueue.main.async {
            SystemController.shared.execute(action, up: continuousUp)
            self.flash(slot)
        }
    }

    /// Clears all in-flight gesture state. Exposed so tests start from a known point.
    func resetForTesting() {
        frameLock.lock()
        defer { frameLock.unlock() }
        resetSession()
    }

    private func resetSession() {
        sessionActive = false
        sessionDevice = nil
        sessionMaxFingers = 0
        frameFingerCount = 0
        settleUntil = 0
        originX = 0
        originY = 0
        lastX = nil
        lastY = nil
        accumulatedX = 0
        accumulatedY = 0
        maxDrift = 0
        touchOrigins.removeAll(keepingCapacity: true)
        maxFingerDrift = 0
        pinchReference = nil
        axisLock = .none
        didTriggerMotion = false
        firedDiscrete.removeAll(keepingCapacity: true)
    }

    // MARK: - Radar

    private func publishRadar(_ touches: [MTTouch], timestamp: Double, force: Bool) {
        guard radarIsObserved else { return }
        // 30 Hz is plenty for a visualiser and keeps the main queue free.
        guard force || timestamp - lastRadarPublish >= 1.0 / 30.0 else { return }
        lastRadarPublish = timestamp

        let points = touches.map {
            TrackpadTouch(
                id: Int($0.identifier),
                normalizedX: CGFloat($0.normalized.position.x),
                normalizedY: CGFloat(1.0 - $0.normalized.position.y)
            )
        }
        DispatchQueue.main.async { self.activeTouches = points }
    }
}
