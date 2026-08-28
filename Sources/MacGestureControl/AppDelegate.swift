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

    let settings = AppSettings.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self

        // 1. Setup SwiftUI Settings Popover
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 380, height: 380)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: SettingsView())
        self.popover = popover

        // 2. Setup Menu Bar Item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateStatusItemIcon(settings.menuBarIcon)

        // 3. Request Accessibility & Install Fallback Event Tap
        requestAccessibilityPermission()
        installEventTap()

        // 4. Start Native Multitouch Engine (2, 3, 4 & 5 fingers, pinches, corner taps)
        MultitouchEngine.shared.start()
    }

    func updateStatusItemIcon(_ iconName: String) {
        guard let button = statusItem.button else { return }
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        if let img = NSImage(systemSymbolName: iconName, accessibilityDescription: "MacGesture Control")?.withSymbolConfiguration(config) {
            button.image = img
        } else {
            button.image = NSImage(systemSymbolName: "hand.draw.fill", accessibilityDescription: "MacGesture Control")
        }
        button.target = self
        button.action = #selector(togglePopover(_:))
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

    // MARK: - Event Tap (Fallback Scroll Wheel Interceptor)
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

                // Only intercept 2-finger scroll if explicitly mapped to an action
                if abs(deltaY) > 0.4 && delegate.settings.twoFingerVerticalAction != .none {
                    SystemController.shared.execute(delegate.settings.twoFingerVerticalAction, up: deltaY > 0)
                }

                if abs(deltaX) > 0.4 && delegate.settings.twoFingerHorizontalAction != .none {
                    SystemController.shared.execute(delegate.settings.twoFingerHorizontalAction, up: deltaX > 0)
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
}
