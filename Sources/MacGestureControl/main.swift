// main.swift
import Cocoa

let application = NSApplication.shared
// Held at top level: NSApplication does not retain its delegate.
var appDelegate: AppDelegate?

switch CommandLineInterface.parse(Array(CommandLine.arguments.dropFirst())) {
case .exit(let code):
    exit(code)

case .performAction(let action, let up):
    guard AppSettings.shared.isEnabled else {
        FileHandle.standardError.write(Data("MacGestureControl is paused — enable it first.\n".utf8))
        exit(1)
    }
    application.setActivationPolicy(.accessory)
    DispatchQueue.main.async {
        SystemController.shared.execute(action, up: up)
        // Give the action, its HUD and any launched app a moment to land.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { exit(0) }
    }
    application.run()

case .runApp:
    guard SingleInstance.acquire() else {
        FileHandle.standardError.write(Data(
            "MacGestureControl is already running — quit it first (its menu bar icon has a Quit button).\n".utf8
        ))
        exit(1)
    }
    appDelegate = AppDelegate()
    application.delegate = appDelegate
    application.setActivationPolicy(.accessory) // No Dock icon
    application.run()
}
