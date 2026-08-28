// LaunchAtLoginManager.swift
import Foundation
import ServiceManagement
import AppKit

/// Registers the app to start at login.
///
/// `SMAppService` is the supported route and works when the app runs from a
/// bundle. A plain `swift run` binary is not a bundle, so a LaunchAgent plist is
/// written instead.
final class LaunchAtLoginManager: ObservableObject {
    static let shared = LaunchAtLoginManager()

    @Published private(set) var isEnabled: Bool = false

    private let identifier = "com.imthecloud.MacGestureControl"

    /// True when running from a real .app bundle, where SMAppService applies.
    private var isBundled: Bool {
        Bundle.main.bundleIdentifier != nil && Bundle.main.bundlePath.hasSuffix(".app")
    }

    private var launchAgentURL: URL {
        FileManager.default
            .urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LaunchAgents")
            .appendingPathComponent("\(identifier).plist")
    }

    private init() {
        refresh()
    }

    func refresh() {
        if isBundled, SMAppService.mainApp.status == .enabled {
            isEnabled = true
            return
        }
        isEnabled = FileManager.default.fileExists(atPath: launchAgentURL.path)
    }

    func setEnabled(_ enabled: Bool) {
        if isBundled {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
                refresh()
                return
            } catch {
                NSLog("[LaunchAtLogin] SMAppService failed (\(error.localizedDescription)); using LaunchAgent")
            }
        }

        enabled ? writeLaunchAgent() : removeLaunchAgent()
        refresh()
    }

    private func writeLaunchAgent() {
        let executable = Bundle.main.executablePath ?? CommandLine.arguments[0]
        let plist: [String: Any] = [
            "Label": identifier,
            "ProgramArguments": [(executable as NSString).expandingTildeInPath],
            "RunAtLoad": true,
            "KeepAlive": false,
            "ProcessType": "Interactive"
        ]

        do {
            try FileManager.default.createDirectory(
                at: launchAgentURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            try data.write(to: launchAgentURL, options: .atomic)
        } catch {
            NSLog("[LaunchAtLogin] Failed to write LaunchAgent: \(error.localizedDescription)")
        }
    }

    private func removeLaunchAgent() {
        guard FileManager.default.fileExists(atPath: launchAgentURL.path) else { return }
        try? FileManager.default.removeItem(at: launchAgentURL)
    }
}
