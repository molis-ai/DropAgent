import DropAgentJob
import SwiftUI

struct RecipeChooser: View {
    @ObservedObject var session: AppSession

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                recipeButton(
                    title: session.actionBarEditing ? Copy.t("完成", "Done") : Copy.t("整理", "Arrange"),
                    symbol: session.actionBarEditing ? "checkmark" : "line.3.horizontal",
                    enabled: true,
                    selected: session.actionBarEditing,
                    help: Copy.t("隐藏或调整动作顺序", "Hide actions or change their order"),
                    identifier: "recipe-arrange"
                ) {
                    session.setActionBarEditing(!session.actionBarEditing)
                }
                ForEach(session.barSlots(organizing: session.actionBarEditing)) { slot in
                    HStack(spacing: 0) {
                        if session.actionBarEditing {
                            Button {
                                session.moveSlot(id: slot.id, by: -1)
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(Palette.muted)
                                    .frame(width: 16, height: 32)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("action-left-\(slot.id)")
                        }
                        recipeButton(
                            title: slotTitle(slot),
                            symbol: slotSymbol(slot),
                            enabled: session.actionBarEditing || session.canRunSlot(slot),
                            selected: false,
                            help: session.slotHelp(slot),
                            identifier: slotButtonID(slot)
                        ) {
                            if session.actionBarEditing == false {
                                session.chooseSlot(slot)
                            }
                        }
                        if session.actionBarEditing {
                            Button {
                                session.hideSlot(slot)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(Palette.muted)
                                    .frame(width: 16, height: 32)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("action-hide-\(slot.id)")
                            Button {
                                session.moveSlot(id: slot.id, by: 1)
                            } label: {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(Palette.muted)
                                    .frame(width: 16, height: 32)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("action-right-\(slot.id)")
                        }
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
                    session.setActionBarEditing(false)
                    session.toggleOther()
                }
                recipeButton(
                    title: Copy.t("添加", "Add"),
                    symbol: "plus",
                    enabled: true,
                    selected: session.shortcutDraft != nil,
                    help: Copy.t("添加快捷动作", "Add a shortcut action"),
                    identifier: "recipe-add"
                ) {
                    session.openShortcutComposer()
                }
            }
            .padding(.leading, 2)
        }
        .accessibilityIdentifier("acts")
    }

    private func slotTitle(_ slot: ActionSlot) -> String {
        switch slot {
        case .recipe(let recipe):
            return Copy.recipeShort(recipe)
        case .shortcut(let id):
            return session.shortcut(id: id)?.name ?? Copy.t("快捷", "Shortcut")
        }
    }

    private func slotSymbol(_ slot: ActionSlot) -> String {
        switch slot {
        case .recipe(let recipe):
            return RecipeGlyph.symbol(recipe)
        case .shortcut:
            return RecipeGlyph.symbol(.shortcut)
        }
    }

    private func slotButtonID(_ slot: ActionSlot) -> String {
        switch slot {
        case .recipe(let recipe):
            return "recipe-\(recipe.rawValue)"
        case .shortcut(let id):
            return "recipe-shortcut-\(id)"
        }
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
        case .imageText: return "text.viewfinder"
        case .pdfText: return "doc.text"
        case .translate: return "globe"
        case .redact: return "eye.slash"
        case .toMarkdown: return "doc.richtext"
        case .brief: return "square.stack"
        case .shortcut: return "bolt"
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
