// PopoverLayout.swift
// Sizing shared between the popover's AppKit host and its SwiftUI content.
import SwiftUI

/// How tall the scrolling area is allowed to grow, decided by the screen the
/// menu bar item lives on. The popover then takes its natural height and only
/// scrolls when a tab genuinely does not fit.
final class PopoverLayout: ObservableObject {
    static let shared = PopoverLayout()

    @Published var maxContentHeight: CGFloat = SettingsMetrics.minContentHeight

    private init() {}

    /// - Parameter visibleHeight: `visibleFrame.height` of the screen showing the menu bar.
    func update(forScreenHeight visibleHeight: CGFloat) {
        let available = visibleHeight - SettingsMetrics.chromeHeight - SettingsMetrics.screenMargin
        maxContentHeight = max(SettingsMetrics.minContentHeight, available.rounded(.down))
    }
}

enum SettingsMetrics {
    static let width: CGFloat = 440

    /// Everything outside the scrolling area: header, tab bar, footer and their
    /// dividers. Pinned by `SettingsLayoutTests` so it cannot drift.
    static let chromeHeight: CGFloat = 144

    /// Keeps a short tab from collapsing into a sliver.
    static let minContentHeight: CGFloat = 260

    /// Gap left below the popover and around the menu bar arrow.
    static let screenMargin: CGFloat = 44
}

/// Reports the natural height of the current tab's content.
struct ContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
