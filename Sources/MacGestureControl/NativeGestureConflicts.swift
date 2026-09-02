// NativeGestureConflicts.swift
// macOS keeps its own trackpad gestures, and MultitouchSupport is read-only, so
// a gesture we act on still reaches the system too. The only reliable fix is to
// turn the matching macOS gesture off — which this file does, on request.
import Foundation
import Combine

/// A macOS trackpad gesture that can collide with one of ours.
enum NativeGesture: String, CaseIterable, Identifiable {
    case fourFingerVerticalSwipe
    case fourFingerHorizontalSwipe
    case fourFingerPinch
    case threeFingerVerticalSwipe
    case threeFingerHorizontalSwipe
    case threeFingerTap

    var id: String { rawValue }

    /// Key inside the two trackpad preference domains.
    var trackpadKey: String {
        switch self {
        case .fourFingerVerticalSwipe: return "TrackpadFourFingerVertSwipeGesture"
        case .fourFingerHorizontalSwipe: return "TrackpadFourFingerHorizSwipeGesture"
        case .fourFingerPinch: return "TrackpadFourFingerPinchGesture"
        case .threeFingerVerticalSwipe: return "TrackpadThreeFingerVertSwipeGesture"
        case .threeFingerHorizontalSwipe: return "TrackpadThreeFingerHorizSwipeGesture"
        case .threeFingerTap: return "TrackpadThreeFingerTapGesture"
        }
    }

    /// Mirror of the same setting in the global domain, stored per host.
    var globalKey: String {
        switch self {
        case .fourFingerVerticalSwipe: return "com.apple.trackpad.fourFingerVertSwipeGesture"
        case .fourFingerHorizontalSwipe: return "com.apple.trackpad.fourFingerHorizSwipeGesture"
        case .fourFingerPinch: return "com.apple.trackpad.fourFingerPinchSwipeGesture"
        case .threeFingerVerticalSwipe: return "com.apple.trackpad.threeFingerVertSwipeGesture"
        case .threeFingerHorizontalSwipe: return "com.apple.trackpad.threeFingerHorizSwipeGesture"
        case .threeFingerTap: return "com.apple.trackpad.threeFingerTapGesture"
        }
    }

    /// What macOS does with it, phrased for the warning strip.
    var systemBehaviour: String {
        switch self {
        case .fourFingerVerticalSwipe: return "Mission Control and App Windows"
        case .fourFingerHorizontalSwipe: return "switching between desktops"
        case .fourFingerPinch: return "Launchpad and Show Desktop"
        case .threeFingerVerticalSwipe: return "Mission Control and App Windows"
        case .threeFingerHorizontalSwipe: return "switching between desktops"
        case .threeFingerTap: return "Look Up"
        }
    }
}

final class NativeGestureManager: ObservableObject {
    static let shared = NativeGestureManager()

    /// Which macOS gestures are currently switched on.
    @Published private(set) var isActive: [NativeGesture: Bool] = [:]

    /// Both trackpad kinds carry their own copy of the setting.
    private let trackpadDomains = [
        "com.apple.AppleMultitouchTrackpad",
        "com.apple.driver.AppleBluetoothMultitouch.trackpad"
    ]

    /// macOS writes 2 for an enabled gesture and 0 for a disabled one.
    private let enabledValue = 2
    private let disabledValue = 0

    /// Only the gestures this app switched off, so restoring never turns on
    /// something the user had chosen to keep off themselves.
    private var ownedDisables: Set<String> {
        didSet { UserDefaults.standard.set(Array(ownedDisables), forKey: Self.ownedKey) }
    }

    private static let ownedKey = "app_disabledNativeGestures_v6"

    private init() {
        ownedDisables = Set(UserDefaults.standard.stringArray(forKey: Self.ownedKey) ?? [])
        refresh()
    }

    /// How many macOS gestures this app is currently holding off.
    var disabledCount: Int {
        ownedDisables.filter { raw in
            guard let gesture = NativeGesture(rawValue: raw) else { return false }
            return !isActive(gesture)
        }.count
    }

    func isActive(_ gesture: NativeGesture) -> Bool {
        isActive[gesture] ?? true
    }

    func refresh() {
        var states: [NativeGesture: Bool] = [:]
        for gesture in NativeGesture.allCases {
            states[gesture] = readValue(gesture) != disabledValue
        }
        if states != isActive { isActive = states }
    }

    func setActive(_ active: Bool, for gesture: NativeGesture) {
        write(active ? enabledValue : disabledValue, for: gesture)
        if active {
            ownedDisables.remove(gesture.rawValue)
        } else {
            ownedDisables.insert(gesture.rawValue)
        }
        applySystemSettings()
        refresh()
    }

    /// Hands back any macOS gesture this app switched off that nothing is bound
    /// to any more — the binding was cleared, or the action behind it no longer
    /// exists. Without this the app leaves the trackpad quieter than it found
    /// it: the native gesture stays off, serving a binding that is long gone.
    func releaseUnusedDisables(isBound: (GestureSlot) -> Bool = { AppSettings.shared.action(for: $0) != .none }) {
        let orphans = Self.orphanedDisables(owned: ownedDisables, isBound: isBound)
        guard !orphans.isEmpty else { return }

        for gesture in orphans {
            write(enabledValue, for: gesture)
            ownedDisables.remove(gesture.rawValue)
        }
        applySystemSettings()
        refresh()
    }

    /// The decision behind `releaseUnusedDisables`, kept pure so it can be
    /// tested without writing to system preferences.
    static func orphanedDisables(owned: Set<String>, isBound: (GestureSlot) -> Bool) -> Set<NativeGesture> {
        let disabled = owned.compactMap(NativeGesture.init(rawValue:))
        return Set(disabled.filter { gesture in
            !GestureSlot.allCases.contains { $0.nativeConflict == gesture && isBound($0) }
        })
    }

    /// Puts back the macOS gestures this app switched off, and only those.
    func restoreAll() {
        for raw in ownedDisables {
            guard let gesture = NativeGesture(rawValue: raw) else { continue }
            write(enabledValue, for: gesture)
        }
        ownedDisables.removeAll()
        applySystemSettings()
        refresh()
    }

    // MARK: - Preferences

    /// The built-in trackpad domain is the source of truth for display; all
    /// three locations are kept in step when writing.
    private func readValue(_ gesture: NativeGesture) -> Int? {
        let domain = trackpadDomains[0] as CFString
        CFPreferencesAppSynchronize(domain)
        return CFPreferencesCopyAppValue(gesture.trackpadKey as CFString, domain) as? Int
    }

    private func write(_ value: Int, for gesture: NativeGesture) {
        for domain in trackpadDomains {
            CFPreferencesSetValue(
                gesture.trackpadKey as CFString,
                value as CFNumber,
                domain as CFString,
                kCFPreferencesCurrentUser,
                kCFPreferencesAnyHost
            )
            CFPreferencesSynchronize(domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        }

        // The global domain copy is stored per host, matching `defaults -currentHost`.
        CFPreferencesSetValue(
            gesture.globalKey as CFString,
            value as CFNumber,
            kCFPreferencesAnyApplication,
            kCFPreferencesCurrentUser,
            kCFPreferencesCurrentHost
        )
        CFPreferencesSynchronize(kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost)
    }

    /// Makes the driver re-read the preferences, so the change takes effect
    /// without logging out.
    private func applySystemSettings() {
        let tool = "/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings"
        guard FileManager.default.isExecutableFile(atPath: tool) else { return }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: tool)
        task.arguments = ["-u"]
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            NSLog("[NativeGestureManager] activateSettings failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Slot mapping

extension GestureSlot {
    /// The macOS gesture this slot collides with, when there is one we can switch off.
    var nativeConflict: NativeGesture? {
        switch self {
        case .fourFingerVertical: return .fourFingerVerticalSwipe
        case .fourFingerHorizontal: return .fourFingerHorizontalSwipe
        case .fourFingerPinchIn, .fourFingerPinchOut: return .fourFingerPinch
        case .threeFingerVertical: return .threeFingerVerticalSwipe
        case .threeFingerHorizontal: return .threeFingerHorizontalSwipe
        case .threeFingerTap: return .threeFingerTap
        default: return nil
        }
    }

    /// A collision macOS offers no setting for, so it can only be explained.
    var unavoidableConflict: String? {
        switch self {
        case .cornerTopLeft, .cornerTopRight, .cornerBottomLeft, .cornerBottomRight:
            return "With “tap to click” on, a corner tap also clicks wherever the pointer is."
        default:
            return nil
        }
    }
}
