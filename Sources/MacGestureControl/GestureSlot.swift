// GestureSlot.swift
// Every bindable gesture, described once so the engine, the settings UI and
// persistence all stay in sync automatically.
import Foundation

/// How a slot is recognised by the multitouch engine.
enum GestureKind {
    case swipeVertical
    case swipeHorizontal
    case tap
    case pinchIn
    case pinchOut
    case cornerTap
}

/// Which tab a slot belongs to in the settings popover.
enum GestureGroup: String, CaseIterable, Identifiable {
    case fourFinger
    case threeFinger
    case corners

    var id: String { rawValue }

    var tabTitle: String {
        switch self {
        case .fourFinger: return "4 Fingers"
        case .threeFinger: return "3 Fingers"
        case .corners: return "Corners"
        }
    }

    var sectionTitle: String {
        switch self {
        case .fourFinger: return "4-FINGER GESTURES"
        case .threeFinger: return "3-FINGER GESTURES"
        case .corners: return "CORNER TAPS"
        }
    }

    var sectionIcon: String {
        switch self {
        case .fourFinger: return "hand.raised.fill"
        case .threeFinger: return "hand.point.up.left.fill"
        case .corners: return "square.grid.2x2.fill"
        }
    }

    var slots: [GestureSlot] { GestureSlot.allCases.filter { $0.group == self } }
}

enum GestureSlot: String, CaseIterable, Identifiable, Codable {
    case fourFingerVertical
    case fourFingerHorizontal
    case fourFingerTap
    case fourFingerPinchIn
    case fourFingerPinchOut

    case threeFingerVertical
    case threeFingerHorizontal
    case threeFingerTap
    case threeFingerPinchIn
    case threeFingerPinchOut

    case cornerTopLeft
    case cornerTopRight
    case cornerBottomLeft
    case cornerBottomRight

    var id: String { rawValue }

    var group: GestureGroup {
        switch self {
        case .fourFingerVertical, .fourFingerHorizontal, .fourFingerTap,
             .fourFingerPinchIn, .fourFingerPinchOut:
            return .fourFinger
        case .threeFingerVertical, .threeFingerHorizontal, .threeFingerTap,
             .threeFingerPinchIn, .threeFingerPinchOut:
            return .threeFinger
        case .cornerTopLeft, .cornerTopRight, .cornerBottomLeft, .cornerBottomRight:
            return .corners
        }
    }

    var kind: GestureKind {
        switch self {
        case .fourFingerVertical, .threeFingerVertical:
            return .swipeVertical
        case .fourFingerHorizontal, .threeFingerHorizontal:
            return .swipeHorizontal
        case .fourFingerTap, .threeFingerTap:
            return .tap
        case .fourFingerPinchIn, .threeFingerPinchIn:
            return .pinchIn
        case .fourFingerPinchOut, .threeFingerPinchOut:
            return .pinchOut
        case .cornerTopLeft, .cornerTopRight, .cornerBottomLeft, .cornerBottomRight:
            return .cornerTap
        }
    }

    /// Number of fingers that must be on the trackpad. Corner taps use one finger.
    var fingerCount: Int {
        switch group {
        case .fourFinger: return 4
        case .threeFinger: return 3
        case .corners: return 1
        }
    }

    /// Short label used inside its own tab ("Vertical Swipe").
    var title: String {
        switch kind {
        case .swipeVertical: return "Vertical Swipe"
        case .swipeHorizontal: return "Horizontal Swipe"
        case .tap: return "Single Tap"
        case .pinchIn: return "Pinch In"
        case .pinchOut: return "Spread Out"
        case .cornerTap:
            switch self {
            case .cornerTopLeft: return "Top-Left Corner"
            case .cornerTopRight: return "Top-Right Corner"
            case .cornerBottomLeft: return "Bottom-Left Corner"
            default: return "Bottom-Right Corner"
            }
        }
    }

    /// Fully qualified label used on the dashboard ("4-Finger Vertical Swipe").
    var fullTitle: String {
        switch group {
        case .fourFinger: return "4-Finger \(title)"
        case .threeFinger: return "3-Finger \(title)"
        case .corners: return title
        }
    }

    var subtitle: String {
        switch kind {
        case .swipeVertical: return "Slide up or down with \(fingerCount) fingers"
        case .swipeHorizontal: return "Slide left or right with \(fingerCount) fingers"
        case .tap: return "Brief tap with \(fingerCount) fingers"
        case .pinchIn: return "Draw \(fingerCount) fingers together"
        case .pinchOut: return "Spread \(fingerCount) fingers apart"
        case .cornerTap: return "One-finger tap in this trackpad corner"
        }
    }

    var icon: String {
        switch kind {
        case .swipeVertical: return "arrow.up.and.down"
        case .swipeHorizontal: return "arrow.left.and.right"
        case .tap: return "hand.tap.fill"
        case .pinchIn: return "arrow.down.right.and.arrow.up.left"
        case .pinchOut: return "arrow.up.left.and.arrow.down.right"
        case .cornerTap:
            switch self {
            case .cornerTopLeft: return "arrow.up.left.square"
            case .cornerTopRight: return "arrow.up.right.square"
            case .cornerBottomLeft: return "arrow.down.left.square"
            default: return "arrow.down.right.square"
            }
        }
    }

    /// Nothing is bound on a fresh install: every macOS trackpad gesture keeps
    /// working untouched until the user deliberately claims one.
    var defaultAction: GestureAction { .none }

    /// Key used by `UserDefaults`.
    var storageKey: String { "slot_\(rawValue)_v6" }
}
