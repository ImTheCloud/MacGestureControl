// WindowManager.swift
import AppKit
import ApplicationServices

class WindowManager {
    static let shared = WindowManager()

    func snapActiveWindow(to action: GestureAction) {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return }
        let pid = frontApp.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        var focusedWindow: AnyObject?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow)
        guard result == .success, let window = focusedWindow else {
            HUDManager.shared.show(icon: "exclamationmark.triangle.fill", title: "No Active Window", subtitle: "Select a window first")
            return
        }

        let windowElement = window as! AXUIElement
        guard let screen = NSScreen.main else { return }
        let screenRect = screen.visibleFrame

        switch action {
        case .snapLeft:
            let targetFrame = CGRect(
                x: screenRect.origin.x,
                y: screen.frame.height - (screenRect.origin.y + screenRect.height),
                width: screenRect.width / 2,
                height: screenRect.height
            )
            setWindowFrame(windowElement, frame: targetFrame)
            HUDManager.shared.show(icon: "rectangle.lefthalf.filled", title: "Snapped Left", subtitle: frontApp.localizedName)
            HapticManager.shared.triggerClick()

        case .snapRight:
            let targetFrame = CGRect(
                x: screenRect.origin.x + (screenRect.width / 2),
                y: screen.frame.height - (screenRect.origin.y + screenRect.height),
                width: screenRect.width / 2,
                height: screenRect.height
            )
            setWindowFrame(windowElement, frame: targetFrame)
            HUDManager.shared.show(icon: "rectangle.righthalf.filled", title: "Snapped Right", subtitle: frontApp.localizedName)
            HapticManager.shared.triggerClick()

        case .maximizeWindow:
            let targetFrame = CGRect(
                x: screenRect.origin.x,
                y: screen.frame.height - (screenRect.origin.y + screenRect.height),
                width: screenRect.width,
                height: screenRect.height
            )
            setWindowFrame(windowElement, frame: targetFrame)
            HUDManager.shared.show(icon: "arrow.up.left.and.arrow.down.right", title: "Maximized", subtitle: frontApp.localizedName)
            HapticManager.shared.triggerClick()

        case .centerWindow:
            let width = screenRect.width * 0.75
            let height = screenRect.height * 0.80
            let targetFrame = CGRect(
                x: screenRect.origin.x + (screenRect.width - width) / 2,
                y: screen.frame.height - (screenRect.origin.y + screenRect.height) + (screenRect.height - height) / 2,
                width: width,
                height: height
            )
            setWindowFrame(windowElement, frame: targetFrame)
            HUDManager.shared.show(icon: "rectangle.center.inset.filled", title: "Centered", subtitle: frontApp.localizedName)
            HapticManager.shared.triggerClick()

        case .minimizeWindow:
            AXUIElementSetAttributeValue(windowElement, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
            HUDManager.shared.show(icon: "minus.rectangle", title: "Minimized", subtitle: frontApp.localizedName)
            HapticManager.shared.triggerClick()

        default:
            break
        }
    }

    private func setWindowFrame(_ window: AXUIElement, frame: CGRect) {
        var origin = CGPoint(x: frame.origin.x, y: frame.origin.y)
        var size = CGSize(width: frame.size.width, height: frame.size.height)

        if let positionValue = AXValueCreate(.cgPoint, &origin) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
        }
        if let sizeValue = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        }
    }
}
