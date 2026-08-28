// GestureSettings.swift
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
    case mouseSpeed = "mouse_speed"
    case launchApp = "launch_app"
    case none = "none"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .volume: return "Volume Système"
        case .brightness: return "Luminosité Écran"
        case .mediaPlayPause: return "Lecture / Pause"
        case .mediaNext: return "Piste Suivante"
        case .mediaPrevious: return "Piste Précédente"
        case .toggleMute: return "Couper / Rétablir le Son"
        case .mouseSpeed: return "Vitesse du Curseur"
        case .launchApp: return "Lancer une Application"
        case .none: return "Aucune Action"
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
        case .mouseSpeed: return "cursorarrow.motionlines"
        case .launchApp: return "arrow.up.forward.app.fill"
        case .none: return "slash.circle"
        }
    }
}

class GestureSettings: ObservableObject {
    static let shared = GestureSettings()

    @Published var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: "gesture_isEnabled") }
    }

    @Published var twoFingerVerticalAction: GestureAction {
        didSet { UserDefaults.standard.set(twoFingerVerticalAction.rawValue, forKey: "twoFingerVerticalAction") }
    }

    @Published var twoFingerHorizontalAction: GestureAction {
        didSet { UserDefaults.standard.set(twoFingerHorizontalAction.rawValue, forKey: "twoFingerHorizontalAction") }
    }

    @Published var threeFingerHorizontalAction: GestureAction {
        didSet { UserDefaults.standard.set(threeFingerHorizontalAction.rawValue, forKey: "threeFingerHorizontalAction") }
    }

    @Published var threeFingerVerticalAction: GestureAction {
        didSet { UserDefaults.standard.set(threeFingerVerticalAction.rawValue, forKey: "threeFingerVerticalAction") }
    }

    @Published var fourFingerVerticalAction: GestureAction {
        didSet { UserDefaults.standard.set(fourFingerVerticalAction.rawValue, forKey: "fourFingerVerticalAction") }
    }

    @Published var fourFingerTapAction: GestureAction {
        didSet { UserDefaults.standard.set(fourFingerTapAction.rawValue, forKey: "fourFingerTapAction") }
    }

    @Published var sensitivity: Double {
        didSet { UserDefaults.standard.set(sensitivity, forKey: "gesture_sensitivity") }
    }

    @Published var targetBundleId: String {
        didSet { UserDefaults.standard.set(targetBundleId, forKey: "gesture_targetBundleId") }
    }

    private init() {
        self.isEnabled = UserDefaults.standard.object(forKey: "gesture_isEnabled") as? Bool ?? true
        
        let twoVert = UserDefaults.standard.string(forKey: "twoFingerVerticalAction") ?? GestureAction.volume.rawValue
        self.twoFingerVerticalAction = GestureAction(rawValue: twoVert) ?? .volume

        let twoHoriz = UserDefaults.standard.string(forKey: "twoFingerHorizontalAction") ?? GestureAction.none.rawValue
        self.twoFingerHorizontalAction = GestureAction(rawValue: twoHoriz) ?? .none

        let threeHoriz = UserDefaults.standard.string(forKey: "threeFingerHorizontalAction") ?? GestureAction.mediaNext.rawValue
        self.threeFingerHorizontalAction = GestureAction(rawValue: threeHoriz) ?? .mediaNext

        let threeVert = UserDefaults.standard.string(forKey: "threeFingerVerticalAction") ?? GestureAction.toggleMute.rawValue
        self.threeFingerVerticalAction = GestureAction(rawValue: threeVert) ?? .toggleMute

        let fourVert = UserDefaults.standard.string(forKey: "fourFingerVerticalAction") ?? GestureAction.brightness.rawValue
        self.fourFingerVerticalAction = GestureAction(rawValue: fourVert) ?? .brightness

        let fourTap = UserDefaults.standard.string(forKey: "fourFingerTapAction") ?? GestureAction.launchApp.rawValue
        self.fourFingerTapAction = GestureAction(rawValue: fourTap) ?? .launchApp

        self.sensitivity = UserDefaults.standard.object(forKey: "gesture_sensitivity") as? Double ?? 0.05
        self.targetBundleId = UserDefaults.standard.string(forKey: "gesture_targetBundleId") ?? "com.apple.Notes"
    }
}
