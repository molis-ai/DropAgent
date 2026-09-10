import DropAgentJob
import DropAgentShelf
import Foundation

struct ShortcutAction: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var kinds: [ItemKind]
    var prompt: String

    init(id: String = UUID().uuidString, name: String, kinds: [ItemKind], prompt: String) {
        self.id = id
        self.name = name
        self.kinds = kinds
        self.prompt = prompt
    }

    var kindSet: Set<ItemKind> { Set(kinds) }

    var storedRecipe: String { RecipeID.storedShortcut(id: id) }
}

enum ActionSlot: Equatable, Identifiable {
    case recipe(RecipeID)
    case shortcut(String)

    var id: String {
        switch self {
        case .recipe(let recipe): return recipe.rawValue
        case .shortcut(let id): return RecipeID.storedShortcut(id: id)
        }
    }

    static func parse(_ raw: String) -> ActionSlot? {
        if let recipe = RecipeID(rawValue: raw), recipe != .shortcut {
            return .recipe(recipe)
        }
        if let id = RecipeID.shortcutStoredID(raw) {
            return .shortcut(id)
        }
        return nil
    }
}

struct ShortcutDraft: Equatable {
    var id: String?
    var name: String
    var kinds: Set<ItemKind>
    var prompt: String

    static func blank(matching: [ItemKind] = []) -> ShortcutDraft {
        ShortcutDraft(
            id: nil,
            name: "",
            kinds: matching.isEmpty ? [.pdf, .markdown, .clip, .web] : Set(matching),
            prompt: ""
        )
    }

    static func edit(_ action: ShortcutAction) -> ShortcutDraft {
        ShortcutDraft(id: action.id, name: action.name, kinds: action.kindSet, prompt: action.prompt)
    }
}

enum ActionBarLayout {
    static var defaultOrder: [String] {
        RecipeID.barRecipes.map(\.rawValue)
    }

    static func slots(order: [String], shortcuts: [ShortcutAction]) -> [ActionSlot] {
        let known = Set(shortcuts.map(\.id))
        let parsed = (order.isEmpty ? defaultOrder : order).compactMap(ActionSlot.parse)
        var seen = Set<String>()
        var result: [ActionSlot] = []
        for slot in parsed {
            if seen.contains(slot.id) { continue }
            if case .shortcut(let id) = slot, known.contains(id) == false { continue }
            if case .recipe(let recipe) = slot, recipe == .shortcut { continue }
            seen.insert(slot.id)
            result.append(slot)
        }
        return result
    }
}
