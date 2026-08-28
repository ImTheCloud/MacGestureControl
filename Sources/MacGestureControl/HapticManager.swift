// HapticManager.swift
import AppKit

class HapticManager {
    static let shared = HapticManager()

    private let performer = NSHapticFeedbackManager.defaultPerformer

    func trigger(pattern: NSHapticFeedbackManager.FeedbackPattern = .alignment) {
        guard AppSettings.shared.hapticsEnabled else { return }
        performer.perform(pattern, performanceTime: .default)
    }

    func triggerClick() {
        trigger(pattern: .levelChange)
    }
}
