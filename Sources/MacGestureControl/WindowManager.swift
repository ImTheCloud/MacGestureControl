// WindowManager.swift
// Moves and resizes the frontmost window through the Accessibility API.
import AppKit
import ApplicationServices

/// Not exposed as a constant by ApplicationServices, but the attribute every
/// standard macOS window uses for its green full-screen button.
private let axFullScreenAttribute = "AXFullScreen"

final class WindowManager {
    static let shared = WindowManager()

    private init() {}

    func perform(_ action: GestureAction) {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        guard let window = focusedWindow(of: app.processIdentifier) else {
            HUDManager.shared.show(
                icon: "exclamationmark.triangle.fill",
                title: "No Active Window",
                subtitle: AXIsProcessTrusted() ? "Focus a window first" : "Grant Accessibility access"
            )
            return
        }

        if action == .minimizeWindow {
            AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
            announce(action, app: app)
            return
        }

        if action == .fullScreenWindow {
            let isFullScreen = boolAttribute(window, axFullScreenAttribute) ?? false
            AXUIElementSetAttributeValue(
                window,
                axFullScreenAttribute as CFString,
                (isFullScreen ? kCFBooleanFalse : kCFBooleanTrue) as CFTypeRef
            )
            announce(action, app: app)
            return
        }

        // Tiling a full-screen window does nothing useful, so leave full screen first.
        if boolAttribute(window, axFullScreenAttribute) == true {
            AXUIElementSetAttributeValue(window, axFullScreenAttribute as CFString, kCFBooleanFalse)
        }

        guard let screen = screen(containing: window) else { return }
        guard let frame = targetFrame(for: action, on: screen) else { return }

        setFrame(window, to: frame)
        announce(action, app: app)
    }

    // MARK: - Geometry

    private func targetFrame(for action: GestureAction, on screen: NSScreen) -> CGRect? {
        let area = screen.visibleFrame

        switch action {
        case .snapLeft:
            return CGRect(x: area.minX, y: area.minY, width: area.width / 2, height: area.height)
        case .snapRight:
            return CGRect(x: area.midX, y: area.minY, width: area.width / 2, height: area.height)
        case .snapTop:
            return CGRect(x: area.minX, y: area.midY, width: area.width, height: area.height / 2)
        case .snapBottom:
            return CGRect(x: area.minX, y: area.minY, width: area.width, height: area.height / 2)
        case .maximizeWindow:
            return area
        case .centerWindow:
            let width = area.width * 0.75
            let height = area.height * 0.80
            return CGRect(
                x: area.minX + (area.width - width) / 2,
                y: area.minY + (area.height - height) / 2,
                width: width,
                height: height
            )
        default:
            return nil
        }
    }

    /// Converts a Cocoa rect (origin bottom-left of the primary screen) into the
    /// Accessibility coordinate space (origin top-left of the primary screen).
    /// Flipping against the window's own screen — as the previous version did —
    /// misplaced windows on every secondary display.
    private func accessibilityOrigin(for frame: CGRect) -> CGPoint {
        guard let primary = NSScreen.screens.first else { return frame.origin }
        return CGPoint(x: frame.minX, y: primary.frame.maxY - frame.maxY)
    }

    private func screen(containing window: AXUIElement) -> NSScreen? {
        guard let current = currentFrame(of: window) else { return NSScreen.main ?? NSScreen.screens.first }
        let center = CGPoint(x: current.midX, y: current.midY)
        // `current` is already in Cocoa space, so a plain containment test works.
        return NSScreen.screens.first { $0.frame.contains(center) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
    }

    private func currentFrame(of window: AXUIElement) -> CGRect? {
        guard let position = pointAttribute(window, kAXPositionAttribute),
              let size = sizeAttribute(window, kAXSizeAttribute),
              let primary = NSScreen.screens.first else { return nil }
        // Back from Accessibility space into Cocoa space.
        return CGRect(
            x: position.x,
            y: primary.frame.maxY - position.y - size.height,
            width: size.width,
            height: size.height
        )
    }

    private func setFrame(_ window: AXUIElement, to frame: CGRect) {
        var size = frame.size
        var origin = accessibilityOrigin(for: frame)

        // Size first, then position, then size again: a window that is still too
        // large to fit at the new origin would otherwise be pushed back by macOS.
        if let value = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, value)
        }
        if let value = AXValueCreate(.cgPoint, &origin) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value)
        }
        if let value = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, value)
        }
    }

    // MARK: - Accessibility helpers

    private func focusedWindow(of pid: pid_t) -> AXUIElement? {
        let app = AXUIElementCreateApplication(pid)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &value) == .success,
              let result = value,
              CFGetTypeID(result) == AXUIElementGetTypeID() else { return nil }
        return (result as! AXUIElement)
    }

    private func boolAttribute(_ element: AXUIElement, _ attribute: String) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let number = value as? Bool else { return nil }
        return number
    }

    private func axValue(_ element: AXUIElement, _ attribute: String) -> AXValue? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let result = value,
              CFGetTypeID(result) == AXValueGetTypeID() else { return nil }
        return (result as! AXValue)
    }

    private func pointAttribute(_ element: AXUIElement, _ attribute: String) -> CGPoint? {
        guard let value = axValue(element, attribute) else { return nil }
        var point = CGPoint.zero
        guard AXValueGetValue(value, .cgPoint, &point) else { return nil }
        return point
    }

    private func sizeAttribute(_ element: AXUIElement, _ attribute: String) -> CGSize? {
        guard let value = axValue(element, attribute) else { return nil }
        var size = CGSize.zero
        guard AXValueGetValue(value, .cgSize, &size) else { return nil }
        return size
    }

    private func announce(_ action: GestureAction, app: NSRunningApplication) {
        HapticManager.shared.triggerClick()
        HUDManager.shared.show(icon: action.icon, title: action.title, subtitle: app.localizedName)
    }
}
