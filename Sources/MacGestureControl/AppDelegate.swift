// AppDelegate.swift
import Cocoa
import SwiftUI
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var cancellables: Set<AnyCancellable> = []
    private var permissionTimer: Timer?

    private let settings = AppSettings.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        setUpPopover()
        setUpStatusItem()
        requestAccessibilityPermission()

        // The only input path: the multitouch engine reads the trackpad directly.
        MultitouchEngine.shared.start()

        observeSettings()
        startPermissionWatch()
    }

    func applicationWillTerminate(_ notification: Notification) {
        permissionTimer?.invalidate()
        MultitouchEngine.shared.stop()
    }

    // MARK: - UI

    private func setUpPopover() {
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: SettingsView())
        self.popover = popover
    }

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover(_:))
        updateStatusItem(icon: settings.menuBarIcon, enabled: settings.isEnabled)
    }

    private func updateStatusItem(icon: String, enabled: Bool) {
        guard let button = statusItem.button else { return }
        let configuration = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        let image = NSImage(systemSymbolName: icon, accessibilityDescription: "MacGesture Control")
            ?? NSImage(systemSymbolName: AppSettings.defaultMenuBarIcon, accessibilityDescription: "MacGesture Control")
        button.image = image?.withSymbolConfiguration(configuration)
        button.appearsDisabled = !enabled
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    // MARK: - Settings observation

    /// `@Published` publishes in `willSet`, so both sinks use the value they are
    /// handed — reading the property back here would still return the old one.
    private func observeSettings() {
        settings.$menuBarIcon
            .removeDuplicates()
            .sink { [weak self] icon in
                guard let self else { return }
                self.updateStatusItem(icon: icon, enabled: self.settings.isEnabled)
            }
            .store(in: &cancellables)

        // Dimming the icon makes the paused state visible without opening the popover.
        settings.$isEnabled
            .removeDuplicates()
            .sink { [weak self] enabled in
                guard let self else { return }
                self.updateStatusItem(icon: self.settings.menuBarIcon, enabled: enabled)
            }
            .store(in: &cancellables)
    }

    // MARK: - Accessibility permission

    private func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    /// macOS gives no notification when the user grants access, so the state is
    /// polled cheaply to keep the banner in the popover accurate.
    private func startPermissionWatch() {
        PermissionMonitor.shared.refresh()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            PermissionMonitor.shared.refresh()
        }
    }
}

/// Publishes whether the app currently holds Accessibility permission.
final class PermissionMonitor: ObservableObject {
    static let shared = PermissionMonitor()

    @Published private(set) var isTrusted: Bool = AXIsProcessTrusted()

    private init() {}

    func refresh() {
        let trusted = AXIsProcessTrusted()
        if trusted != isTrusted { isTrusted = trusted }
    }

    func openSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }
}
