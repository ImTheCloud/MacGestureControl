import XCTest
@testable import MacGestureControl

/// Drives the recogniser with synthetic touch frames — no trackpad, no side effects.
final class GestureRecognitionTests: XCTestCase {

    private var engine: MultitouchEngine!
    private var fired: [(action: GestureAction, slot: GestureSlot, up: Bool)] = []
    private var settings = SettingsSnapshot()
    private var clock: Double = 0

    /// Frames arrive at roughly the trackpad's reporting rate.
    private let frameInterval: Double = 1.0 / 120.0

    override func setUp() {
        super.setUp()
        fired = []
        clock = 0
        // An explicit configuration, so these tests describe recognition rather
        // than whatever the app happens to ship as defaults.
        var actions = Dictionary(uniqueKeysWithValues: GestureSlot.allCases.map { ($0, GestureAction.none) })
        actions[.fourFingerVertical] = .volume
        actions[.fourFingerTap] = .mediaPlayPause

        settings = SettingsSnapshot(
            isEnabled: true,
            invertDirection: false,
            sensitivity: 0.5,
            actions: actions
        )

        engine = MultitouchEngine.shared
        engine.resetForTesting()
        engine.settingsProvider = { [unowned self] in self.settings }
        engine.actionSink = { [unowned self] action, slot, up in
            self.fired.append((action, slot, up))
        }
    }

    override func tearDown() {
        engine.actionSink = nil
        engine.settingsProvider = { AppSettings.shared.snapshot }
        engine.resetForTesting()
        super.tearDown()
    }

    // MARK: - Frame helpers

    private func touch(_ id: Int32, _ x: Float, _ y: Float) -> MTTouch {
        var t = MTTouch(
            frame: 0, timestamp: 0, identifier: id, state: 4, fingerID: id, handID: 1,
            normalized: MTVector(position: MTPoint(x: x, y: y), velocity: MTPoint(x: 0, y: 0)),
            size: 1, pressure: 0, angle: 0, majorAxis: 1, minorAxis: 1,
            absolute: MTVector(position: MTPoint(x: x, y: y), velocity: MTPoint(x: 0, y: 0)),
            reserved1: 0, reserved2: 0, density: 1
        )
        t.state = 4
        return t
    }

    /// Fingers spread horizontally around a centre point, as a real hand lands.
    private func hand(count: Int, centreX: Float, centreY: Float) -> [MTTouch] {
        guard count > 0 else { return [] }
        let spacing: Float = 0.09
        let start = centreX - spacing * Float(count - 1) / 2
        return (0..<count).map { touch(Int32($0), start + spacing * Float($0), centreY) }
    }

    /// Fingers that keep their own place on the glass as contacts come and go.
    /// This is what the trackpad reports — lifting one finger does not slide the
    /// others — and it is the difference between a tap and a flick, so the
    /// landing and lifting tests build hands this way rather than with `hand`.
    private func steadyHand(_ ids: [Int32], centreY: Float = 0.5, jitter: Float = 0) -> [MTTouch] {
        ids.map { touch($0, 0.32 + 0.09 * Float($0) + jitter, centreY + jitter) }
    }

    private func send(_ touches: [MTTouch], frames: Int = 1) {
        for _ in 0..<frames {
            clock += frameInterval
            engine.handleFrame(device: nil, touches: touches, timestamp: clock)
        }
    }

    private func hold(_ seconds: Double, _ touches: [MTTouch]) {
        send(touches, frames: max(1, Int(seconds / frameInterval)))
    }

    // MARK: - Taps

    /// The reported bug: a 4-finger tap only worked about three times in four.
    /// Fingers land and lift a few milliseconds apart, which lurches the
    /// centroid; that lurch used to register as a swipe, nudging the volume and
    /// disqualifying the tap.
    func testStaggeredFourFingerTapFiresEveryTime() {
        for attempt in 0..<25 {
            engine.resetForTesting()
            fired = []

            // Fingers land one frame apart, each landing slightly off-centre.
            let jitter = Float(attempt % 5) * 0.004
            send(steadyHand([0], jitter: jitter))
            send(steadyHand([0, 1], jitter: jitter))
            send(steadyHand([0, 1, 2], jitter: jitter))
            hold(0.10, steadyHand([0, 1, 2, 3], jitter: jitter))
            // ...and lift one at a time, which drags the centroid across the pad.
            send(steadyHand([1, 2, 3], jitter: jitter))
            send(steadyHand([2, 3], jitter: jitter))
            send(steadyHand([3], jitter: jitter))
            send([])

            XCTAssertEqual(fired.count, 1, "attempt \(attempt): expected exactly one action")
            XCTAssertEqual(fired.first?.slot, .fourFingerTap, "attempt \(attempt)")
            XCTAssertEqual(fired.first?.action, .mediaPlayPause, "attempt \(attempt)")
        }
    }

    func testTapDoesNotFireWhenTheSlotIsUnassigned() {
        settings.actions[.fourFingerTap] = GestureAction.none
        hold(0.10, hand(count: 4, centreX: 0.5, centreY: 0.5))
        send([])
        XCTAssertTrue(fired.isEmpty)
    }

    func testLongRestIsNotATap() {
        hold(0.9, hand(count: 4, centreX: 0.5, centreY: 0.5))
        send([])
        XCTAssertTrue(fired.isEmpty, "resting four fingers must not trigger play/pause")
    }

    /// The reported bug: the two-finger action firing at random through the day.
    /// A quick scroll flick — fingers down, sideways, up, all inside 150 ms —
    /// never outlives the settle window, so the centroid it used to be judged on
    /// had not moved by the time the fingers left and it was read as a tap.
    func testQuickTwoFingerFlickIsNotATap() {
        settings.actions[.twoFingerTap] = .appExpose

        send(steadyHand([0, 1]))
        for step in 1...12 {
            let offset = Float(step) * 0.012
            send([touch(0, 0.32, 0.5 - offset), touch(1, 0.41, 0.5 - offset)])
        }
        send([])

        XCTAssertTrue(fired.isEmpty, "a two-finger scroll flick fired \(fired.map(\.slot))")
    }

    func testDeliberateTwoFingerTapStillFires() {
        settings.actions[.twoFingerTap] = .appExpose

        send(steadyHand([0]))
        hold(0.08, steadyHand([0, 1]))
        send(steadyHand([1]))
        send([])

        XCTAssertEqual(fired.map(\.slot), [.twoFingerTap])
    }

    func testThreeFingerTapUsesItsOwnBinding() {
        settings.actions[.threeFingerTap] = .screenshot
        hold(0.08, hand(count: 3, centreX: 0.5, centreY: 0.5))
        send([])
        XCTAssertEqual(fired.map(\.slot), [.threeFingerTap])
        XCTAssertEqual(fired.first?.action, .screenshot)
    }

    // MARK: - Swipes

    func testVerticalSwipeRepeatsForContinuousActions() {
        hold(0.15, hand(count: 4, centreX: 0.5, centreY: 0.30))
        for step in 1...30 {
            send(hand(count: 4, centreX: 0.5, centreY: 0.30 + Float(step) * 0.012))
        }
        send([])

        XCTAssertGreaterThan(fired.count, 3, "volume should step repeatedly during a long swipe")
        XCTAssertTrue(fired.allSatisfy { $0.slot == .fourFingerVertical && $0.action == .volume })
        XCTAssertTrue(fired.allSatisfy(\.up), "swiping up must raise the volume")
        XCTAssertFalse(fired.contains { $0.slot == .fourFingerTap }, "a swipe must never also tap")
    }

    func testSwipeDownLowersVolume() {
        hold(0.15, hand(count: 4, centreX: 0.5, centreY: 0.70))
        for step in 1...30 {
            send(hand(count: 4, centreX: 0.5, centreY: 0.70 - Float(step) * 0.012))
        }
        send([])
        XCTAssertFalse(fired.isEmpty)
        XCTAssertTrue(fired.allSatisfy { $0.up == false })
    }

    func testInvertDirectionFlipsTheSwipe() {
        settings.invertDirection = true
        hold(0.15, hand(count: 4, centreX: 0.5, centreY: 0.30))
        for step in 1...30 {
            send(hand(count: 4, centreX: 0.5, centreY: 0.30 + Float(step) * 0.012))
        }
        send([])
        XCTAssertFalse(fired.isEmpty)
        XCTAssertTrue(fired.allSatisfy { $0.up == false }, "inverted, swiping up must lower")
    }

    /// A long swipe bound to a discrete action must not skip a dozen tracks.
    func testDiscreteSwipeFiresOncePerSwipe() {
        settings.actions[.threeFingerHorizontal] = .mediaNext
        hold(0.15, hand(count: 3, centreX: 0.25, centreY: 0.5))
        for step in 1...40 {
            send(hand(count: 3, centreX: 0.25 + Float(step) * 0.012, centreY: 0.5))
        }
        send([])

        XCTAssertEqual(fired.count, 1)
        XCTAssertEqual(fired.first?.action, .mediaNext)
    }

    /// One binding covers both directions: the reverse swipe runs the opposite action.
    func testReverseSwipeRunsTheInverseAction() {
        settings.actions[.threeFingerHorizontal] = .mediaNext
        hold(0.15, hand(count: 3, centreX: 0.75, centreY: 0.5))
        for step in 1...40 {
            send(hand(count: 3, centreX: 0.75 - Float(step) * 0.012, centreY: 0.5))
        }
        send([])

        XCTAssertEqual(fired.count, 1)
        XCTAssertEqual(fired.first?.action, .mediaPrevious)
    }

    /// A diagonal swipe must commit to one axis, not fire both bindings.
    func testDiagonalSwipeLocksToASingleAxis() {
        settings.actions[.fourFingerHorizontal] = .mediaNext
        hold(0.15, hand(count: 4, centreX: 0.35, centreY: 0.35))
        for step in 1...40 {
            let delta = Float(step) * 0.012
            send(hand(count: 4, centreX: 0.35 + delta, centreY: 0.35 + delta))
        }
        send([])

        let slots = Set(fired.map(\.slot))
        XCTAssertEqual(slots.count, 1, "a diagonal swipe fired \(slots)")
    }

    func testUnassignedAxisStaysSilent() {
        // Horizontal is unbound by default; sliding sideways must do nothing.
        hold(0.15, hand(count: 4, centreX: 0.25, centreY: 0.5))
        for step in 1...40 {
            send(hand(count: 4, centreX: 0.25 + Float(step) * 0.012, centreY: 0.5))
        }
        send([])
        XCTAssertTrue(fired.isEmpty)
    }

    // MARK: - Pinch

    func testPinchFiresOnceAndBlocksTheTap() {
        settings.actions[.fourFingerPinchIn] = .missionControl
        hold(0.15, hand(count: 4, centreX: 0.5, centreY: 0.5))
        // Collapse the hand towards its centre.
        for step in 1...20 {
            let squeeze = 1.0 - Float(step) * 0.045
            let spacing = 0.09 * max(squeeze, 0.05)
            let touches = (0..<4).map { index in
                touch(Int32(index), 0.5 + spacing * (Float(index) - 1.5), 0.5)
            }
            send(touches)
        }
        send([])

        XCTAssertEqual(fired.count, 1)
        XCTAssertEqual(fired.first?.slot, .fourFingerPinchIn)
        XCTAssertEqual(fired.first?.action, .missionControl)
    }

    func testTwoFingerPinchIsLeftToMacOS() {
        // Zoom is a native two-finger gesture and has no slot of its own.
        XCTAssertNil(GestureSlot.allCases.first { $0.kind == .pinchIn && $0.fingerCount == 2 })
    }

    // MARK: - Corner taps

    func testCornerTapFiresOnlyInItsCorner() {
        settings.actions[.cornerBottomLeft] = .spotlight

        hold(0.08, [touch(0, 0.06, 0.07)])
        send([])
        XCTAssertEqual(fired.map(\.slot), [.cornerBottomLeft])

        fired = []
        hold(0.08, [touch(0, 0.5, 0.5)])
        send([])
        XCTAssertTrue(fired.isEmpty, "a tap in the middle is not a corner tap")

        fired = []
        hold(0.08, [touch(0, 0.06, 0.94)])
        send([])
        XCTAssertTrue(fired.isEmpty, "the opposite corner is unbound")
    }

    func testMovingOneFingerIsNotACornerTap() {
        settings.actions[.cornerBottomLeft] = .spotlight
        // Pointer movement starting from the corner.
        send([touch(0, 0.06, 0.07)])
        hold(0.05, [touch(0, 0.06, 0.07)])
        for step in 1...20 {
            send([touch(0, 0.06 + Float(step) * 0.02, 0.07)])
        }
        send([])
        XCTAssertTrue(fired.isEmpty)
    }

    // MARK: - Global state

    func testNothingFiresWhileDisabled() {
        settings.isEnabled = false
        hold(0.10, hand(count: 4, centreX: 0.5, centreY: 0.5))
        send([])
        XCTAssertTrue(fired.isEmpty)
    }

    func testHoverTouchesAreIgnored() {
        // State 2 is a hover, not a contact; it must not count as a finger.
        var hovering = hand(count: 4, centreX: 0.5, centreY: 0.5)
        for index in hovering.indices { hovering[index].state = 2 }
        hold(0.10, hovering)
        send([])
        XCTAssertTrue(fired.isEmpty)
    }

    // MARK: - Configuration coherence

    func testEverySlotIsReachableByTheRecogniser() {
        for slot in GestureSlot.allCases where slot.kind != .cornerTap {
            let match = GestureSlot.allCases.first {
                $0.kind == slot.kind && $0.fingerCount == slot.fingerCount
            }
            XCTAssertEqual(match, slot, "\(slot) is shadowed by another slot")
        }
    }

    func testInverseActionsArePairedBothWays() {
        for action in GestureAction.allCases {
            XCTAssertEqual(action.inverse.inverse, action, "\(action) has an asymmetric inverse")
        }
    }

    func testContinuousActionsHaveNoInverse() {
        for action in GestureAction.allCases where action.isContinuous {
            XCTAssertFalse(action.hasDistinctInverse, "\(action) handles direction itself")
        }
    }

    func testEveryActionIsOfferedInThePicker() {
        // The picker lists `.none` separately, then every category in turn.
        for action in GestureAction.allCases where action != .none {
            XCTAssertTrue(
                ActionCategory.allCases.contains(action.category),
                "\(action) would not appear in any menu section"
            )
        }
    }
}
