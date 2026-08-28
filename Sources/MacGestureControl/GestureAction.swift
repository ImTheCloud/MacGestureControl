// GestureAction.swift
// Every action a gesture can be bound to, plus the metadata the UI needs to render it.
import Foundation

/// Menu grouping so the action picker stays readable as the catalogue grows.
enum ActionCategory: String, CaseIterable, Identifiable {
    case audio = "Audio"
    case display = "Display"
    case media = "Media"
    case windows = "Windows"
    case desktop = "Desktop & Spaces"
    case system = "System"

    var id: String { rawValue }
}

enum GestureAction: String, CaseIterable, Identifiable, Codable {
    case none = "none"

    // Audio
    case volume = "volume"
    case toggleMute = "toggle_mute"

    // Display
    case brightness = "brightness"
    case sleepDisplay = "sleep_display"
    case lockScreen = "lock_screen"

    // Media
    case mediaPlayPause = "media_play_pause"
    case mediaNext = "media_next"
    case mediaPrevious = "media_previous"

    // Windows
    case snapLeft = "snap_left"
    case snapRight = "snap_right"
    case snapTop = "snap_top"
    case snapBottom = "snap_bottom"
    case maximizeWindow = "maximize_window"
    case centerWindow = "center_window"
    case minimizeWindow = "minimize_window"
    case fullScreenWindow = "fullscreen_window"
    case closeWindow = "close_window"

    // Desktop & Spaces
    case missionControl = "mission_control"
    case appExpose = "app_expose"
    case showDesktop = "show_desktop"
    case nextSpace = "next_space"
    case previousSpace = "previous_space"

    // System
    case screenshot = "screenshot"
    case spotlight = "spotlight"
    case middleClick = "middle_click"
    case launchApp = "launch_app"

    var id: String { rawValue }

    var category: ActionCategory {
        switch self {
        case .volume, .toggleMute:
            return .audio
        case .brightness, .sleepDisplay, .lockScreen:
            return .display
        case .mediaPlayPause, .mediaNext, .mediaPrevious:
            return .media
        case .snapLeft, .snapRight, .snapTop, .snapBottom, .maximizeWindow,
             .centerWindow, .minimizeWindow, .fullScreenWindow, .closeWindow:
            return .windows
        case .missionControl, .appExpose, .showDesktop, .nextSpace, .previousSpace:
            return .desktop
        case .screenshot, .spotlight, .middleClick, .launchApp, .none:
            return .system
        }
    }

    /// Full name, used in the action picker.
    var title: String {
        switch self {
        case .none: return "Disabled"
        case .volume: return "System Volume"
        case .toggleMute: return "Mute / Unmute Audio"
        case .brightness: return "Screen Brightness"
        case .sleepDisplay: return "Sleep Display"
        case .lockScreen: return "Lock Screen"
        case .mediaPlayPause: return "Play / Pause"
        case .mediaNext: return "Next Track"
        case .mediaPrevious: return "Previous Track"
        case .snapLeft: return "Snap Left Half"
        case .snapRight: return "Snap Right Half"
        case .snapTop: return "Snap Top Half"
        case .snapBottom: return "Snap Bottom Half"
        case .maximizeWindow: return "Maximize Window"
        case .centerWindow: return "Center Window"
        case .minimizeWindow: return "Minimize Window"
        case .fullScreenWindow: return "Toggle Full Screen"
        case .closeWindow: return "Close Window"
        case .missionControl: return "Mission Control"
        case .appExpose: return "App Exposé"
        case .showDesktop: return "Show Desktop"
        case .nextSpace: return "Next Desktop"
        case .previousSpace: return "Previous Desktop"
        case .screenshot: return "Screenshot to Clipboard"
        case .spotlight: return "Spotlight Search"
        case .middleClick: return "Middle Click"
        case .launchApp: return "Launch Application"
        }
    }

    /// Condensed name, used on the compact picker button inside a row.
    var shortTitle: String {
        switch self {
        case .none: return "Disabled"
        case .volume: return "Volume"
        case .toggleMute: return "Mute"
        case .brightness: return "Brightness"
        case .sleepDisplay: return "Sleep Display"
        case .lockScreen: return "Lock Screen"
        case .mediaPlayPause: return "Play / Pause"
        case .mediaNext: return "Next Track"
        case .mediaPrevious: return "Prev Track"
        case .snapLeft: return "Snap Left"
        case .snapRight: return "Snap Right"
        case .snapTop: return "Snap Top"
        case .snapBottom: return "Snap Bottom"
        case .maximizeWindow: return "Maximize"
        case .centerWindow: return "Center"
        case .minimizeWindow: return "Minimize"
        case .fullScreenWindow: return "Full Screen"
        case .closeWindow: return "Close Window"
        case .missionControl: return "Mission Control"
        case .appExpose: return "App Exposé"
        case .showDesktop: return "Show Desktop"
        case .nextSpace: return "Next Desktop"
        case .previousSpace: return "Prev Desktop"
        case .screenshot: return "Screenshot"
        case .spotlight: return "Spotlight"
        case .middleClick: return "Middle Click"
        case .launchApp: return "Launch App"
        }
    }

    var icon: String {
        switch self {
        case .none: return "slash.circle"
        case .volume: return "speaker.wave.3.fill"
        case .toggleMute: return "speaker.slash.fill"
        case .brightness: return "sun.max.fill"
        case .sleepDisplay: return "display"
        case .lockScreen: return "lock.fill"
        case .mediaPlayPause: return "playpause.fill"
        case .mediaNext: return "forward.fill"
        case .mediaPrevious: return "backward.fill"
        case .snapLeft: return "rectangle.lefthalf.filled"
        case .snapRight: return "rectangle.righthalf.filled"
        case .snapTop: return "rectangle.tophalf.filled"
        case .snapBottom: return "rectangle.bottomhalf.filled"
        case .maximizeWindow: return "arrow.up.left.and.arrow.down.right"
        case .centerWindow: return "rectangle.center.inset.filled"
        case .minimizeWindow: return "minus.rectangle"
        case .fullScreenWindow: return "arrow.up.left.and.arrow.down.right.rectangle"
        case .closeWindow: return "xmark.rectangle"
        case .missionControl: return "rectangle.stack.fill"
        case .appExpose: return "square.on.square"
        case .showDesktop: return "menubar.rectangle"
        case .nextSpace: return "arrow.right.square"
        case .previousSpace: return "arrow.left.square"
        case .screenshot: return "camera.fill"
        case .spotlight: return "magnifyingglass"
        case .middleClick: return "computermouse.fill"
        case .launchApp: return "arrow.up.forward.app.fill"
        }
    }

    /// Continuous actions repeat for as long as the swipe keeps going (volume, brightness).
    /// Discrete actions fire once per swipe so a single long swipe cannot skip ten tracks.
    var isContinuous: Bool {
        self == .volume || self == .brightness
    }

    /// The action performed when the same swipe runs the other way.
    /// This is what makes a single axis binding behave sensibly in both directions:
    /// binding "Next Track" to a horizontal swipe automatically gives you
    /// "Previous Track" on the reverse swipe. Actions with no natural opposite
    /// simply repeat themselves.
    var inverse: GestureAction {
        switch self {
        case .mediaNext: return .mediaPrevious
        case .mediaPrevious: return .mediaNext
        case .snapLeft: return .snapRight
        case .snapRight: return .snapLeft
        case .snapTop: return .snapBottom
        case .snapBottom: return .snapTop
        case .maximizeWindow: return .minimizeWindow
        case .minimizeWindow: return .maximizeWindow
        case .missionControl: return .showDesktop
        case .showDesktop: return .missionControl
        case .nextSpace: return .previousSpace
        case .previousSpace: return .nextSpace
        default: return self
        }
    }

    /// True when the reverse swipe does something different from the forward swipe.
    var hasDistinctInverse: Bool { inverse != self }
}
