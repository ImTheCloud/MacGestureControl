// LaunchAtLoginManager.swift
import Foundation
import ServiceManagement
import AppKit

class LaunchAtLoginManager: ObservableObject {
    static let shared = LaunchAtLoginManager()

    private let launchAgentIdentifier = "com.imthecloud.MacGestureControl"
    private var launchAgentURL: URL {
        let libraryDir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        let launchAgentsDir = libraryDir.appendingPathComponent("LaunchAgents")
        return launchAgentsDir.appendingPathComponent("\(launchAgentIdentifier).plist")
    }

    @Published var isEnabled: Bool = false

    private init() {
        checkStatus()
    }

    func checkStatus() {
        if #available(macOS 13.0, *) {
            if SMAppService.mainApp.status == .enabled {
                self.isEnabled = true
                return
            }
        }
        // Fallback check LaunchAgents directory
        self.isEnabled = FileManager.default.fileExists(atPath: launchAgentURL.path)
    }

    func setEnabled(_ enabled: Bool) {
        self.isEnabled = enabled

        // 1. Try modern SMAppService (if running inside a proper .app bundle)
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                        return
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    }
                }
            } catch {
                NSLog("SMAppService registration note: \(error.localizedDescription) - falling back to LaunchAgent")
            }
        }

        // 2. Fallback: Manage LaunchAgent plist in ~/Library/LaunchAgents/
        let fileManager = FileManager.default
        let launchAgentsDir = launchAgentURL.deletingLastPathComponent()

        if enabled {
            do {
                try fileManager.createDirectory(at: launchAgentsDir, withIntermediateDirectories: true, attributes: nil)
                let executablePath = Bundle.main.executablePath ?? CommandLine.arguments[0]
                let absolutePath = (executablePath as NSString).expandingTildeInPath

                let plistContent: [String: Any] = [
                    "Label": launchAgentIdentifier,
                    "ProgramArguments": [absolutePath],
                    "RunAtLoad": true,
                    "KeepAlive": false,
                    "ProcessType": "Interactive"
                ]

                let data = try PropertyListSerialization.data(fromPropertyList: plistContent, format: .xml, options: 0)
                try data.write(to: launchAgentURL, options: .atomic)
                NSLog("LaunchAgent created at: \(launchAgentURL.path)")
            } catch {
                NSLog("Failed to write LaunchAgent: \(error.localizedDescription)")
            }
        } else {
            if fileManager.fileExists(atPath: launchAgentURL.path) {
                try? fileManager.removeItem(at: launchAgentURL)
                NSLog("LaunchAgent removed")
            }
        }
    }
}
