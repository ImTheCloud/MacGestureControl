// AppSettings.swift
import Foundation
import Combine

/// Immutable copy of everything the realtime multitouch thread needs.
///
/// The engine runs on a high-priority HID callback thread while `AppSettings`
/// is an `ObservableObject` owned by the main thread, so the engine never
/// touches the published properties directly — it grabs one of these per frame.
struct SettingsSnapshot {
    var isEnabled: Bool = true
    var invertDirection: Bool = false
    /// 0 = deliberate, long swipes. 1 = hair trigger. 0.5 is the default.
    var sensitivity: Double = 0.5
    var actions: [GestureSlot: GestureAction] = [:]

    func action(for slot: GestureSlot) -> GestureAction {
        actions[slot] ?? .none
    }

    /// Multiplier applied to every movement threshold. Higher sensitivity means
    /// a shorter swipe is needed, so the multiplier shrinks.
    var thresholdScale: Float {
        Float(1.45 - 0.9 * min(max(sensitivity, 0), 1))
    }
}

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    // MARK: - Global switches
    @Published var isEnabled: Bool { didSet { defaults.set(isEnabled, forKey: Keys.isEnabled); refreshSnapshot() } }
    @Published var hapticsEnabled: Bool { didSet { defaults.set(hapticsEnabled, forKey: Keys.haptics) } }
    @Published var showHUD: Bool { didSet { defaults.set(showHUD, forKey: Keys.showHUD) } }
    @Published var invertDirection: Bool { didSet { defaults.set(invertDirection, forKey: Keys.invertDirection); refreshSnapshot() } }
    @Published var sensitivity: Double { didSet { defaults.set(sensitivity, forKey: Keys.sensitivity); refreshSnapshot() } }
    @Published var launchTargetBundleId: String { didSet { defaults.set(launchTargetBundleId, forKey: Keys.launchTarget) } }

    // MARK: - Gesture bindings
    @Published private(set) var actions: [GestureSlot: GestureAction]

    // MARK: - Realtime snapshot
    private let snapshotLock = NSLock()
    private var storedSnapshot = SettingsSnapshot()

    /// Thread-safe view of the settings, safe to call from the multitouch thread.
    var snapshot: SettingsSnapshot {
        snapshotLock.lock()
        defer { snapshotLock.unlock() }
        return storedSnapshot
    }

    private enum Keys {
        static let isEnabled = "app_isEnabled_v6"
        static let haptics = "app_haptics_v6"
        static let showHUD = "app_showHUD_v6"
        static let invertDirection = "app_invertDirection_v6"
        static let sensitivity = "app_sensitivity_v6"
        static let launchTarget = "app_launchTarget_v6"
    }

    /// The app's glyph, used by the menu bar item and the popover header.
    static let appGlyph = "hand.draw.fill"

    private init() {
        isEnabled = defaults.object(forKey: Keys.isEnabled) as? Bool ?? true
        hapticsEnabled = defaults.object(forKey: Keys.haptics) as? Bool ?? true
        showHUD = defaults.object(forKey: Keys.showHUD) as? Bool ?? true
        invertDirection = defaults.object(forKey: Keys.invertDirection) as? Bool ?? false
        sensitivity = defaults.object(forKey: Keys.sensitivity) as? Double ?? 0.5
        launchTargetBundleId = defaults.string(forKey: Keys.launchTarget) ?? "com.apple.Notes"

        var loaded: [GestureSlot: GestureAction] = [:]
        for slot in GestureSlot.allCases {
            // An unreadable or retired action name falls back to the default,
            // so a binding left over from an older build cannot break a launch.
            let raw = defaults.string(forKey: slot.storageKey)
            loaded[slot] = raw.flatMap(GestureAction.init(rawValue:)) ?? slot.defaultAction
        }
        actions = loaded

        refreshSnapshot()
    }

    // MARK: - Binding access
    func action(for slot: GestureSlot) -> GestureAction {
        actions[slot] ?? .none
    }

    func setAction(_ action: GestureAction, for slot: GestureSlot) {
        guard actions[slot] != action else { return }
        actions[slot] = action
        defaults.set(action.rawValue, forKey: slot.storageKey)
        refreshSnapshot()
    }

    /// Slots currently bound to something, in declaration order.
    var assignedSlots: [GestureSlot] {
        GestureSlot.allCases.filter { action(for: $0) != .none }
    }

    var usesLaunchApp: Bool {
        actions.values.contains(.launchApp)
    }

    // MARK: - Reset
    func resetToDefaults() {
        for slot in GestureSlot.allCases {
            setAction(slot.defaultAction, for: slot)
        }
        sensitivity = 0.5
        invertDirection = false
        hapticsEnabled = true
        showHUD = true
        isEnabled = true
    }

    private func refreshSnapshot() {
        let fresh = SettingsSnapshot(
            isEnabled: isEnabled,
            invertDirection: invertDirection,
            sensitivity: sensitivity,
            actions: actions
        )
        snapshotLock.lock()
        storedSnapshot = fresh
        snapshotLock.unlock()
    }
}
