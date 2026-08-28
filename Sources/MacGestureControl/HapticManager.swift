// HapticManager.swift
import AppKit

final class HapticManager {
    static let shared = HapticManager()

    private let performer = NSHapticFeedbackManager.defaultPerformer

    private init() {}

    /// Light tick used for continuous gestures such as volume steps.
    func trigger(pattern: NSHapticFeedbackManager.FeedbackPattern = .alignment) {
        guard AppSettings.shared.hapticsEnabled else { return }
        performer.perform(pattern, performanceTime: .default)
    }

    /// Firmer click used when a discrete action commits.
    func triggerClick() {
        trigger(pattern: .levelChange)
    }
}
