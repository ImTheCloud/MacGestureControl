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
        let hosting = NSHostingController(rootView: SettingsView())
        // Without this the controller never reports a preferred size, the
        // popover keeps its default 0x0 content size, and AppKit anchors the
        // resulting degenerate frame off the top of the screen.
        hosting.sizingOptions = [.preferredContentSize]

        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = hosting
        popover.contentSize = hosting.view.fittingSize
        self.popover = popover
    }

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover(_:))
        updateStatusItem(enabled: settings.isEnabled)
    }

    private func updateStatusItem(enabled: Bool) {
        guard let button = statusItem.button else { return }
        let configuration = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        button.image = NSImage(systemSymbolName: AppSettings.appGlyph, accessibilityDescription: "MacGesture Control")?
            .withSymbolConfiguration(configuration)
        button.appearsDisabled = !enabled
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
            return
        }

        // System settings can change behind our back, so re-read before showing.
        NativeGestureManager.shared.refresh()
        updatePopoverLayout(for: button)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    /// Lets the content grow into whatever the screen under the menu bar offers,
    /// so a tab only scrolls when it genuinely cannot fit.
    private func updatePopoverLayout(for button: NSStatusBarButton) {
        let screen = button.window?.screen ?? NSScreen.main
        guard let visibleHeight = screen?.visibleFrame.height else { return }
        PopoverLayout.shared.update(forScreenHeight: visibleHeight)

        // The hosting controller republishes its preferred size asynchronously;
        // seed it now so the first presentation is already the right size.
        if let hosting = popover.contentViewController {
            hosting.view.layoutSubtreeIfNeeded()
            popover.contentSize = hosting.view.fittingSize
        }
    }

    // MARK: - Settings observation

    /// Dimming the icon makes the paused state visible without opening the popover.
    /// `@Published` publishes in `willSet`, so the sink uses the value it is
    /// handed — reading the property back here would still return the old one.
    private func observeSettings() {
        settings.$isEnabled
            .removeDuplicates()
            .sink { [weak self] enabled in self?.updateStatusItem(enabled: enabled) }
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

    /// macOS attaches the grant to the code signature it was given, not to the
    /// name in the list. A bare binary from `swift build` is signed ad-hoc, so
    /// every rebuild produces a file the old grant no longer covers: System
    /// Settings keeps showing MacGestureControl switched on while
    /// `AXIsProcessTrusted()` says no. Worth spelling out, because the obvious
    /// reading of that screen is that the app is lying.
    let isBundled = Bundle.main.bundleURL.pathExtension == "app"

    private init() {}

    func refresh() {
        let trusted = AXIsProcessTrusted()
        if trusted != isTrusted { isTrusted = trusted }
    }

    func openSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    /// Selects the running executable in Finder, so it can be dragged onto the
    /// Accessibility list after the stale entry has been removed.
    func revealExecutable() {
        guard let url = Bundle.main.executableURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([isBundled ? Bundle.main.bundleURL : url])
    }
}
