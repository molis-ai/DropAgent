import AppKit
import Foundation
import SwiftUI

enum AppearancePreference: String, Codable, CaseIterable, Identifiable {
    case light
    case dark
    case system

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }

    @MainActor
    var resolvedIsDark: Bool {
        switch self {
        case .light: return false
        case .dark: return true
        case .system:
            return NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        }
    }
}

enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case zh
    case en
    case system

    var id: String { rawValue }

    static var systemIsChinese: Bool {
        if let first = Locale.preferredLanguages.first, first.hasPrefix("zh") {
            return true
        }
        return Locale.current.language.languageCode?.identifier == "zh"
    }

    var resolved: AppLanguage {
        switch self {
        case .zh, .en: return self
        case .system: return Self.systemIsChinese ? .zh : .en
        }
    }
}

struct AppPreferences: Codable, Equatable {
    var appearance: AppearancePreference
    var language: AppLanguage
    var inboxPath: String?
    var jobsPath: String?
    var setupCardDismissed: Bool
    var toggleHotKey: HotKeyChord
    var captureHotKey: HotKeyChord
    var filesHotKey: HotKeyChord
    var hideHotKey: HotKeyChord
    var pasteHotKey: HotKeyChord
    var copyHotKey: HotKeyChord
    var deleteHotKey: HotKeyChord

    static let `default` = AppPreferences()

    init(
        appearance: AppearancePreference = .light,
        language: AppLanguage = .system,
        inboxPath: String? = nil,
        jobsPath: String? = nil,
        setupCardDismissed: Bool = false,
        toggleHotKey: HotKeyChord = .toggleDefault,
        captureHotKey: HotKeyChord = .captureDefault,
        filesHotKey: HotKeyChord = .filesDefault,
        hideHotKey: HotKeyChord = .hideDefault,
        pasteHotKey: HotKeyChord = .pasteDefault,
        copyHotKey: HotKeyChord = .copyDefault,
        deleteHotKey: HotKeyChord = .deleteDefault
    ) {
        self.appearance = appearance
        self.language = language
        self.inboxPath = inboxPath
        self.jobsPath = jobsPath
        self.setupCardDismissed = setupCardDismissed
        self.toggleHotKey = toggleHotKey
        self.captureHotKey = captureHotKey
        self.filesHotKey = filesHotKey
        self.hideHotKey = hideHotKey
        self.pasteHotKey = pasteHotKey
        self.copyHotKey = copyHotKey
        self.deleteHotKey = deleteHotKey
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        appearance = try container.decodeIfPresent(AppearancePreference.self, forKey: .appearance) ?? .light
        language = try container.decodeIfPresent(AppLanguage.self, forKey: .language) ?? .system
        inboxPath = try container.decodeIfPresent(String.self, forKey: .inboxPath)
        jobsPath = try container.decodeIfPresent(String.self, forKey: .jobsPath)
        setupCardDismissed = try container.decodeIfPresent(Bool.self, forKey: .setupCardDismissed) ?? false
        toggleHotKey = try container.decodeIfPresent(HotKeyChord.self, forKey: .toggleHotKey) ?? .toggleDefault
        captureHotKey = try container.decodeIfPresent(HotKeyChord.self, forKey: .captureHotKey) ?? .captureDefault
        filesHotKey = try container.decodeIfPresent(HotKeyChord.self, forKey: .filesHotKey) ?? .filesDefault
        hideHotKey = try container.decodeIfPresent(HotKeyChord.self, forKey: .hideHotKey) ?? .hideDefault
        pasteHotKey = try container.decodeIfPresent(HotKeyChord.self, forKey: .pasteHotKey) ?? .pasteDefault
        copyHotKey = try container.decodeIfPresent(HotKeyChord.self, forKey: .copyHotKey) ?? .copyDefault
        deleteHotKey = try container.decodeIfPresent(HotKeyChord.self, forKey: .deleteHotKey) ?? .deleteDefault
    }

    enum CodingKeys: String, CodingKey {
        case appearance
        case language
        case inboxPath
        case jobsPath
        case setupCardDismissed
        case toggleHotKey
        case captureHotKey
        case filesHotKey
        case hideHotKey
        case pasteHotKey
        case copyHotKey
        case deleteHotKey
    }

    var inboxURL: URL? {
        inboxPath.map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    var jobsURL: URL? {
        jobsPath.map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    static func load() -> AppPreferences {
        guard let data = try? Data(contentsOf: DropAgentPaths.prefsFile),
              let decoded = try? JSONDecoder().decode(AppPreferences.self, from: data)
        else { return .default }
        return decoded
    }

    func save() {
        try? DropAgentPaths.ensure()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(self) {
            try? data.write(to: DropAgentPaths.prefsFile, options: .atomic)
        }
    }
}
