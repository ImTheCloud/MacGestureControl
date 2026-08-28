// KeyboardLayout.swift
import Foundation
import Carbon

/// Turns a character into the virtual key code that produces it on the layout
/// the user is actually typing on.
///
/// Virtual key codes name physical positions, not letters. Key 13 is "W" on a
/// US keyboard but "Z" on AZERTY, so a hard-coded code sends the wrong
/// shortcut to everyone outside the US — Command-W became Command-Z, which
/// quietly triggered Undo instead of closing the window.
enum KeyboardLayout {
    private static let lock = NSLock()
    private static var cache: [Character: CGKeyCode]?
    private static var observerInstalled = false

    /// The key code producing `character` on the current layout, if any.
    static func keyCode(for character: Character) -> CGKeyCode? {
        lock.lock()
        defer { lock.unlock() }

        installObserverIfNeeded()
        if cache == nil { cache = buildMap() }
        return cache?[Character(character.lowercased())]
    }

    /// The character `keyCode` types on the current layout, for display.
    static func character(for keyCode: CGKeyCode) -> String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let data = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data
        let produced = character(forKeyCode: UInt16(keyCode), data: data, keyboardType: UInt32(LMGetKbdType()))
        guard let produced, !produced.isEmpty, produced.first?.isWhitespace == false else { return nil }
        return produced
    }

    /// Layouts can be switched at any time, so the map is rebuilt on change.
    private static func installObserverIfNeeded() {
        guard !observerInstalled else { return }
        observerInstalled = true
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil,
            queue: nil
        ) { _ in
            lock.lock()
            cache = nil
            lock.unlock()
        }
    }

    private static func buildMap() -> [Character: CGKeyCode] {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return [:] }

        let data = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data
        let keyboardType = UInt32(LMGetKbdType())
        var map: [Character: CGKeyCode] = [:]

        // 0...127 covers every physical key the layout can describe.
        for code in 0...127 as ClosedRange<UInt16> {
            guard let produced = character(forKeyCode: code, data: data, keyboardType: keyboardType),
                  let first = produced.first,
                  !first.isWhitespace else { continue }
            // First position wins, so the primary key for a letter is preferred.
            if map[first] == nil { map[first] = CGKeyCode(code) }
        }
        return map
    }

    private static func character(forKeyCode code: UInt16, data: Data, keyboardType: UInt32) -> String? {
        var deadKeyState: UInt32 = 0
        var length = 0
        var characters = [UniChar](repeating: 0, count: 4)

        let status = data.withUnsafeBytes { raw -> OSStatus in
            guard let layout = raw.bindMemory(to: UCKeyboardLayout.self).baseAddress else { return -1 }
            return UCKeyTranslate(
                layout, code, UInt16(kUCKeyActionDown), 0, keyboardType,
                UInt32(kUCKeyTranslateNoDeadKeysBit), &deadKeyState,
                characters.count, &length, &characters
            )
        }
        guard status == noErr, length > 0 else { return nil }
        return String(utf16CodeUnits: characters, count: length)
    }
}
