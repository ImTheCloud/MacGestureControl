// SystemController.swift
// Performs the actual system side effect behind every gesture.
import Cocoa
import CoreAudio
import AudioToolbox

/// Virtual key codes used by the keyboard-driven actions.
private enum KeyCode {
    static let space: CGKeyCode = 49
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

        // macOS drops synthesised input from an untrusted process without
        // reporting anything, so an action would otherwise show its HUD and
        // quietly do nothing — which is exactly how a stale Accessibility grant
        // looks from the outside.
        guard !action.requiresAccessibility || AXIsProcessTrusted() else {
            HUDManager.shared.show(
                icon: "lock.trianglebadge.exclamationmark.fill",
                title: "Accessibility Access Required",
                subtitle: "\(action.title) cannot run — grant access from the menu bar popover"
            )
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
        case .screenshot:
            takeScreenshot()
        case .spotlight:
            postKey(KeyCode.space, flags: .maskCommand)
            feedback(icon: "magnifyingglass", title: "Spotlight")
        case .launchApp:
            launchApp(bundleId: AppSettings.shared.launchTargetBundleId)
        }
    }

    // MARK: - Audio

    private func adjustVolume(up: Bool) {
        guard let device = defaultOutputDevice(), let current = outputVolume(of: device) else { return }

        var target = max(0, min(1, current + (up ? volumeStep : -volumeStep)))

        // Outputs do not report round numbers: this USB device answers
        // 0.125434 for what should be two sixteenths, so stepping down lands
        // just above zero rather than on it — and just above zero is still
        // audible. Anything within half a step of silence is silence.
        if !up, target < volumeStep / 2 { target = 0 }

        setOutputVolume(target, on: device)

        // Raising the volume on a muted output should be audible.
        if up, target > 0, isMuted(device) == true {
            setMuted(false, on: device)
        } else if !up, target == 0 {
            // Zero gain is not silence on every output — measured here: the
            // step down lands on exactly 0.000000000 with the device still
            // unmuted, and something is still playing. macOS's own volume keys
            // mute when the last step reaches zero, which is why one press
            // silences a Mac and one swipe used to leave a whisper behind.
            setMuted(true, on: device)
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

    /// Where a device's level control actually lives.
    ///
    /// Not every output has a main volume: this Mac's USB output carries one
    /// per channel and lets the system emulate a main one on top. Writing
    /// through that emulation does not stick — measured, a step down from
    /// 0.125434 came back as 0.125434 two steps later — while the channels take
    /// the value they are handed, 0.0 included. So the channels are used
    /// whenever they exist, and the emulation only when nothing else does.
    private enum VolumeControl {
        case channels([AudioObjectPropertyElement])
        case virtualMain
        case unavailable
    }

    private func channelVolumeAddress(element: AudioObjectPropertyElement) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: element
        )
    }

    private var virtualVolumeAddress: AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    private func volumeControl(of device: AudioObjectID) -> VolumeControl {
        var main = channelVolumeAddress(element: kAudioObjectPropertyElementMain)
        if AudioObjectHasProperty(device, &main) { return .channels([kAudioObjectPropertyElementMain]) }

        let channels = stereoChannels(of: device, scope: kAudioDevicePropertyScopeOutput).filter { element in
            var address = channelVolumeAddress(element: element)
            return AudioObjectHasProperty(device, &address)
        }
        if !channels.isEmpty { return .channels(channels) }

        var virtual = virtualVolumeAddress
        return AudioObjectHasProperty(device, &virtual) ? .virtualMain : .unavailable
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
        let addresses: [AudioObjectPropertyAddress]
        switch volumeControl(of: device) {
        case .channels(let elements): addresses = elements.map(channelVolumeAddress(element:))
        case .virtualMain: addresses = [virtualVolumeAddress]
        case .unavailable: return nil
        }

        let levels = addresses.compactMap { address -> Float32? in
            var address = address
            var volume: Float32 = 0
            var size = UInt32(MemoryLayout<Float32>.size)
            guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &volume) == noErr else { return nil }
            return volume
        }
        guard !levels.isEmpty else { return nil }

        // Channels can sit at slightly different levels; the mean is what the
        // user thinks of as "the volume".
        return levels.reduce(0, +) / Float32(levels.count)
    }

    private func setOutputVolume(_ volume: Float32, on device: AudioObjectID) {
        let addresses: [AudioObjectPropertyAddress]
        switch volumeControl(of: device) {
        case .channels(let elements): addresses = elements.map(channelVolumeAddress(element:))
        case .virtualMain: addresses = [virtualVolumeAddress]
        case .unavailable: return
        }

        for address in addresses {
            var address = address
            var settable: DarwinBoolean = false
            guard AudioObjectIsPropertySettable(device, &address, &settable) == noErr, settable.boolValue else { continue }
            var value = volume
            AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &value)
        }
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

        // A gesture can carry a click of its own: with "tap to click" on, a
        // corner tap also clicks wherever the pointer is. That click lands in
        // screencapture's crosshair as an empty selection and cancels it, so
        // let it finish first.
        DispatchQueue.main.asyncAfter(deadline: .now() + screenshotClickSettleDelay) {
            // Interactive area selection, straight to the clipboard.
            self.runTool("/usr/sbin/screencapture", arguments: ["-i", "-c"])
        }
    }

    // MARK: - Apps

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
    /// but system-wide shortcuts such as Spotlight ignore them.
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
