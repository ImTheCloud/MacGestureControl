// SystemController.swift
// Performs the actual system side effect behind every gesture.
import Cocoa
import CoreAudio
import AudioToolbox

/// Virtual key codes used by the keyboard-driven actions.
private enum KeyCode {
    static let space: CGKeyCode = 49
    static let leftArrow: CGKeyCode = 123
    static let rightArrow: CGKeyCode = 124
    static let downArrow: CGKeyCode = 125
    static let brightnessDown: CGKeyCode = 145
    static let brightnessUp: CGKeyCode = 144
    static let command: CGKeyCode = 55
    static let shift: CGKeyCode = 56
    static let option: CGKeyCode = 58
    static let control: CGKeyCode = 59
}

/// Subtypes of the system-defined event used for the hardware media keys.
private enum MediaKey: Int32 {
    case mute = 7
    case playPause = 16
    case next = 17
    case previous = 18
}

final class SystemController {
    static let shared = SystemController()

    /// macOS itself moves the volume in sixteenths; matching that keeps our HUD
    /// in step with the system one.
    private let volumeStep: Float32 = 1.0 / 16.0
    private let brightnessStep: Float = 1.0 / 16.0
    /// Long enough for a click made by the same gesture to be delivered and done.
    private let screenshotClickSettleDelay: TimeInterval = 0.35

    private init() {}

    // MARK: - Action router

    /// - Parameter up: direction for continuous actions (volume, brightness).
    func execute(_ action: GestureAction, up: Bool = true) {
        guard AppSettings.shared.isEnabled else { return }

        // Everything below touches AppKit, so normalise onto the main thread once
        // instead of relying on each call site to do it.
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.execute(action, up: up) }
            return
        }

        switch action {
        case .none:
            break
        case .volume:
            adjustVolume(up: up)
        case .toggleMute:
            toggleMute()
        case .toggleMicrophone:
            toggleMicrophone()
        case .brightness:
            adjustBrightness(up: up)
        case .lockScreen:
            lockScreen()
        case .mediaPlayPause:
            postMediaKey(.playPause, icon: "playpause.fill", title: "Play / Pause")
        case .mediaNext:
            postMediaKey(.next, icon: "forward.fill", title: "Next Track")
        case .mediaPrevious:
            postMediaKey(.previous, icon: "backward.fill", title: "Previous Track")
        case .snapLeft, .snapRight, .snapTop, .snapBottom, .maximizeWindow,
             .centerWindow, .minimizeWindow, .fullScreenWindow:
            WindowManager.shared.perform(action)
        case .closeWindow:
            // The close button first; the keystroke only if there is none.
            if WindowManager.shared.closeFocusedWindow() {
                HapticManager.shared.triggerClick()
            } else {
                postCharacter("w", flags: .maskCommand)
                feedback(icon: "xmark.rectangle", title: "Close Window")
            }
        case .missionControl:
            openSystemApp(bundleId: "com.apple.exposelauncher", icon: "rectangle.stack.fill", title: "Mission Control")
        case .appExpose:
            postKey(KeyCode.downArrow, flags: .maskControl)
            feedback(icon: "square.on.square", title: "App Exposé")
        case .nextSpace:
            postKey(KeyCode.rightArrow, flags: .maskControl)
            feedback(icon: "arrow.right.square", title: "Next Desktop")
        case .previousSpace:
            postKey(KeyCode.leftArrow, flags: .maskControl)
            feedback(icon: "arrow.left.square", title: "Previous Desktop")
        case .screenshot:
            takeScreenshot()
        case .spotlight:
            postKey(KeyCode.space, flags: .maskCommand)
            feedback(icon: "magnifyingglass", title: "Spotlight")
        case .middleClick:
            performMiddleClick()
        case .launchApp:
            launchApp(bundleId: AppSettings.shared.launchTargetBundleId)
        }
    }

    // MARK: - Audio

    private func adjustVolume(up: Bool) {
        guard let device = defaultOutputDevice(), let current = outputVolume(of: device) else { return }

        let target = max(0, min(1, current + (up ? volumeStep : -volumeStep)))
        setOutputVolume(target, on: device)

        // Raising the volume on a muted output should be audible.
        if up, target > 0, isMuted(device) == true {
            setMuted(false, on: device)
        }
        let muted = isMuted(device) == true

        HapticManager.shared.trigger()
        HUDManager.shared.show(
            icon: volumeIcon(for: target, muted: muted),
            title: "Volume",
            progress: muted ? 0 : target
        )
    }

    private func toggleMute() {
        guard let device = defaultOutputDevice(),
              let muted = isMuted(device),
              setMuted(!muted, on: device) else {
            // No usable mute control: let the system handle it with its own key.
            postMediaKey(.mute, icon: "speaker.slash.fill", title: "Mute")
            return
        }

        HapticManager.shared.triggerClick()
        HUDManager.shared.show(
            icon: !muted ? "speaker.slash.fill" : "speaker.wave.2.fill",
            title: !muted ? "Muted" : "Unmuted",
            subtitle: !muted ? "Audio output muted" : "Audio output active"
        )
    }

    /// Every conferencing app has its own mute shortcut; muting the input
    /// device itself works the same way in all of them.
    private func toggleMicrophone() {
        let scope = kAudioDevicePropertyScopeInput
        guard let device = defaultInputDevice(),
              let muted = isMuted(device, scope: scope),
              setMuted(!muted, on: device, scope: scope) else {
            HUDManager.shared.show(
                icon: "mic.slash.fill",
                title: "Microphone",
                subtitle: "This input has no mute control"
            )
            return
        }

        HapticManager.shared.triggerClick()
        HUDManager.shared.show(
            icon: !muted ? "mic.slash.fill" : "mic.fill",
            title: !muted ? "Microphone Muted" : "Microphone On"
        )
    }

    private func volumeIcon(for level: Float32, muted: Bool) -> String {
        if muted || level == 0 { return "speaker.slash.fill" }
        if level > 0.5 { return "speaker.wave.3.fill" }
        if level > 0.15 { return "speaker.wave.2.fill" }
        return "speaker.wave.1.fill"
    }

    private func defaultOutputDevice() -> AudioObjectID? {
        defaultDevice(selector: kAudioHardwarePropertyDefaultOutputDevice)
    }

    private func defaultInputDevice() -> AudioObjectID? {
        defaultDevice(selector: kAudioHardwarePropertyDefaultInputDevice)
    }

    private func defaultDevice(selector: AudioObjectPropertySelector) -> AudioObjectID? {
        var deviceID = AudioObjectID(0)
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID
        )
        guard status == noErr, deviceID != kAudioObjectUnknown else { return nil }
        return deviceID
    }

    private var volumeAddress: AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    private func muteAddress(element: AudioObjectPropertyElement, scope: AudioObjectPropertyScope) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: scope,
            mElement: element
        )
    }

    /// Where the mute control actually lives on this device: the main element
    /// when it has one, otherwise its individual channels. Plenty of USB and
    /// HDMI outputs only expose per-channel mute, and looking at the main
    /// element alone made Mute / Unmute silently do nothing on them.
    private func muteElements(of device: AudioObjectID, scope: AudioObjectPropertyScope) -> [AudioObjectPropertyElement] {
        var main = muteAddress(element: kAudioObjectPropertyElementMain, scope: scope)
        if AudioObjectHasProperty(device, &main) { return [kAudioObjectPropertyElementMain] }

        return stereoChannels(of: device, scope: scope).filter { element in
            var address = muteAddress(element: element, scope: scope)
            return AudioObjectHasProperty(device, &address)
        }
    }

    private func stereoChannels(of device: AudioObjectID, scope: AudioObjectPropertyScope) -> [AudioObjectPropertyElement] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyPreferredChannelsForStereo,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        var channels: (UInt32, UInt32) = (1, 2)
        var size = UInt32(MemoryLayout<(UInt32, UInt32)>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &channels) == noErr else {
            return [1, 2]
        }
        return [channels.0, channels.1]
    }

    private func outputVolume(of device: AudioObjectID) -> Float32? {
        var address = volumeAddress
        guard AudioObjectHasProperty(device, &address) else { return nil }
        var volume: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        let status = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &volume)
        guard status == noErr else { return nil }
        return volume
    }

    private func setOutputVolume(_ volume: Float32, on device: AudioObjectID) {
        var address = volumeAddress
        var settable: DarwinBoolean = false
        guard AudioObjectIsPropertySettable(device, &address, &settable) == noErr, settable.boolValue else { return }
        var value = volume
        AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &value)
    }

    /// `nil` when the device exposes no mute control at all.
    private func isMuted(_ device: AudioObjectID, scope: AudioObjectPropertyScope = kAudioDevicePropertyScopeOutput) -> Bool? {
        let elements = muteElements(of: device, scope: scope)
        guard !elements.isEmpty else { return nil }

        // Muted only when every element carrying the control is muted.
        return elements.allSatisfy { element in
            var address = muteAddress(element: element, scope: scope)
            var muted: UInt32 = 0
            var size = UInt32(MemoryLayout<UInt32>.size)
            guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &muted) == noErr else { return false }
            return muted != 0
        }
    }

    @discardableResult
    private func setMuted(_ muted: Bool, on device: AudioObjectID, scope: AudioObjectPropertyScope = kAudioDevicePropertyScopeOutput) -> Bool {
        var changed = false
        for element in muteElements(of: device, scope: scope) {
            var address = muteAddress(element: element, scope: scope)
            var settable: DarwinBoolean = false
            guard AudioObjectIsPropertySettable(device, &address, &settable) == noErr, settable.boolValue else { continue }
            var value: UInt32 = muted ? 1 : 0
            if AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value) == noErr {
                changed = true
            }
        }
        return changed
    }

    // MARK: - Brightness

    private func adjustBrightness(up: Bool) {
        HapticManager.shared.trigger()

        if let current = BrightnessService.shared.brightness() {
            let target = max(0, min(1, current + (up ? brightnessStep : -brightnessStep)))
            if BrightnessService.shared.setBrightness(target) {
                HUDManager.shared.show(
                    icon: target > 0.5 ? "sun.max.fill" : "sun.min.fill",
                    title: "Brightness",
                    progress: target
                )
                return
            }
        }

        // External displays and Macs without a controllable panel fall back to
        // the hardware keys, which macOS handles with its own overlay.
        postKey(up ? KeyCode.brightnessUp : KeyCode.brightnessDown)
        HUDManager.shared.show(
            icon: up ? "sun.max.fill" : "sun.min.fill",
            title: up ? "Brightness Up" : "Brightness Down"
        )
    }

    // MARK: - Media

    private func postMediaKey(_ key: MediaKey, icon: String, title: String) {
        for isDown in [true, false] {
            let flags = NSEvent.ModifierFlags(rawValue: isDown ? 0xA00 : 0xB00)
            let data1 = Int((key.rawValue << 16) | ((isDown ? 0xA : 0xB) << 8))
            guard let event = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: flags,
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: data1,
                data2: -1
            ) else { continue }
            event.cgEvent?.post(tap: .cghidEventTap)
        }
        feedback(icon: icon, title: title)
    }

    // MARK: - Display & session

    private func lockScreen() {
        HapticManager.shared.triggerClick()
        HUDManager.shared.show(icon: "lock.fill", title: "Lock Screen")

        // macOS ignores a synthesised Control-Command-Q, so ask the login
        // framework directly and keep the keystroke only as a fallback.
        if LoginServices.shared.lockScreen() { return }
        postCharacter("q", flags: [.maskCommand, .maskControl])
    }

    private func takeScreenshot() {
        HapticManager.shared.triggerClick()
        HUDManager.shared.show(icon: "camera.fill", title: "Screenshot", subtitle: "Select an area — copied to clipboard")

        // A gesture can carry a click of its own: macOS reads a two-finger tap
        // as a secondary click. That click lands in screencapture's crosshair
        // as an empty selection and cancels it, so let it finish first.
        DispatchQueue.main.asyncAfter(deadline: .now() + screenshotClickSettleDelay) {
            // Interactive area selection, straight to the clipboard.
            self.runTool("/usr/sbin/screencapture", arguments: ["-i", "-c"])
        }
    }

    // MARK: - Pointer

    private func performMiddleClick() {
        let mouseLocation = NSEvent.mouseLocation
        // Cocoa's origin is the bottom-left of the primary screen, Quartz's is
        // the top-left, so flip against the primary screen even on multi-display setups.
        guard let primary = NSScreen.screens.first else { return }
        let point = CGPoint(x: mouseLocation.x, y: primary.frame.maxY - mouseLocation.y)

        CGEvent(mouseEventSource: nil, mouseType: .otherMouseDown, mouseCursorPosition: point, mouseButton: .center)?
            .post(tap: .cghidEventTap)
        CGEvent(mouseEventSource: nil, mouseType: .otherMouseUp, mouseCursorPosition: point, mouseButton: .center)?
            .post(tap: .cghidEventTap)

        feedback(icon: "computermouse.fill", title: "Middle Click")
    }

    // MARK: - Apps

    private func openSystemApp(bundleId: String, icon: String, title: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            HUDManager.shared.show(icon: "exclamationmark.triangle.fill", title: "Unavailable", subtitle: title)
            return
        }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        feedback(icon: icon, title: title)
    }

    private func launchApp(bundleId: String) {
        guard !bundleId.isEmpty,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            HUDManager.shared.show(
                icon: "exclamationmark.triangle.fill",
                title: "App Not Found",
                subtitle: bundleId.isEmpty ? "Choose an app in Preferences" : bundleId
            )
            return
        }

        let name = FileManager.default.displayName(atPath: url.path)
            .replacingOccurrences(of: ".app", with: "")
        feedback(icon: "arrow.up.forward.app.fill", title: name)
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    // MARK: - Primitives

    /// Synthesises a key press. Requires Accessibility permission, which the app
    /// already needs — unlike AppleScript, it never triggers an Automation prompt.
    ///
    /// The modifiers are pressed and released as real key events rather than
    /// only set as flags on the keystroke. Applications accept the flags alone,
    /// but the system-wide shortcuts — Spotlight, Mission Control, switching
    /// desktops — ignore them.
    private func postKey(_ key: CGKeyCode, flags: CGEventFlags = []) {
        let source = CGEventSource(stateID: .hidSystemState)

        let modifiers: [(CGKeyCode, CGEventFlags)] = [
            (KeyCode.control, .maskControl),
            (KeyCode.option, .maskAlternate),
            (KeyCode.shift, .maskShift),
            (KeyCode.command, .maskCommand)
        ].filter { flags.contains($0.1) }

        var held: CGEventFlags = []
        for (code, flag) in modifiers {
            held.insert(flag)
            post(code, keyDown: true, flags: held, source: source)
        }

        post(key, keyDown: true, flags: flags, source: source)
        post(key, keyDown: false, flags: flags, source: source)

        for (code, flag) in modifiers.reversed() {
            held.remove(flag)
            post(code, keyDown: false, flags: held, source: source)
        }
    }

    /// Presses the key that types `character` on the user's own layout.
    private func postCharacter(_ character: Character, flags: CGEventFlags) {
        guard let key = KeyboardLayout.keyCode(for: character) else { return }
        postKey(key, flags: flags)
    }

    private func post(_ key: CGKeyCode, keyDown: Bool, flags: CGEventFlags, source: CGEventSource?) {
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: keyDown) else { return }
        event.flags = flags
        event.post(tap: .cghidEventTap)
    }

    private func runTool(_ path: String, arguments: [String]) {
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: path)
            task.arguments = arguments
            do {
                try task.run()
            } catch {
                NSLog("[SystemController] Failed to run \(path): \(error.localizedDescription)")
            }
        }
    }

    private func feedback(icon: String, title: String, subtitle: String? = nil) {
        HapticManager.shared.triggerClick()
        HUDManager.shared.show(icon: icon, title: title, subtitle: subtitle)
    }
}

// MARK: - Screen locking

/// Wrapper over the private login framework, which locks the screen the same
/// way the menu bar's "Lock Screen" item does.
private final class LoginServices {
    static let shared = LoginServices()

    private typealias LockScreen = @convention(c) () -> Int32
    private let lock: LockScreen?

    private init() {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/login.framework/login", RTLD_LAZY),
              let symbol = dlsym(handle, "SACLockScreenImmediate") else {
            lock = nil
            return
        }
        lock = unsafeBitCast(symbol, to: LockScreen.self)
    }

    /// `true` when the screen was locked.
    func lockScreen() -> Bool {
        guard let lock else { return false }
        return lock() == 0
    }
}

// MARK: - Brightness backend

/// Thin wrapper over the private DisplayServices framework so brightness can be
/// read and set directly, giving the same progress HUD as the volume control.
private final class BrightnessService {
    static let shared = BrightnessService()

    private typealias GetBrightness = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetBrightness = @convention(c) (CGDirectDisplayID, Float) -> Int32

    private let get: GetBrightness?
    private let set: SetBrightness?

    private init() {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY),
              let getSym = dlsym(handle, "DisplayServicesGetBrightness"),
              let setSym = dlsym(handle, "DisplayServicesSetBrightness") else {
            get = nil
            set = nil
            return
        }
        get = unsafeBitCast(getSym, to: GetBrightness.self)
        set = unsafeBitCast(setSym, to: SetBrightness.self)
    }

    func brightness() -> Float? {
        guard let get else { return nil }
        var level: Float = 0
        guard get(CGMainDisplayID(), &level) == 0 else { return nil }
        return level
    }

    @discardableResult
    func setBrightness(_ level: Float) -> Bool {
        guard let set else { return false }
        return set(CGMainDisplayID(), level) == 0
    }
}
