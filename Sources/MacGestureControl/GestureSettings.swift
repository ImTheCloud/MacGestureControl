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
        case .none: return "Désactivé"
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
        didSet { UserDefaults.standard.set(isEnabled, forKey: "gesture_isEnabled_v2") }
    }

    @Published var twoFingerVerticalAction: GestureAction {
        didSet { UserDefaults.standard.set(twoFingerVerticalAction.rawValue, forKey: "twoFingerVerticalAction_v2") }
    }

    @Published var twoFingerHorizontalAction: GestureAction {
        didSet { UserDefaults.standard.set(twoFingerHorizontalAction.rawValue, forKey: "twoFingerHorizontalAction_v2") }
    }

    @Published var threeFingerHorizontalAction: GestureAction {
        didSet { UserDefaults.standard.set(threeFingerHorizontalAction.rawValue, forKey: "threeFingerHorizontalAction_v2") }
    }

    @Published var threeFingerVerticalAction: GestureAction {
        didSet { UserDefaults.standard.set(threeFingerVerticalAction.rawValue, forKey: "threeFingerVerticalAction_v2") }
    }

    @Published var fourFingerVerticalAction: GestureAction {
        didSet { UserDefaults.standard.set(fourFingerVerticalAction.rawValue, forKey: "fourFingerVerticalAction_v2") }
    }

    @Published var fourFingerTapAction: GestureAction {
        didSet { UserDefaults.standard.set(fourFingerTapAction.rawValue, forKey: "fourFingerTapAction_v2") }
    }

    @Published var sensitivity: Double {
        didSet { UserDefaults.standard.set(sensitivity, forKey: "gesture_sensitivity_v2") }
    }

    @Published var targetBundleId: String {
        didSet { UserDefaults.standard.set(targetBundleId, forKey: "gesture_targetBundleId_v2") }
    }

    private init() {
        self.isEnabled = UserDefaults.standard.object(forKey: "gesture_isEnabled_v2") as? Bool ?? true
        
        // Tout désactivé par défaut (.none), sauf 4 doigts vertical -> .volume
        let twoVert = UserDefaults.standard.string(forKey: "twoFingerVerticalAction_v2") ?? GestureAction.none.rawValue
        self.twoFingerVerticalAction = GestureAction(rawValue: twoVert) ?? .none

        let twoHoriz = UserDefaults.standard.string(forKey: "twoFingerHorizontalAction_v2") ?? GestureAction.none.rawValue
        self.twoFingerHorizontalAction = GestureAction(rawValue: twoHoriz) ?? .none

        let threeHoriz = UserDefaults.standard.string(forKey: "threeFingerHorizontalAction_v2") ?? GestureAction.none.rawValue
        self.threeFingerHorizontalAction = GestureAction(rawValue: threeHoriz) ?? .none

        let threeVert = UserDefaults.standard.string(forKey: "threeFingerVerticalAction_v2") ?? GestureAction.none.rawValue
        self.threeFingerVerticalAction = GestureAction(rawValue: threeVert) ?? .none

        // SEUL GESTE ACTIVÉ PAR DÉFAUT : 4 doigts vertical -> Volume
        let fourVert = UserDefaults.standard.string(forKey: "fourFingerVerticalAction_v2") ?? GestureAction.volume.rawValue
        self.fourFingerVerticalAction = GestureAction(rawValue: fourVert) ?? .volume

        let fourTap = UserDefaults.standard.string(forKey: "fourFingerTapAction_v2") ?? GestureAction.none.rawValue
        self.fourFingerTapAction = GestureAction(rawValue: fourTap) ?? .none

        self.sensitivity = UserDefaults.standard.object(forKey: "gesture_sensitivity_v2") as? Double ?? 0.05
        self.targetBundleId = UserDefaults.standard.string(forKey: "gesture_targetBundleId_v2") ?? "com.apple.Notes"
    }

    func resetToDefaults() {
        twoFingerVerticalAction = .none
        twoFingerHorizontalAction = .none
        threeFingerHorizontalAction = .none
        threeFingerVerticalAction = .none
        fourFingerVerticalAction = .volume
        fourFingerTapAction = .none
    }
}
