import Foundation

public enum RuntimeCommand {
    public enum ParseError: Error, Equatable, Sendable {
        case empty
        case hasArguments
    }

    public static func parse(_ raw: String) -> Result<String, ParseError> {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return .failure(.empty)
        }
        if trimmed.contains(where: { $0.isWhitespace }) {
            return .failure(.hasArguments)
        }
        return .success(trimmed)
    }

    public static func resolve(
        command: String,
        pathEnvironment: String,
        home: URL,
        fileManager: FileManager = .default
    ) -> URL? {
        let expanded = expand(command, home: home)
        if expanded.contains("/") {
            guard fileManager.isExecutableFile(atPath: expanded) else { return nil }
            return URL(fileURLWithPath: expanded)
        }
        for directory in AgentService.searchDirectories(pathEnvironment: pathEnvironment, home: home) {
            let url = directory.appendingPathComponent(command)
            if fileManager.isExecutableFile(atPath: url.path) {
                return url
            }
        }
        return nil
    }

    private static func expand(_ command: String, home: URL) -> String {
        if command == "~" {
            return home.path
        }
        if command.hasPrefix("~/") {
            return home.appendingPathComponent(String(command.dropFirst(2))).path
        }
        return command
    }
}
