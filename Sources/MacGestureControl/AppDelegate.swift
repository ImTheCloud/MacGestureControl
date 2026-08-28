// AppDelegate.swift
import Cocoa
import CoreAudio
import AudioToolbox

enum MediaAction {
    case playPause
    case next
    case previous
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var eventTap: CFMachPort?
    var runLoopSource: CFRunLoopSource?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set up menu bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "speaker.wave.2.fill", accessibilityDescription: "Volume Control")
            button.action = #selector(showMenu(_:))
        }
        constructMenu()
        requestAccessibilityPermission()
        installEventTap()
    }

    func constructMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc func showMenu(_ sender: Any?) {}

    @objc func quit() {
        NSApplication.shared.terminate(self)
    }

    // MARK: - Accessibility Permission
    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Event Tap
    func installEventTap() {
        // Only listen for scroll wheel events for volume control.
        let mask = CGEventMask(1 << CGEventType.scrollWheel.rawValue)
        let callback: CGEventTapCallBack = { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
            guard let delegatePtr = refcon else { return Unmanaged.passUnretained(event) }
            let delegate = Unmanaged<AppDelegate>.fromOpaque(delegatePtr).takeUnretainedValue()
            if type == .scrollWheel {
                let deltaY = event.getDoubleValueField(.scrollWheelEventDeltaAxis1)
                if abs(deltaY) > 0.5 {
                    delegate.adjustSystemVolume(up: deltaY > 0)
                }
                // TODO: Add detection for brightness via modifier keys or other event types.
            }
            // Future gesture handling (swipe, tap, etc.) can be added here.
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
        let step: Float32 = 0.05 // 5% per swipe
        var newVolume = max(0, min(1, volume + (up ? step : -step)))
        AudioObjectSetPropertyData(deviceID, &volAddress, 0, nil, volSize, &newVolume)
    }

    // MARK: - Placeholder Features
    func adjustBrightness(up: Bool) {
        // TODO: implement brightness adjustment
    }

    func toggleMute() {
        // TODO: implement mute/unmute toggle
    }

    func controlMedia(action: MediaAction) {
        // TODO: implement media control (play/pause, next, previous)
    }

    func setMouseTrackingSpeed(increase: Bool) {
        // TODO: implement mouse tracking speed adjustment
    }

    func launchApplication(bundleID: String) {
        // TODO: implement launching of application by bundle identifier
    }
}
