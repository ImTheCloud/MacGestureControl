// CommandLineInterface.swift
// A small terminal surface, so actions can be tried out without binding them
// to a gesture first.
import Foundation

enum CommandLineInterface {
    enum Mode {
        case runApp
        case performAction(GestureAction, up: Bool)
        case exit(code: Int32)
    }

    static func parse(_ arguments: [String]) -> Mode {
        guard let first = arguments.first else { return .runApp }

        switch first {
        case "-h", "--help":
            print(usage)
            return .exit(code: 0)

        case "--version":
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            print(version ?? "dev")
            return .exit(code: 0)

        case "--list-actions":
            for category in ActionCategory.allCases {
                print("\(category.rawValue):")
                for action in GestureAction.allCases where action.category == category && action != .none {
                    print("  \(action.rawValue.padding(toLength: 22, withPad: " ", startingAt: 0)) \(action.title)")
                }
            }
            return .exit(code: 0)

        case "--run-action":
            guard arguments.count > 1 else {
                complain("--run-action needs an action identifier. Try --list-actions.")
                return .exit(code: 1)
            }
            guard let action = GestureAction(rawValue: arguments[1]), action != .none else {
                complain("Unknown action '\(arguments[1])'. Try --list-actions.")
                return .exit(code: 1)
            }
            let down = arguments.dropFirst(2).contains("--down")
            return .performAction(action, up: !down)

        default:
            complain("Unknown option '\(first)'.\n\n\(usage)")
            return .exit(code: 1)
        }
    }

    private static let usage = """
    MacGestureControl — trackpad gestures for macOS

    Usage:
      MacGestureControl                    Run the menu bar app
      MacGestureControl --run-action <id>  Perform one action, then exit
      MacGestureControl --list-actions     List every action identifier
      MacGestureControl --version
      MacGestureControl --help

    Options for --run-action:
      --down    Run the downward direction of a continuous action
                (volume and brightness; ignored by the others)

    Examples:
      MacGestureControl --run-action volume --down
      MacGestureControl --run-action snap_left
      MacGestureControl --run-action mission_control
    """

    private static func complain(_ message: String) {
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }
}
