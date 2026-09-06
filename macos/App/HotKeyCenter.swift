import Carbon
import Foundation

struct HotKeyAvailability: Equatable, Sendable {
    var toggle: Bool
    var capture: Bool
}

enum HotKeyCopy {
    static func recipeActorLine(hasRecipe: Bool, hasAgent: Bool, tuiTitle: String) -> String {
        if hasRecipe == false { return "副本任务需要 Codex。" }
        if hasAgent { return "Codex 在副本里跑，不是 \(tuiTitle) 终端。" }
        return "Codex 在副本里跑。"
    }

    static let recipeApprovalWaitLine = "这里点不了同意。等 Codex 自己过，或取消。"

    static func footer(hasAgent: Bool, tuiTitle: String, toggleOK: Bool, captureOK: Bool) -> String {
        let first = hasAgent
            ? "发送进 \(tuiTitle) 终端，不是副本沙箱。文件可拖出或复制。"
            : "没有终端 Agent，只能先放架子。"
        return first + "\n" + hotkeyLine(hasAgent: hasAgent, toggleOK: toggleOK, captureOK: captureOK)
    }

    static func hotkeyLine(hasAgent: Bool, toggleOK: Bool, captureOK: Bool) -> String {
        switch (toggleOK, captureOK) {
        case (true, true):
            return hasAgent ? "⌃⌥D 打开，⌃⌥W 抓当前页。" : "⌃⌥W 仍可抓当前页。"
        case (false, true):
            return "⌃⌥D 被占用，点菜单栏图标打开。⌃⌥W 抓当前页。"
        case (true, false):
            return "⌃⌥D 打开。⌃⌥W 被占用，用菜单抓页。"
        case (false, false):
            return "快捷键被占用。点菜单栏图标打开，用菜单抓页。"
        }
    }

    static func emptyHint(hasAgent: Bool, tuiTitle: String, captureOK: Bool) -> String {
        if hasAgent {
            return "先放下，⌘V 粘贴，或拖到下方发给 \(tuiTitle)"
        }
        return captureOK
            ? "没有终端也能先放着，⌘V 粘贴，或 ⌃⌥W 抓当前页"
            : "没有终端也能先放着，⌘V 粘贴，或用菜单抓当前页"
    }

    static func workIdleHint(hasAgent: Bool, hasRecipe: Bool, tuiTitle: String, captureOK: Bool) -> String {
        if hasAgent && hasRecipe {
            return "点列表里的文件，或拖到上方加入、拖到这一区发给 \(tuiTitle)。"
        }
        if hasAgent {
            return "动作需要 Codex。终端可以发给 \(tuiTitle)。点右上角切换或指定可执行文件。"
        }
        return captureOK
            ? "未发现终端 Agent。仍可把文件放到上面，或 ⌃⌥W 抓当前页。也可以点右上角选择已装的 TUI。"
            : "未发现终端 Agent。仍可把文件放到上面，或用菜单抓当前页。也可以点右上角选择已装的 TUI。"
    }

    static func menuCaptureTitle(captureOK: Bool) -> String {
        captureOK ? "抓取当前页 (⌃⌥W)" : "抓取当前页"
    }
}

@MainActor
final class HotKeyCenter {
    static let shared = HotKeyCenter()
    private var toggle: (() -> Void)?
    private var capture: (() -> Void)?
    private var handler: EventHandlerRef?
    private var toggleRef: EventHotKeyRef?
    private var captureRef: EventHotKeyRef?

    @discardableResult
    func register(toggle: @escaping () -> Void, capture: @escaping () -> Void) -> HotKeyAvailability {
        self.toggle = toggle
        self.capture = capture
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { (_, event, userData) -> OSStatus in
            guard let userData, let event else { return noErr }
            let center = Unmanaged<HotKeyCenter>.fromOpaque(userData).takeUnretainedValue()
            var hotKeyID = EventHotKeyID()
            GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            DispatchQueue.main.async {
                if hotKeyID.id == 1 { center.toggle?() }
                if hotKeyID.id == 2 { center.capture?() }
            }
            return noErr
        }, 1, &spec, pointer, &handler)

        let toggleOK = RegisterEventHotKey(
            UInt32(kVK_ANSI_D),
            UInt32(controlKey | optionKey),
            EventHotKeyID(signature: OSType(0x44524131), id: 1),
            GetApplicationEventTarget(),
            0,
            &toggleRef
        ) == noErr
        let captureOK = RegisterEventHotKey(
            UInt32(kVK_ANSI_W),
            UInt32(controlKey | optionKey),
            EventHotKeyID(signature: OSType(0x44524132), id: 2),
            GetApplicationEventTarget(),
            0,
            &captureRef
        ) == noErr
        return HotKeyAvailability(toggle: toggleOK, capture: captureOK)
    }
}
