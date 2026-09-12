import DropAgentJob
import Foundation

enum WheelAction: Equatable {
    case shelf
    case send
    case recipe(RecipeID)
}

struct WheelSlice: Equatable {
    var action: WheelAction
    var title: String
    var symbol: String
    var enabled: Bool
}

enum WheelLayout {
    static func slices(hasAgent: Bool, hasRecipe: Bool) -> [WheelSlice] {
        [
            WheelSlice(action: .shelf, title: Copy.t("加入材料", "Add files"), symbol: "tray.and.arrow.down", enabled: true),
            WheelSlice(action: .send, title: Copy.t("发给终端", "To terminal"), symbol: "arrow.right", enabled: hasAgent),
            WheelSlice(action: .recipe(.summarize), title: Copy.recipeShort(.summarize), symbol: RecipeGlyph.symbol(.summarize), enabled: hasRecipe),
            WheelSlice(action: .recipe(.extract), title: Copy.recipeShort(.extract), symbol: RecipeGlyph.symbol(.extract), enabled: hasRecipe),
            WheelSlice(action: .recipe(.translate), title: Copy.recipeShort(.translate), symbol: RecipeGlyph.symbol(.translate), enabled: hasRecipe),
            WheelSlice(action: .recipe(.toMarkdown), title: Copy.t("转 MD", "To MD"), symbol: RecipeGlyph.symbol(.toMarkdown), enabled: hasRecipe),
        ]
    }
}
