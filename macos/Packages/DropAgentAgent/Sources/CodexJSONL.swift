import Foundation

public enum CodexJSONL {
    public static func event(from line: Data) -> AgentEvent? {
        guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else {
            return nil
        }
        if let message = object["message"] as? String, !message.isEmpty, isHuman(message) {
            return AgentEvent(message: message)
        }
        guard let type = object["type"] as? String, !type.isEmpty else {
            return nil
        }
        if shouldIgnore(type) { return nil }
        let item = object["item"] as? [String: Any]
        let itemType = ((item?["type"] as? String) ?? "").lowercased()
        guard let text = display(type: type, itemType: itemType) else {
            return nil
        }
        return AgentEvent(message: text)
    }

    public static func events(from text: String) -> [AgentEvent] {
        text.split(separator: "\n").compactMap { line in
            event(from: Data(line.utf8))
        }
    }

    private static func isHuman(_ message: String) -> Bool {
        if message.contains(where: { $0 >= "\u{4e00}" && $0 <= "\u{9fff}" }) { return true }
        if message.contains(" ") { return true }
        if message.contains(".") { return false }
        return true
    }

    private static func shouldIgnore(_ type: String) -> Bool {
        type.contains("token") || type.hasPrefix("event_msg") || type.hasSuffix(".delta")
    }

    private static func display(type: String, itemType: String) -> String? {
        let lowered = type.lowercased()
        if lowered.contains("approval") || lowered.contains("auth") {
            return "等待授权"
        }
        if lowered.contains("error") || lowered.contains("failed") {
            return "失败"
        }
        switch lowered {
        case "thread.started", "turn.started":
            return "开始运行"
        case "turn.completed", "thread.completed":
            return "收尾"
        case "agent_message", "message":
            return "在写结果"
        case "item.started":
            return itemStarted(itemType)
        case "item.completed":
            return itemCompleted(itemType)
        default:
            return nil
        }
    }

    private static func itemStarted(_ itemType: String) -> String {
        if itemType.contains("search") || itemType.contains("web") {
            return "联网"
        }
        if itemType.contains("command") || itemType.contains("shell") || itemType.contains("mcp") || itemType.contains("tool") {
            return "工具调用"
        }
        if itemType.contains("file") || itemType.contains("patch") {
            return "在写文件"
        }
        if itemType.contains("message") {
            return "在写结果"
        }
        if itemType.contains("reason") {
            return "思考中"
        }
        return "进行中"
    }

    private static func itemCompleted(_ itemType: String) -> String? {
        if itemType.contains("command") || itemType.contains("shell") {
            return "工具调用完成"
        }
        if itemType.contains("message") {
            return "在写结果"
        }
        return nil
    }
}
