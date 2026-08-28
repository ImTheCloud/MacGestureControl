// SystemController.swift
import Cocoa
import CoreAudio
import AudioToolbox

class SystemController {
    static let shared = SystemController()

    // MARK: - Action Router
    func execute(_ action: GestureAction, up: Bool = true) {
        guard AppSettings.shared.isEnabled else { return }

        switch action {
        case .volume:
            adjustVolume(up: up)
        case .brightness:
            adjustBrightness(up: up)
        case .mediaPlayPause:
            controlMedia(action: .playPause)
        case .mediaNext:
            controlMedia(action: .next)
        case .mediaPrevious:
            controlMedia(action: .previous)
        case .toggleMute:
            toggleMute()
        case .middleClick:
            performMiddleClick()
        case .snapLeft, .snapRight, .maximizeWindow, .centerWindow, .minimizeWindow:
            WindowManager.shared.snapActiveWindow(to: action)
        case .missionControl:
            triggerMissionControl()
        case .showDesktop:
            triggerShowDesktop()
        case .lockScreen:
            lockScreen()
        case .sleepDisplay:
            sleepDisplay()
        case .screenshot:
            takeScreenshot()
        case .launchApp:
            launchApp(bundleId: AppSettings.shared.targetBundleId)
        case .none:
            break
        }
    }

    // MARK: - Volume Control
    func adjustVolume(up: Bool) {
        var deviceID = AudioObjectID(0)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID)
        guard status == noErr else { return }

        var volume: Float32 = 0
        var volSize = UInt32(MemoryLayout<Float32>.size)
        var volAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(deviceID, &volAddress, 0, nil, &volSize, &volume)

        let step = Float32(AppSettings.shared.sensitivity)
        var newVolume = max(0, min(1, volume + (up ? step : -step)))
        AudioObjectSetPropertyData(deviceID, &volAddress, 0, nil, volSize, &newVolume)

        HapticManager.shared.trigger()
        HUDManager.shared.show(
            icon: newVolume == 0 ? "speaker.slash.fill" : (newVolume > 0.5 ? "speaker.wave.3.fill" : "speaker.wave.1.fill"),
            title: "Volume",
            progress: newVolume
        )
    }

    // MARK: - Brightness Control
    func adjustBrightness(up: Bool) {
        let script = up
            ? "tell application \"System Events\" to key code 144"
            : "tell application \"System Events\" to key code 145"
        runAppleScript(script)
        HapticManager.shared.trigger()
        HUDManager.shared.show(
            icon: up ? "sun.max.fill" : "sun.min.fill",
            title: up ? "Brightness Up" : "Brightness Down"
        )
    }

    // MARK: - Mute Toggle
    func toggleMute() {
        let script = """
        set currentMute to output muted of (get volume settings)
        set volume output muted not currentMute
        return not currentMute
        """
        runAppleScriptWithResult(script) { isMuted in
            HapticManager.shared.triggerClick()
            let muted = isMuted.trimmingCharacters(in: .whitespacesAndNewlines) == "true"
            HUDManager.shared.show(
                icon: muted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                title: muted ? "Muted" : "Unmuted",
                subtitle: muted ? "Audio output muted" : "Audio output active"
            )
        }
    }

    // MARK: - Middle Click Simulation
    func performMiddleClick() {
        let mouseLocation = NSEvent.mouseLocation
        guard let screen = NSScreen.main else { return }
        let location = CGPoint(x: mouseLocation.x, y: screen.frame.height - mouseLocation.y)

        let mouseDown = CGEvent(mouseEventSource: nil, mouseType: .otherMouseDown, mouseCursorPosition: location, mouseButton: .center)
        let mouseUp = CGEvent(mouseEventSource: nil, mouseType: .otherMouseUp, mouseCursorPosition: location, mouseButton: .center)

        mouseDown?.post(tap: .cghidEventTap)
        mouseUp?.post(tap: .cghidEventTap)

        HapticManager.shared.triggerClick()
        HUDManager.shared.show(icon: "computermouse.fill", title: "Middle Click", subtitle: "Simulated center button")
    }

    // MARK: - Media Playback
    func controlMedia(action: MediaAction) {
        let script: String
        let title: String
        let icon: String

        switch action {
        case .playPause:
            title = "Play / Pause"
            icon = "playpause.fill"
            script = """
            if application "Spotify" is running then
                tell application "Spotify" to playpause
            else if application "Music" is running then
                tell application "Music" to playpause
            else
                tell application "System Events" to key code 16 using {option down}
            end if
            """
        case .next:
            title = "Next Track"
            icon = "forward.fill"
            script = """
            if application "Spotify" is running then
                tell application "Spotify" to next track
            else if application "Music" is running then
                tell application "Music" to next track
            end if
            """
        case .previous:
            title = "Previous Track"
            icon = "backward.fill"
            script = """
            if application "Spotify" is running then
                tell application "Spotify" to previous track
            else if application "Music" is running then
                tell application "Music" to previous track
            end if
            """
        }

        runAppleScript(script)
        HapticManager.shared.triggerClick()
        HUDManager.shared.show(icon: icon, title: title)
    }

    // MARK: - System Shortcuts
    func triggerMissionControl() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.exposelauncher") ??
                     NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.launchpad.launcher") {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
        } else {
            let script = "tell application \"Mission Control\" to launch"
            runAppleScript(script)
        }
        HUDManager.shared.show(icon: "rectangle.stack.fill", title: "Mission Control")
    }

    func triggerShowDesktop() {
        let script = "tell application \"System Events\" to key code 103" // F11
        runAppleScript(script)
        HUDManager.shared.show(icon: "menubar.rectangle", title: "Show Desktop")
    }

    func lockScreen() {
        let script = "tell application \"System Events\" to keystroke \"q\" using {command down, control down}"
        runAppleScript(script)
        HUDManager.shared.show(icon: "lock.fill", title: "Lock Screen")
    }

    func sleepDisplay() {
        let script = "do shell script \"pmset displaysleepnow\""
        runAppleScript(script)
        HUDManager.shared.show(icon: "display", title: "Sleep Display")
    }

    func takeScreenshot() {
        let script = "tell application \"System Events\" to keystroke \"4\" using {command down, shift down}"
        runAppleScript(script)
        HUDManager.shared.show(icon: "camera.fill", title: "Screenshot Tool")
    }

    func launchApp(bundleId: String) {
        guard !bundleId.isEmpty else { return }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            let config = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.openApplication(at: url, configuration: config) { app, error in
                DispatchQueue.main.async {
                    if let app = app {
                        HUDManager.shared.show(icon: "arrow.up.forward.app.fill", title: app.localizedName ?? "App Launched")
                        HapticManager.shared.triggerClick()
                    }
                }
            }
        } else {
            HUDManager.shared.show(icon: "exclamationmark.triangle.fill", title: "App Not Found", subtitle: bundleId)
        }
    }

    // MARK: - Helper AppleScript Runner
    private func runAppleScript(_ script: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            if let appleScript = NSAppleScript(source: script) {
                var error: NSDictionary?
                appleScript.executeAndReturnError(&error)
            }
        }
    }

    private func runAppleScriptWithResult(_ script: String, completion: @escaping (String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            if let appleScript = NSAppleScript(source: script) {
                var error: NSDictionary?
                let desc = appleScript.executeAndReturnError(&error)
                let result = desc.stringValue ?? ""
                DispatchQueue.main.async {
                    completion(result)
                }
            }
        }
    }
}
