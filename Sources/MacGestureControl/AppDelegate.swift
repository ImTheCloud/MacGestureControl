// AppDelegate.swift
import Cocoa
import SwiftUI
import CoreAudio
import AudioToolbox

class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var shared: AppDelegate?

    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var eventTap: CFMachPort?
    var runLoopSource: CFRunLoopSource?

    let settings = GestureSettings.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self

        // 1. Initialiser le Popover SwiftUI
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 360, height: 380)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: GestureSettingsView())
        self.popover = popover

        // 2. Configurer l'icône de la barre des menus
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            if let img = NSImage(systemSymbolName: "hand.draw.fill", accessibilityDescription: "MacGesture Control")?.withSymbolConfiguration(config) {
                button.image = img
            } else {
                button.image = NSImage(systemSymbolName: "hand.tap.fill", accessibilityDescription: "MacGesture Control")
            }
            button.target = self
            button.action = #selector(togglePopover(_:))
        }

        // 3. Demander les permissions & installer l'event tap
        requestAccessibilityPermission()
        installEventTap()
    }

    // MARK: - Popover Handling
    @objc func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    // MARK: - Accessibility Permission
    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Event Tap
    func installEventTap() {
        let mask = CGEventMask(1 << CGEventType.scrollWheel.rawValue)
        let callback: CGEventTapCallBack = { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
            guard let delegatePtr = refcon else { return Unmanaged.passUnretained(event) }
            let delegate = Unmanaged<AppDelegate>.fromOpaque(delegatePtr).takeUnretainedValue()

            guard delegate.settings.isEnabled else {
                return Unmanaged.passUnretained(event)
            }

            if type == .scrollWheel {
                let deltaY = event.getDoubleValueField(.scrollWheelEventDeltaAxis1)
                let deltaX = event.getDoubleValueField(.scrollWheelEventDeltaAxis2)

                // Détection Défilement Vertical (2 doigts)
                if abs(deltaY) > 0.4 {
                    delegate.executeAction(delegate.settings.twoFingerVerticalAction, up: deltaY > 0)
                }

                // Détection Défilement Horizontal (2 doigts)
                if abs(deltaX) > 0.4 && delegate.settings.twoFingerHorizontalAction != .none {
                    delegate.executeAction(delegate.settings.twoFingerHorizontalAction, up: deltaX > 0)
                }
            }

            return Unmanaged.passUnretained(event)
        }

        let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        if let tap = CGEvent.tapCreate(tap: .cghidEventTap,
                                       place: .headInsertEventTap,
                                       options: .defaultTap,
                                       eventsOfInterest: mask,
                                       callback: callback,
                                       userInfo: refcon) {
            eventTap = tap
            runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
        } else {
            NSLog("Failed to create event tap – ensure Accessibility permission is granted.")
        }
    }

    // MARK: - Action Dispatcher
    func executeAction(_ action: GestureAction, up: Bool) {
        switch action {
        case .volume:
            adjustSystemVolume(up: up)
        case .brightness:
            adjustBrightness(up: up)
        case .mediaPlayPause:
            controlMedia(action: .playPause)
        case .mediaNext:
            controlMedia(action: up ? .next : .previous)
        case .mediaPrevious:
            controlMedia(action: .previous)
        case .toggleMute:
            toggleMute()
        case .mouseSpeed:
            setMouseTrackingSpeed(increase: up)
        case .launchApp:
            launchApplication(bundleID: settings.targetBundleId)
        case .none:
            break
        }
    }

    // MARK: - Volume Control
    func adjustSystemVolume(up: Bool) {
        var deviceID = AudioObjectID(0)
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                                mScope: kAudioObjectPropertyScopeGlobal,
                                                mElement: kAudioObjectPropertyElementMain)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID)
        guard status == noErr else { return }

        var volume: Float32 = 0
        var volSize = UInt32(MemoryLayout<Float32>.size)
        var volAddress = AudioObjectPropertyAddress(mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
                                                    mScope: kAudioDevicePropertyScopeOutput,
                                                    mElement: kAudioObjectPropertyElementMain)
        AudioObjectGetPropertyData(deviceID, &volAddress, 0, nil, &volSize, &volume)

        let step = Float32(settings.sensitivity)
        var newVolume = max(0, min(1, volume + (up ? step : -step)))
        AudioObjectSetPropertyData(deviceID, &volAddress, 0, nil, volSize, &newVolume)
    }

    // MARK: - Brightness Control
    func adjustBrightness(up: Bool) {
        let script = up
            ? "tell application \"System Events\" to key code 144"
            : "tell application \"System Events\" to key code 145"
        runAppleScript(script)
    }

    // MARK: - Mute Toggle
    func toggleMute() {
        let script = "set volume output muted not (output muted of (get volume settings))"
        runAppleScript(script)
    }

    // MARK: - Media Control
    func controlMedia(action: MediaAction) {
        let script: String
        switch action {
        case .playPause:
            script = """
            if application "Music" is running then
                tell application "Music" to playpause
            else if application "Spotify" is running then
                tell application "Spotify" to playpause
            end if
            """
        case .next:
            script = """
            if application "Music" is running then
                tell application "Music" to next track
            else if application "Spotify" is running then
                tell application "Spotify" to next track
            end if
            """
        case .previous:
            script = """
            if application "Music" is running then
                tell application "Music" to previous track
            else if application "Spotify" is running then
                tell application "Spotify" to previous track
            end if
            """
        }
        runAppleScript(script)
    }

    // MARK: - Mouse Speed Placeholder
    func setMouseTrackingSpeed(increase: Bool) {
        // TODO: implement mouse tracking speed adjustment
    }

    // MARK: - Launch Application
    func launchApplication(bundleID: String) {
        guard !bundleID.isEmpty else { return }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let config = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.openApplication(at: url, configuration: config, completionHandler: nil)
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
}
