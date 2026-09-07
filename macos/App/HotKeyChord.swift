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
