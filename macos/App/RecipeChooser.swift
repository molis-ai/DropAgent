import DropAgentJob
import SwiftUI

struct RecipeChooser: View {
    @ObservedObject var session: AppSession

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
            ForEach(RecipeID.allCases, id: \.self) { recipe in
                recipeRow(
                    title: Copy.recipeShort(recipe),
                    blurb: Copy.recipeBlurb(recipe),
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
        GridRow(alignment: .center) {
            Button(action: action) {
                HStack(spacing: 6) {
                    Image(systemName: symbol)
                        .font(.system(size: 12, weight: .regular))
                        .imageScale(.small)
                    Text(title)
                        .lineLimit(1)
                }
            }
            .buttonStyle(TagButtonStyle(selected: selected))
            .disabled(!enabled)
            .help(help)
            .accessibilityIdentifier(identifier)
            .accessibilityLabel(title)
            .accessibilityHint(hint)
            .gridColumnAlignment(.leading)

            Text(blurb)
                .font(.system(size: 12))
                .foregroundStyle(enabled ? Palette.muted : Palette.faint)
                .lineSpacing(1)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityHidden(true)
        }
    }
}

struct RecipeOptionChips: View {
    @ObservedObject var session: AppSession
    let recipe: RecipeID

    var body: some View {
        let group = RecipeCatalog.choices(for: recipe)
        let current = session.choiceID(for: recipe)
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(group.label)
                if group.hint.isEmpty == false {
                    Text("· \(group.hint)")
                }
            }
            .font(.system(size: 10))
            .foregroundStyle(Palette.muted)
            VStack(spacing: 1) {
                ForEach(group.choices) { choice in
                    let on = current == choice.id
                    Button {
                        session.setChoice(choice.id, for: recipe)
                    } label: {
                        HStack {
                            Text(choice.title)
                                .font(.system(size: 12, weight: .medium))
                            Spacer()
                            Circle()
                                .fill(on ? Palette.text : Color.clear)
                                .frame(width: 5, height: 5)
                        }
                        .padding(.horizontal, 8)
                        .frame(height: 34)
                        .background(on ? Palette.panelPress : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("recipe-opt-\(choice.id)")
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
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
        VStack(spacing: 0) {
            row("读", count > 1 ? "\(count) 份材料的副本" : "这份材料的副本")
            Divider().background(Palette.line)
            row("写", write)
            Divider().background(Palette.line)
            row("网络", network)
            Divider().background(Palette.line)
            row("隔离", isolation)
        }
        .padding(.bottom, 4)
    }

    private func row(_ key: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(key)
                .foregroundStyle(Palette.muted)
                .frame(width: 56, alignment: .leading)
            Text(value)
                .foregroundStyle(Palette.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 12, weight: .medium))
        .padding(.vertical, 5)
        .frame(minHeight: 28)
    }
}
