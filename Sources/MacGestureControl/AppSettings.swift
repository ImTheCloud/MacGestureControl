// AppSettings.swift
import Foundation
import SwiftUI
import Combine

enum MediaAction {
    case playPause
    case next
    case previous
}

enum GestureAction: String, CaseIterable, Identifiable, Codable {
    case volume = "volume"
    case brightness = "brightness"
    case mediaPlayPause = "media_play_pause"
    case mediaNext = "media_next"
    case mediaPrevious = "media_previous"
    case toggleMute = "toggle_mute"
    case middleClick = "middle_click"
    case snapLeft = "snap_left"
    case snapRight = "snap_right"
    case maximizeWindow = "maximize_window"
    case centerWindow = "center_window"
    case minimizeWindow = "minimize_window"
    case missionControl = "mission_control"
    case showDesktop = "show_desktop"
    case lockScreen = "lock_screen"
    case sleepDisplay = "sleep_display"
    case screenshot = "screenshot"
    case launchApp = "launch_app"
    case none = "none"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .volume: return "System Volume"
        case .brightness: return "Screen Brightness"
        case .mediaPlayPause: return "Play / Pause Media (Spotify, Apple Music)"
        case .mediaNext: return "Next Track"
        case .mediaPrevious: return "Previous Track"
        case .toggleMute: return "Mute / Unmute Audio"
        case .middleClick: return "Middle Click (Open link / Close tab)"
        case .snapLeft: return "Snap Window Left Half"
        case .snapRight: return "Snap Window Right Half"
        case .maximizeWindow: return "Maximize Window"
        case .centerWindow: return "Center Window"
        case .minimizeWindow: return "Minimize Window"
        case .missionControl: return "Open Mission Control"
        case .showDesktop: return "Show Desktop"
        case .lockScreen: return "Lock Screen"
        case .sleepDisplay: return "Sleep Display"
        case .screenshot: return "Take Screenshot (Cmd+Shift+4)"
        case .launchApp: return "Launch Application"
        case .none: return "Disabled"
        }
    }

    var icon: String {
        switch self {
        case .volume: return "speaker.wave.3.fill"
        case .brightness: return "sun.max.fill"
        case .mediaPlayPause: return "playpause.fill"
        case .mediaNext: return "forward.fill"
        case .mediaPrevious: return "backward.fill"
        case .toggleMute: return "speaker.slash.fill"
        case .middleClick: return "computermouse.fill"
        case .snapLeft: return "rectangle.lefthalf.filled"
        case .snapRight: return "rectangle.righthalf.filled"
        case .maximizeWindow: return "arrow.up.left.and.arrow.down.right"
        case .centerWindow: return "rectangle.center.inset.filled"
        case .minimizeWindow: return "minus.rectangle"
        case .missionControl: return "rectangle.stack.fill"
        case .showDesktop: return "menubar.rectangle"
        case .lockScreen: return "lock.fill"
        case .sleepDisplay: return "display"
        case .screenshot: return "camera.fill"
        case .launchApp: return "arrow.up.forward.app.fill"
        case .none: return "slash.circle"
        }
    }

    var isContinuous: Bool {
        return self == .volume || self == .brightness
    }
}

class AppSettings: ObservableObject {
    static let shared = AppSettings()

    // MARK: - Global Switches
    @Published var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: "app_isEnabled_v4") }
    }
    @Published var hapticsEnabled: Bool {
        didSet { UserDefaults.standard.set(hapticsEnabled, forKey: "app_hapticsEnabled_v4") }
    }
    @Published var showHUD: Bool {
        didSet { UserDefaults.standard.set(showHUD, forKey: "app_showHUD_v4") }
    }
    @Published var menuBarIcon: String {
        didSet { UserDefaults.standard.set(menuBarIcon, forKey: "app_menuBarIcon_v4") }
    }
    @Published var sensitivity: Double {
        didSet { UserDefaults.standard.set(sensitivity, forKey: "app_sensitivity_v4") }
    }
    @Published var targetBundleId: String {
        didSet { UserDefaults.standard.set(targetBundleId, forKey: "app_targetBundleId_v4") }
    }

    // MARK: - 4-Finger Gestures (Defaults: Vertical = Volume, Tap = Play/Pause)
    @Published var fourFingerVerticalAction: GestureAction {
        didSet { UserDefaults.standard.set(fourFingerVerticalAction.rawValue, forKey: "fourFingerVerticalAction_v4") }
    }
    @Published var fourFingerHorizontalAction: GestureAction {
        didSet { UserDefaults.standard.set(fourFingerHorizontalAction.rawValue, forKey: "fourFingerHorizontalAction_v4") }
    }
    @Published var fourFingerTapAction: GestureAction {
        didSet { UserDefaults.standard.set(fourFingerTapAction.rawValue, forKey: "fourFingerTapAction_v4") }
    }
    @Published var fourFingerPinchInAction: GestureAction {
        didSet { UserDefaults.standard.set(fourFingerPinchInAction.rawValue, forKey: "fourFingerPinchInAction_v4") }
    }
    @Published var fourFingerPinchOutAction: GestureAction {
        didSet { UserDefaults.standard.set(fourFingerPinchOutAction.rawValue, forKey: "fourFingerPinchOutAction_v4") }
    }

    // MARK: - 3-Finger Gestures (Default: All Disabled)
    @Published var threeFingerVerticalAction: GestureAction {
        didSet { UserDefaults.standard.set(threeFingerVerticalAction.rawValue, forKey: "threeFingerVerticalAction_v4") }
    }
    @Published var threeFingerHorizontalAction: GestureAction {
        didSet { UserDefaults.standard.set(threeFingerHorizontalAction.rawValue, forKey: "threeFingerHorizontalAction_v4") }
    }
    @Published var threeFingerTapAction: GestureAction {
        didSet { UserDefaults.standard.set(threeFingerTapAction.rawValue, forKey: "threeFingerTapAction_v4") }
    }
    @Published var threeFingerPinchInAction: GestureAction {
        didSet { UserDefaults.standard.set(threeFingerPinchInAction.rawValue, forKey: "threeFingerPinchInAction_v4") }
    }
    @Published var threeFingerPinchOutAction: GestureAction {
        didSet { UserDefaults.standard.set(threeFingerPinchOutAction.rawValue, forKey: "threeFingerPinchOutAction_v4") }
    }

    // MARK: - 2-Finger Gestures (Default: All Disabled to preserve normal scrolling)
    @Published var twoFingerVerticalAction: GestureAction {
        didSet { UserDefaults.standard.set(twoFingerVerticalAction.rawValue, forKey: "twoFingerVerticalAction_v4") }
    }
    @Published var twoFingerHorizontalAction: GestureAction {
        didSet { UserDefaults.standard.set(twoFingerHorizontalAction.rawValue, forKey: "twoFingerHorizontalAction_v4") }
    }
    @Published var twoFingerTapAction: GestureAction {
        didSet { UserDefaults.standard.set(twoFingerTapAction.rawValue, forKey: "twoFingerTapAction_v4") }
    }

    // MARK: - Corner Taps (Default: All Disabled)
    @Published var cornerTopLeftAction: GestureAction {
        didSet { UserDefaults.standard.set(cornerTopLeftAction.rawValue, forKey: "cornerTopLeftAction_v4") }
    }
    @Published var cornerTopRightAction: GestureAction {
        didSet { UserDefaults.standard.set(cornerTopRightAction.rawValue, forKey: "cornerTopRightAction_v4") }
    }
    @Published var cornerBottomLeftAction: GestureAction {
        didSet { UserDefaults.standard.set(cornerBottomLeftAction.rawValue, forKey: "cornerBottomLeftAction_v4") }
    }
    @Published var cornerBottomRightAction: GestureAction {
        didSet { UserDefaults.standard.set(cornerBottomRightAction.rawValue, forKey: "cornerBottomRightAction_v4") }
    }

    private init() {
        self.isEnabled = UserDefaults.standard.object(forKey: "app_isEnabled_v4") as? Bool ?? true
        self.hapticsEnabled = UserDefaults.standard.object(forKey: "app_hapticsEnabled_v4") as? Bool ?? true
        self.showHUD = UserDefaults.standard.object(forKey: "app_showHUD_v4") as? Bool ?? true
        self.menuBarIcon = UserDefaults.standard.string(forKey: "app_menuBarIcon_v4") ?? "hand.draw.fill"
        self.sensitivity = UserDefaults.standard.object(forKey: "app_sensitivity_v4") as? Double ?? 0.05
        self.targetBundleId = UserDefaults.standard.string(forKey: "app_targetBundleId_v4") ?? "com.apple.Notes"

        // 4-Finger: Vertical = Volume, Tap = Play/Pause Media
        let fv = UserDefaults.standard.string(forKey: "fourFingerVerticalAction_v4") ?? GestureAction.volume.rawValue
        self.fourFingerVerticalAction = GestureAction(rawValue: fv) ?? .volume
        let fh = UserDefaults.standard.string(forKey: "fourFingerHorizontalAction_v4") ?? GestureAction.none.rawValue
        self.fourFingerHorizontalAction = GestureAction(rawValue: fh) ?? .none
        let ft = UserDefaults.standard.string(forKey: "fourFingerTapAction_v4") ?? GestureAction.mediaPlayPause.rawValue
        self.fourFingerTapAction = GestureAction(rawValue: ft) ?? .mediaPlayPause
        let fpi = UserDefaults.standard.string(forKey: "fourFingerPinchInAction_v4") ?? GestureAction.none.rawValue
        self.fourFingerPinchInAction = GestureAction(rawValue: fpi) ?? .none
        let fpo = UserDefaults.standard.string(forKey: "fourFingerPinchOutAction_v4") ?? GestureAction.none.rawValue
        self.fourFingerPinchOutAction = GestureAction(rawValue: fpo) ?? .none

        // 3-Finger: All disabled by default
        let tv = UserDefaults.standard.string(forKey: "threeFingerVerticalAction_v4") ?? GestureAction.none.rawValue
        self.threeFingerVerticalAction = GestureAction(rawValue: tv) ?? .none
        let th = UserDefaults.standard.string(forKey: "threeFingerHorizontalAction_v4") ?? GestureAction.none.rawValue
        self.threeFingerHorizontalAction = GestureAction(rawValue: th) ?? .none
        let tt = UserDefaults.standard.string(forKey: "threeFingerTapAction_v4") ?? GestureAction.none.rawValue
        self.threeFingerTapAction = GestureAction(rawValue: tt) ?? .none
        let tpi = UserDefaults.standard.string(forKey: "threeFingerPinchInAction_v4") ?? GestureAction.none.rawValue
        self.threeFingerPinchInAction = GestureAction(rawValue: tpi) ?? .none
        let tpo = UserDefaults.standard.string(forKey: "threeFingerPinchOutAction_v4") ?? GestureAction.none.rawValue
        self.threeFingerPinchOutAction = GestureAction(rawValue: tpo) ?? .none

        // 2-Finger: All disabled by default
        let twoV = UserDefaults.standard.string(forKey: "twoFingerVerticalAction_v4") ?? GestureAction.none.rawValue
        self.twoFingerVerticalAction = GestureAction(rawValue: twoV) ?? .none
        let twoH = UserDefaults.standard.string(forKey: "twoFingerHorizontalAction_v4") ?? GestureAction.none.rawValue
        self.twoFingerHorizontalAction = GestureAction(rawValue: twoH) ?? .none
        let twoT = UserDefaults.standard.string(forKey: "twoFingerTapAction_v4") ?? GestureAction.none.rawValue
        self.twoFingerTapAction = GestureAction(rawValue: twoT) ?? .none

        // Corner Taps: All disabled by default
        let ctl = UserDefaults.standard.string(forKey: "cornerTopLeftAction_v4") ?? GestureAction.none.rawValue
        self.cornerTopLeftAction = GestureAction(rawValue: ctl) ?? .none
        let ctr = UserDefaults.standard.string(forKey: "cornerTopRightAction_v4") ?? GestureAction.none.rawValue
        self.cornerTopRightAction = GestureAction(rawValue: ctr) ?? .none
        let cbl = UserDefaults.standard.string(forKey: "cornerBottomLeftAction_v4") ?? GestureAction.none.rawValue
        self.cornerBottomLeftAction = GestureAction(rawValue: cbl) ?? .none
        let cbr = UserDefaults.standard.string(forKey: "cornerBottomRightAction_v4") ?? GestureAction.none.rawValue
        self.cornerBottomRightAction = GestureAction(rawValue: cbr) ?? .none
    }

    func resetToDefaults() {
        fourFingerVerticalAction = .volume
        fourFingerHorizontalAction = .none
        fourFingerTapAction = .mediaPlayPause
        fourFingerPinchInAction = .none
        fourFingerPinchOutAction = .none

        threeFingerVerticalAction = .none
        threeFingerHorizontalAction = .none
        threeFingerTapAction = .none
        threeFingerPinchInAction = .none
        threeFingerPinchOutAction = .none

        twoFingerVerticalAction = .none
        twoFingerHorizontalAction = .none
        twoFingerTapAction = .none

        cornerTopLeftAction = .none
        cornerTopRightAction = .none
        cornerBottomLeftAction = .none
        cornerBottomRightAction = .none

        sensitivity = 0.05
        hapticsEnabled = true
        showHUD = true
        isEnabled = true
    }

    func applyPreset(_ preset: PresetType) {
        switch preset {
        case .essential:
            resetToDefaults()
        case .productivity:
            resetToDefaults()
            threeFingerTapAction = .middleClick
            threeFingerHorizontalAction = .snapRight
            threeFingerVerticalAction = .maximizeWindow
            cornerTopLeftAction = .showDesktop
            cornerTopRightAction = .missionControl
        case .mediaMaster:
            resetToDefaults()
            threeFingerHorizontalAction = .mediaNext
            threeFingerVerticalAction = .toggleMute
            threeFingerTapAction = .mediaPlayPause
        }
    }
}

enum PresetType: String, CaseIterable, Identifiable {
    case essential = "Essential (Default)"
    case productivity = "Productivity & CAD"
    case mediaMaster = "Media Master"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .essential: return "sparkles"
        case .productivity: return "rectangle.split.2x1.fill"
        case .mediaMaster: return "music.note"
        }
    }
}

