// SingleInstance.swift
import Foundation

/// Stops a second copy of the app from running alongside the first.
///
/// Two instances both read the trackpad, so every gesture fires twice: the
/// volume jumps two steps at once, and play/pause toggles and immediately
/// toggles back, which looks like nothing happening at all.
enum SingleInstance {
    /// Held open for the lifetime of the process; the lock is released by the
    /// kernel when it exits, including after a crash or a kill.
    private static var lockDescriptor: Int32 = -1

    private static var lockPath: String {
        NSTemporaryDirectory() + "com.imthecloud.MacGestureControl.lock"
    }

    /// `true` when this process may run, `false` when another instance holds the lock.
    static func acquire() -> Bool {
        let descriptor = open(lockPath, O_CREAT | O_RDWR, 0o644)
        // If the lock file cannot be opened at all, prefer running over refusing to start.
        guard descriptor >= 0 else { return true }

        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            close(descriptor)
            return false
        }

        lockDescriptor = descriptor
        return true
    }
}
