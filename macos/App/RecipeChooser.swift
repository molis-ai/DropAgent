import DropAgentJob
import SwiftUI

struct RecipeChooser: View {
    @ObservedObject var session: AppSession

    var body: some View {
        VStack(spacing: 2) {
            ForEach(RecipeID.allCases, id: \.self) { recipe in
                recipeRow(
                    title: Copy.recipeShort(recipe),
                    blurb: session.recipeFitsSelection(recipe) || session.selectedItems.isEmpty
                        ? Copy.recipeBlurb(recipe) : session.recipeHelp(recipe),
                    symbol: RecipeGlyph.symbol(recipe),
                    enabled: session.hasRecipe && session.recipeFitsSelection(recipe),
                    selected: false,
                    help: session.recipeHelp(recipe),
                    identifier: "recipe-\(recipe.rawValue)",
                    hint: session.recipeFitsSelection(recipe)
                        ? Copy.recipeBlurb(recipe)
                        : session.recipeHelp(recipe)
                ) {
                    session.chooseRecipe(recipe)
                }
            }
            Divider().overlay(Palette.line).padding(.vertical, 8)
            recipeRow(
                title: Copy.otherShort,
                blurb: Copy.otherBlurb,
                symbol: "ellipsis",
                enabled: session.hasAgent,
                selected: session.otherOpen,
                help: Copy.t("展开底下输入框，发给当前终端", "Show the composer and send to the current terminal"),
                identifier: "recipe-other",
                hint: Copy.otherBlurb
            ) {
                session.toggleOther()
            }
        }
    }

    private func recipeRow(
        title: String,
        blurb: String,
        symbol: String,
        enabled: Bool,
        selected: Bool,
        help: String,
        identifier: String,
        hint: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(enabled ? Palette.accent : Palette.faint)
                    .frame(width: 34, height: 34)
                    .background(enabled ? Palette.accent.opacity(0.07) : Palette.panel2)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.text)
                    Text(blurb)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Palette.faint)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(RecipeButtonStyle(selected: selected))
        .disabled(!enabled)
        .help(help)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(title)
        .accessibilityHint(hint)
    }

}

struct RecipeOptionChips: View {
    @ObservedObject var session: AppSession
    let recipe: RecipeID
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let group = RecipeCatalog.choices(for: recipe)
        let current = session.choiceID(for: recipe)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(group.label).font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.text)
                Text(group.hint).font(.system(size: 11))
                    .foregroundStyle(Palette.muted)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
                ForEach(group.choices) { choice in
                    let on = current == choice.id
                    Button { session.setChoice(choice.id, for: recipe) } label: {
                        HStack(spacing: 8) {
                            Image(systemName: on ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(on ? Palette.accent : Palette.faint)
                                .accessibilityHidden(true)
                            Text(choice.title)
                                .font(.system(size: 12, weight: on ? .semibold : .regular))
                                .foregroundStyle(Palette.text)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 10)
                        .frame(minHeight: 40)
                        .background(on ? Palette.accent.opacity(0.08) : Palette.panel2.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(on ? Palette.accent.opacity(0.5) : Palette.line, lineWidth: 1))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("recipe-opt-\(choice.id)")
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
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
        VStack(spacing: 12) {
            row("doc.on.doc", Copy.t("读取", "Read"), Copy.t("\(count) 份材料的副本", "Copies of \(count) materials"))
            row("square.and.pencil", Copy.t("写入", "Write"), write)
            row("network", Copy.t("网络", "Network"), network)
            row("shield.lefthalf.filled", Copy.t("隔离", "Isolation"), isolation)
        }
        .padding(14)
        .background(Palette.panel2.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func row(_ symbol: String, _ key: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbol).frame(width: 16).accessibilityHidden(true)
            Text(key).frame(width: 40, alignment: .leading)
            Text(value)
                .foregroundStyle(Palette.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 11.5))
        .foregroundStyle(Palette.muted)
    }
}
