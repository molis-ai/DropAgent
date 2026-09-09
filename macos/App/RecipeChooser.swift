import DropAgentJob
import SwiftUI

struct RecipeChooser: View {
    @ObservedObject var session: AppSession

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(RecipeID.allCases, id: \.self) { recipe in
                    recipeButton(
                        title: Copy.recipeShort(recipe),
                        symbol: RecipeGlyph.symbol(recipe),
                        enabled: session.hasRecipe && session.recipeFitsSelection(recipe),
                        selected: false,
                        help: session.recipeFitsSelection(recipe) ? Copy.recipeBlurb(recipe) : session.recipeHelp(recipe),
                        identifier: "recipe-\(recipe.rawValue)"
                    ) {
                        session.chooseRecipe(recipe)
                    }
                }
                recipeButton(
                    title: Copy.otherShort,
                    symbol: "ellipsis",
                    enabled: session.hasAgent,
                    selected: session.otherOpen,
                    help: Copy.t("打开对话浮窗，发给当前终端", "Open the chat float and send to the current terminal"),
                    identifier: "recipe-other"
                ) {
                    session.toggleOther()
                }
            }
            .padding(.leading, 2)
        }
        .accessibilityIdentifier("acts")
    }

    private func recipeButton(
        title: String,
        symbol: String,
        enabled: Bool,
        selected: Bool,
        help: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(enabled ? Palette.accent : Palette.faint)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.text)
                    .lineLimit(1)
                    .fixedSize()
            }
            .padding(.horizontal, 7)
            .frame(height: 32)
            .background(selected ? Palette.panelPress : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.42)
        .help(help)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(title)
        .accessibilityHint(help)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct RecipeOptionChips: View {
    @ObservedObject var session: AppSession
    let recipe: RecipeID
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let group = RecipeCatalog.choices(for: recipe)
        let current = session.choiceID(for: recipe)
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(group.label).font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.text)
                Text(group.hint).font(.system(size: 11))
                    .foregroundStyle(Palette.muted)
            }
            HStack(spacing: 8) {
                ForEach(group.choices) { choice in
                    let on = current == choice.id
                    Button { session.setChoice(choice.id, for: recipe) } label: {
                        Text(choice.title)
                            .font(.system(size: 12, weight: on ? .semibold : .regular))
                            .foregroundStyle(Palette.text)
                            .padding(.horizontal, 10)
                            .frame(height: 28)
                            .background(on ? Palette.panelPress : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("recipe-opt-\(choice.id)")
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
                Spacer(minLength: 0)
            }
            .animation(reduceMotion ? nil : Palette.motion, value: current)
        }
    }
}

enum RecipeGlyph {
    static func symbol(_ id: RecipeID) -> String {
        switch id {
        case .summarize: return "text.alignleft"
        case .extract: return "curlybraces"
        case .translate: return "globe"
        case .redact: return "eye.slash"
        case .toMarkdown: return "doc.richtext"
        case .brief: return "square.stack"
        }
    }
}

struct RecipeFacts: View {
    let count: Int
    let write: String
    let network: String
    let isolation: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            row(Copy.t("读", "Read"), Copy.t("\(count) 份材料的副本", "Copies of \(count) materials"))
            row(Copy.t("写", "Write"), write)
            row(Copy.t("网络", "Network"), network)
            row(Copy.t("隔离", "Isolation"), isolation)
        }
    }

    private func row(_ key: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(key)
                .frame(width: 36, alignment: .leading)
                .foregroundStyle(Palette.muted)
            Text(value)
                .foregroundStyle(Palette.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 12))
    }
}
