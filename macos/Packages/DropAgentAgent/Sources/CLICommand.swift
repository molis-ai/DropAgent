import Foundation

public enum CLICommand {
    public static func posixQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    public static func shellExecutable() -> URL {
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        if FileManager.default.isExecutableFile(atPath: shell) {
            return URL(fileURLWithPath: shell)
        }
        return URL(fileURLWithPath: "/bin/zsh")
    }

    public static func line(executable: URL, prompt: String, help: String) -> String {
        let command = posixQuote(executable.path)
        let quoted = posixQuote(prompt)
        let args: String
        if HeadlessCLI.containsFlag(help, "--print") {
            args = "--print \(quoted)"
        } else if help.contains("-p,") || help.contains("-p ") {
            args = "-p \(quoted)"
        } else {
            args = quoted
        }
        return "\(command) \(args)"
    }
}
