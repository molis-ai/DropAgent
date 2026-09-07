import AppKit
import Carbon
import Foundation

struct HotKeyChord: Codable, Equatable, Sendable {
    var keyCode: UInt32
    var carbonModifiers: UInt32

    static let toggleDefault = HotKeyChord(keyCode: UInt32(kVK_ANSI_D), carbonModifiers: UInt32(controlKey | optionKey))
    static let captureDefault = HotKeyChord(keyCode: UInt32(kVK_ANSI_W), carbonModifiers: UInt32(controlKey | optionKey))
    static let filesDefault = HotKeyChord(keyCode: UInt32(kVK_ANSI_A), carbonModifiers: UInt32(controlKey | optionKey))
    static let hideDefault = HotKeyChord(keyCode: UInt32(kVK_Escape), carbonModifiers: 0)
    static let pasteDefault = HotKeyChord(keyCode: UInt32(kVK_ANSI_V), carbonModifiers: UInt32(cmdKey))
    static let copyDefault = HotKeyChord(keyCode: UInt32(kVK_ANSI_C), carbonModifiers: UInt32(cmdKey))
    static let deleteDefault = HotKeyChord(keyCode: UInt32(kVK_Delete), carbonModifiers: 0)

    var hasModifier: Bool { carbonModifiers != 0 }

    var cocoaFlags: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if carbonModifiers & UInt32(controlKey) != 0 { flags.insert(.control) }
        if carbonModifiers & UInt32(optionKey) != 0 { flags.insert(.option) }
        if carbonModifiers & UInt32(shiftKey) != 0 { flags.insert(.shift) }
        if carbonModifiers & UInt32(cmdKey) != 0 { flags.insert(.command) }
        return flags
    }

    var label: String {
        var parts = ""
        if carbonModifiers & UInt32(controlKey) != 0 { parts += "⌃" }
        if carbonModifiers & UInt32(optionKey) != 0 { parts += "⌥" }
        if carbonModifiers & UInt32(shiftKey) != 0 { parts += "⇧" }
        if carbonModifiers & UInt32(cmdKey) != 0 { parts += "⌘" }
        parts += Self.keyName(keyCode)
        return parts
    }

    func matches(_ event: NSEvent) -> Bool {
        UInt32(event.keyCode) == keyCode
            && event.modifierFlags.intersection([.command, .option, .control, .shift]) == cocoaFlags
    }

    static func from(event: NSEvent) -> HotKeyChord? {
        let code = UInt32(event.keyCode)
        if modifierKeyCodes.contains(code) { return nil }
        var carbon: UInt32 = 0
        let flags = event.modifierFlags
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        return HotKeyChord(keyCode: code, carbonModifiers: carbon)
    }

    private static let modifierKeyCodes: Set<UInt32> = [
        UInt32(kVK_Command), UInt32(kVK_RightCommand),
        UInt32(kVK_Option), UInt32(kVK_RightOption),
        UInt32(kVK_Control), UInt32(kVK_RightControl),
        UInt32(kVK_Shift), UInt32(kVK_RightShift),
        UInt32(kVK_Function), UInt32(kVK_CapsLock),
    ]

    private static func keyName(_ code: UInt32) -> String {
        switch Int(code) {
        case kVK_Escape: return "Esc"
        case kVK_Space: return "Space"
        case kVK_Return, kVK_ANSI_KeypadEnter: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Delete: return "⌫"
        case kVK_ForwardDelete: return "⌦"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        default:
            let keyCode = CGKeyCode(code)
            let input = TISCopyCurrentKeyboardLayoutInputSource().takeRetainedValue()
            guard let raw = TISGetInputSourceProperty(input, kTISPropertyUnicodeKeyLayoutData) else {
                return String(format: "Key%d", code)
            }
            let data = Unmanaged<CFData>.fromOpaque(raw).takeUnretainedValue() as Data
            return data.withUnsafeBytes { buffer -> String in
                guard let layout = buffer.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else {
                    return String(format: "Key%d", code)
                }
                var dead: UInt32 = 0
                var length: Int = 0
                var chars = [UniChar](repeating: 0, count: 4)
                let err = UCKeyTranslate(
                    layout,
                    keyCode,
                    UInt16(kUCKeyActionDisplay),
                    0,
                    UInt32(LMGetKbdType()),
                    OptionBits(kUCKeyTranslateNoDeadKeysBit),
                    &dead,
                    4,
                    &length,
                    &chars
                )
                if err == noErr, length > 0 {
                    return String(utf16CodeUnits: chars, count: length).uppercased()
                }
                return String(format: "Key%d", code)
            }
        }
    }
}

enum HotKeySlot: String, CaseIterable, Identifiable {
    case toggle
    case capture
    case files
    case hide
    case paste
    case copy
    case delete

    var id: String { rawValue }
    var isGlobal: Bool { self == .toggle || self == .capture || self == .files }

    var defaultChord: HotKeyChord {
        switch self {
        case .toggle: return .toggleDefault
        case .capture: return .captureDefault
        case .files: return .filesDefault
        case .hide: return .hideDefault
        case .paste: return .pasteDefault
        case .copy: return .copyDefault
        case .delete: return .deleteDefault
        }
    }
}

struct HotKeyAvailability: Equatable, Sendable {
    var toggle: Bool
    var capture: Bool
    var files: Bool
}

@MainActor
enum HotKeyCopy {
    static func missingJobLine(tuiTitle: String) -> String {
        Copy.t(
            "\(tuiTitle) 没有无界面执行入口，动作不能跑。",
            "\(tuiTitle) has no headless entry, so recipes cannot run."
        )
    }

    static func recipeActorLine(hasRecipe: Bool, hasAgent: Bool, tuiTitle: String) -> String {
        if hasRecipe {
            return Copy.t("\(tuiTitle) 在任务副本里跑。", "\(tuiTitle) runs in a job copy.")
        }
        if hasAgent { return missingJobLine(tuiTitle: tuiTitle) }
        return Copy.t("未发现终端 Agent。", "No terminal agent found.")
    }

    static func recipeApprovalWaitLine(tuiTitle: String) -> String {
        Copy.t(
            "这里点不了同意。等 \(tuiTitle) 自己过，或取消。",
            "You cannot approve here. Wait for \(tuiTitle), or cancel."
        )
    }

    static func footer(hasAgent: Bool, tuiTitle: String, toggleOK: Bool, captureOK: Bool, filesOK: Bool = true) -> String {
        let first = hasAgent
            ? Copy.t(
                "发送进 \(tuiTitle) 终端，不是副本沙箱。文件可拖出或复制。",
                "Send goes into the \(tuiTitle) terminal, not the copy sandbox. Files can be dragged or copied."
            )
            : Copy.t("没有终端 Agent，只能先放架子。", "No terminal agent, so items can only sit on the shelf.")
        return first + "\n" + hotkeyLine(hasAgent: hasAgent, toggleOK: toggleOK, captureOK: captureOK, filesOK: filesOK)
    }

    static func hotkeyLine(hasAgent: Bool, toggleOK: Bool, captureOK: Bool, filesOK: Bool = true) -> String {
        let toggle = HotKeyCenter.shared.toggleChord.label
        let capture = HotKeyCenter.shared.captureChord.label
        let files = HotKeyCenter.shared.filesChord.label
        let filesBit = filesOK
            ? Copy.t("\(files) 加入选中文件。", "\(files) adds the selected files.")
            : Copy.t("加入文件的快捷键被占用。", "The add-files hotkey is taken.")
        let base: String
        switch (toggleOK, captureOK) {
        case (true, true):
            base = hasAgent
                ? Copy.t("\(toggle) 打开，\(capture) 抓当前页。", "\(toggle) opens the panel, \(capture) captures the current page.")
                : Copy.t("\(capture) 仍可抓当前页。", "\(capture) can still capture the current page.")
        case (false, true):
            base = Copy.t(
                "\(toggle) 被占用，点菜单栏图标打开。\(capture) 抓当前页。",
                "\(toggle) is taken; click the menu bar icon. \(capture) captures the current page."
            )
        case (true, false):
            base = Copy.t(
                "\(toggle) 打开。\(capture) 被占用，用菜单抓页。",
                "\(toggle) opens the panel. \(capture) is taken; capture from the menu."
            )
        case (false, false):
            base = Copy.t(
                "快捷键被占用。点菜单栏图标打开，用菜单抓页。",
                "Hotkeys are taken. Click the menu bar icon; capture from the menu."
            )
        }
        return base + " " + filesBit
    }

    static func menuFilesTitle(filesOK: Bool) -> String {
        filesOK
            ? Copy.t("加入选中的文件 (\(HotKeyCenter.shared.filesChord.label))", "Add selected files (\(HotKeyCenter.shared.filesChord.label))")
            : Copy.t("加入选中的文件", "Add selected files")
    }

    static func emptyHint(hasAgent: Bool, tuiTitle: String, captureOK: Bool) -> String {
        let paste = HotKeyCenter.shared.pasteChord.label
        let capture = HotKeyCenter.shared.captureChord.label
        if hasAgent {
            return Copy.t(
                "先放下，点 + 或搜索，\(paste) 粘贴，或拖到右侧发给 \(tuiTitle)",
                "Drop here, tap +, search, paste with \(paste), or drag right to send to \(tuiTitle)"
            )
        }
        return captureOK
            ? Copy.t(
                "没有终端也能先放着，\(paste) 粘贴，或 \(capture) 抓当前页",
                "You can still stage files, paste with \(paste), or capture with \(capture)"
            )
            : Copy.t(
                "没有终端也能先放着，\(paste) 粘贴，或用菜单抓当前页",
                "You can still stage files, paste with \(paste), or capture from the menu"
            )
    }

    static func workIdleHint(hasAgent: Bool, hasRecipe: Bool, tuiTitle: String, captureOK: Bool, hasItems: Bool) -> String {
        if hasAgent && hasRecipe {
            if hasItems {
                return Copy.t(
                    "点列表里的文件，或拖到左侧加入、拖到这一区发给 \(tuiTitle)。",
                    "Click a file in the list, drop left to stage, or drop here to send to \(tuiTitle)."
                )
            }
            return Copy.t(
                "拖到左侧加入架子，或拖到这一区发给 \(tuiTitle)。",
                "Drop left to stage, or drop here to send to \(tuiTitle)."
            )
        }
        if hasAgent {
            return Copy.t(
                "\(tuiTitle) 没有无界面执行入口。终端仍可发送。点右上角可换成有执行入口的 CLI。",
                "\(tuiTitle) has no headless entry. You can still send to the terminal. Use the chip to pick a CLI with an exec entry."
            )
        }
        return captureOK
            ? Copy.t(
                "未发现终端 Agent。仍可把文件放到左边，或 \(HotKeyCenter.shared.captureChord.label) 抓当前页。也可以点右上角选择已装的 TUI。",
                "No terminal agent found. You can still stage files on the left, or capture with \(HotKeyCenter.shared.captureChord.label). The chip can pick an installed TUI."
            )
            : Copy.t(
                "未发现终端 Agent。仍可把文件放到左边，或用菜单抓当前页。也可以点右上角选择已装的 TUI。",
                "No terminal agent found. You can still stage files on the left, or capture from the menu. The chip can pick an installed TUI."
            )
    }

    static func menuCaptureTitle(captureOK: Bool) -> String {
        captureOK
            ? Copy.t("抓取当前页 (\(HotKeyCenter.shared.captureChord.label))", "Capture current page (\(HotKeyCenter.shared.captureChord.label))")
            : Copy.t("抓取当前页", "Capture current page")
    }
}

@MainActor
final class HotKeyCenter {
    static let shared = HotKeyCenter()
    private var toggle: (() -> Void)?
    private var capture: (() -> Void)?
    private var files: (() -> Void)?
    private var handler: EventHandlerRef?
    private var toggleRef: EventHotKeyRef?
    private var captureRef: EventHotKeyRef?
    private var filesRef: EventHotKeyRef?
    private(set) var toggleChord = HotKeyChord.toggleDefault
    private(set) var captureChord = HotKeyChord.captureDefault
    private(set) var filesChord = HotKeyChord.filesDefault
    private(set) var hideChord = HotKeyChord.hideDefault
    private(set) var pasteChord = HotKeyChord.pasteDefault
    private(set) var copyChord = HotKeyChord.copyDefault
    private(set) var deleteChord = HotKeyChord.deleteDefault

    @discardableResult
    func register(
        toggle: @escaping () -> Void,
        capture: @escaping () -> Void,
        files: @escaping () -> Void,
        toggleChord: HotKeyChord = .toggleDefault,
        captureChord: HotKeyChord = .captureDefault,
        filesChord: HotKeyChord = .filesDefault,
        hideChord: HotKeyChord = .hideDefault,
        pasteChord: HotKeyChord = .pasteDefault,
        copyChord: HotKeyChord = .copyDefault,
        deleteChord: HotKeyChord = .deleteDefault
    ) -> HotKeyAvailability {
        self.toggle = toggle
        self.capture = capture
        self.files = files
        self.toggleChord = toggleChord
        self.captureChord = captureChord
        self.filesChord = filesChord
        self.hideChord = hideChord
        self.pasteChord = pasteChord
        self.copyChord = copyChord
        self.deleteChord = deleteChord
        unregister()
        if handler == nil {
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
                    if hotKeyID.id == 3 { center.files?() }
                }
                return noErr
            }, 1, &spec, pointer, &handler)
        }

        let toggleOK = toggleChord.hasModifier && RegisterEventHotKey(
            toggleChord.keyCode,
            toggleChord.carbonModifiers,
            EventHotKeyID(signature: OSType(0x44524131), id: 1),
            GetApplicationEventTarget(),
            0,
            &toggleRef
        ) == noErr
        let captureOK = captureChord.hasModifier && RegisterEventHotKey(
            captureChord.keyCode,
            captureChord.carbonModifiers,
            EventHotKeyID(signature: OSType(0x44524132), id: 2),
            GetApplicationEventTarget(),
            0,
            &captureRef
        ) == noErr
        let filesOK = filesChord.hasModifier && RegisterEventHotKey(
            filesChord.keyCode,
            filesChord.carbonModifiers,
            EventHotKeyID(signature: OSType(0x44524133), id: 3),
            GetApplicationEventTarget(),
            0,
            &filesRef
        ) == noErr
        return HotKeyAvailability(toggle: toggleOK, capture: captureOK, files: filesOK)
    }

    func unregister() {
        if let toggleRef {
            UnregisterEventHotKey(toggleRef)
            self.toggleRef = nil
        }
        if let captureRef {
            UnregisterEventHotKey(captureRef)
            self.captureRef = nil
        }
        if let filesRef {
            UnregisterEventHotKey(filesRef)
            self.filesRef = nil
        }
    }
}
