import DropAgentJob
import SwiftUI

struct ActionChipFrameKey: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, next in next })
    }
}

struct DragGrip: View {
    var body: some View {
        HStack(spacing: 1.5) {
            VStack(spacing: 1.5) {
                dot
                dot
                dot
            }
            VStack(spacing: 1.5) {
                dot
                dot
                dot
            }
        }
        .frame(width: 8, height: 32)
        .contentShape(Rectangle())
        .help(Copy.t("拖动排序", "Drag to reorder"))
        .accessibilityLabel(Copy.t("拖动排序", "Drag to reorder"))
    }

    private var dot: some View {
        Circle()
            .fill(Palette.faint)
            .frame(width: 2, height: 2)
    }
}

struct RecipeChooser: View {
    @ObservedObject var session: AppSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var draggingID: String?
    @State private var dragLocation = CGPoint.zero
    @State private var grabOffset: CGFloat = 0
    @State private var dragOrder: [String] = []
    @State private var previewIDs: [String] = []
    @State private var chipFrames: [String: CGRect] = [:]
    @State private var startFrames: [String: CGRect] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if session.showsFirstActionHint {
                if session.guidedSample != nil {
                    SampleActionGuide(session: session)
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                    JourneyEcho(strong: Onboarding.coach)
                    Spacer(minLength: 8)
                    JourneyLink(title: Onboarding.coachDismiss, kind: .skip) {
                        session.dismissFirstActionHint()
                    }
                    .accessibilityIdentifier("onboard-coach-dismiss")
                }
                .accessibilityIdentifier("onboard-coach")
                }
            }
            if let notice = session.shortcutPoolNotice {
                poolNotice(notice)
            }
            if !session.hasRecipe && session.guidedSample == nil {
                HStack(spacing: 8) {
                    Text(Copy.t("总结、翻译等动作需要本机 Agent。图片与 PDF 可直接提取文字。", "Connect a local agent for summaries and translation. Images and PDFs can extract text now."))
                        .font(.system(size: 11.5))
                        .foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    Button(Copy.t("设置 Agent", "Set up agent")) {
                        session.settingsSection = .machine
                        session.settingsOpen = true
                    }
                    .buttonStyle(QuietButtonStyle(subtle: true))
                }
                .padding(.horizontal, 6)
            }
            actionRow
        }
    }

    private var actionRow: some View {
        HStack(spacing: 4) {
        ScrollView(.horizontal, showsIndicators: true) {
            HStack(spacing: 6) {
                ForEach(session.barSlots(organizing: session.actionBarEditing)) { slot in
                    slotChip(slot)
                        .opacity(draggingID == slot.id ? 0 : 1)
                        .offset(x: neighborOffset(slot.id))
                        .animation(
                            reduceMotion || draggingID == slot.id ? nil : Palette.selectionMotion,
                            value: previewIDs
                        )
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(
                                    key: ActionChipFrameKey.self,
                                    value: [slot.id: geo.frame(in: .named("action-bar"))]
                                )
                            }
                        )
                }
            }
            .padding(.leading, 2)
            .coordinateSpace(name: "action-bar")
            .overlay(alignment: .topLeading) { floatingChip }
            .onPreferenceChange(ActionChipFrameKey.self) { frames in
                if draggingID == nil {
                    chipFrames = frames
                }
            }
        }
        .scrollDisabled(draggingID != nil)
        .accessibilityIdentifier("acts")
                Divider()
                    .overlay(Palette.line)
                    .frame(height: 18)
                    .padding(.horizontal, 4)
                recipeButton(
                    title: Copy.t("对话", "Chat"),
                    symbol: "terminal",
                    tone: .plum,
                    enabled: session.hasAgent,
                    selected: session.otherOpen,
                    help: Copy.t("打开终端会话。不会生成新文件。发给终端请用轮盘。", "Open the terminal session. This does not create a new file. Send files from the wheel."),
                    identifier: "recipe-other"
                ) {
                    session.setActionBarEditing(false)
                    session.toggleOther()
                }
            Menu {
                Button(session.actionBarEditing ? Copy.t("完成整理", "Done arranging") : Copy.t("整理动作", "Arrange actions")) {
                    session.setActionBarEditing(!session.actionBarEditing)
                }.accessibilityIdentifier("recipe-arrange")
                Button(Copy.t("新建动作", "New action")) { session.openShortcutComposer() }
                    .accessibilityIdentifier("recipe-add")
            } label: {
                Image(systemName: "ellipsis").font(.system(size: 13)).foregroundStyle(Palette.muted).frame(width: 24, height: 30)
            }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                .help(Copy.t("管理动作", "Manage actions"))
        }
    }

    private func poolNotice(_ notice: ShortcutPoolNotice) -> some View {
        HStack(spacing: 8) {
            Text(Copy.t("「\(notice.name)」已保存", "“\(notice.name)” has been saved"))
                .font(.system(size: 12))
                .foregroundStyle(Palette.text)
            Button(Copy.t("加入动作栏", "Add to bar")) {
                session.pinPooledShortcutToBar()
            }
            .buttonStyle(QuietButtonStyle())
            .accessibilityIdentifier("pool-notice-pin")
            Button(Copy.t("打开设置", "Open settings")) {
                session.openActionPoolInSettings()
            }
            .buttonStyle(QuietButtonStyle())
            .accessibilityIdentifier("pool-notice-settings")
            Spacer(minLength: 0)
            Button {
                session.dismissShortcutPoolNotice()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
            }
            .buttonStyle(IconButtonStyle(size: 24))
            .accessibilityLabel(Copy.t("好", "OK"))
            .accessibilityIdentifier("pool-notice-dismiss")
        }
        .padding(.horizontal, 10)
        .accessibilityIdentifier("shortcut-pool-notice")
    }

    private func slotChip(_ slot: ActionSlot) -> some View {
        HStack(spacing: 0) {
            grabArea(slot)
            if session.actionBarEditing {
                Button {
                    session.hideSlot(slot)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .semibold))
                }
                .buttonStyle(IconButtonStyle(size: 24))
                .accessibilityIdentifier("action-hide-\(slot.id)")
            }
        }
    }

    @ViewBuilder
    private func grabArea(_ slot: ActionSlot) -> some View {
        HStack(spacing: 0) {
            if session.actionBarEditing {
                DragGrip()
                    .accessibilityIdentifier("action-handle-\(slot.id)")
                    .highPriorityGesture(dragGesture(for: slot.id))
            }
            recipeButton(
                title: slotTitle(slot),
                symbol: slotSymbol(slot),
                tone: slotTone(slot),
                enabled: session.actionBarEditing || session.canRunSlot(slot),
                selected: false,
                help: session.slotHelp(slot),
                identifier: slotButtonID(slot)
            ) {
                if session.actionBarEditing == false {
                    session.chooseSlot(slot)
                }
            }
        }
    }

    @ViewBuilder
    private var floatingChip: some View {
        if let id = draggingID,
           let slot = session.barSlots(organizing: true).first(where: { $0.id == id })
        {
            slotChip(slot)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Palette.panel)
                )
                .scaleEffect(reduceMotion ? 1 : 1.04)
                .shadow(
                    color: Color.black.opacity(reduceMotion ? 0 : 0.16),
                    radius: reduceMotion ? 0 : 12,
                    y: reduceMotion ? 0 : 5
                )
                .offset(x: floatingX, y: reduceMotion ? 0 : -2)
                .allowsHitTesting(false)
        }
    }

    private func dragGesture(for id: String) -> some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .named("action-bar"))
            .onChanged { value in
                if draggingID == nil {
                    let order = session.barSlots(organizing: true).map(\.id)
                    dragOrder = order
                    previewIDs = order
                    startFrames = chipFrames
                    grabOffset = value.startLocation.x - (chipFrames[id]?.minX ?? 0)
                    draggingID = id
                    session.beginActionDrag(id: id)
                    NSCursor.closedHand.set()
                }
                dragLocation = value.location
                updatePreview()
            }
            .onEnded { _ in
                commitDrag()
            }
    }

    private func updatePreview() {
        guard let draggingID else { return }
        let sizes = startFrames.mapValues(\.width)
        let width = sizes[draggingID] ?? 0
        let origin = startFrames[dragOrder.first ?? ""]?.minX ?? 0
        let center = floatingX + width / 2 - origin
        let insert = ActionBarReorder.insertIndex(
            dragging: draggingID,
            center: center,
            order: dragOrder,
            sizes: sizes
        )
        let preview = ActionBarReorder.previewOrder(dragging: draggingID, insert: insert, order: dragOrder)
        if preview != previewIDs {
            previewIDs = preview
        }
    }

    private func commitDrag() {
        if previewIDs.isEmpty == false {
            session.applyActionOrder(previewIDs)
        }
        session.endActionDrag()
        draggingID = nil
        dragLocation = .zero
        grabOffset = 0
        dragOrder = []
        previewIDs = []
        startFrames = [:]
        NSCursor.arrow.set()
    }

    private var floatingX: CGFloat {
        dragLocation.x - grabOffset
    }

    private func neighborOffset(_ id: String) -> CGFloat {
        ActionBarReorder.offset(
            id: id,
            dragging: draggingID,
            start: dragOrder,
            preview: previewIDs,
            sizes: startFrames.mapValues(\.width)
        )
    }

    private func slotTitle(_ slot: ActionSlot) -> String {
        switch slot {
        case .recipe(let recipe):
            switch recipe {
            case .extract: return Copy.t("提取", "Extract")
            case .toMarkdown: return Copy.t("转 MD", "To MD")
            default: return Copy.recipeShort(recipe)
            }
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

    private func slotTone(_ slot: ActionSlot) -> Palette.IconTone {
        switch slot {
        case .recipe(let recipe): return RecipeGlyph.tone(recipe)
        case .shortcut: return .ochre
        }
    }

    private func recipeButton(
        title: String,
        symbol: String,
        tone: Palette.IconTone = .slate,
        enabled: Bool,
        selected: Bool,
        help: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(enabled ? tone.ink : Palette.faint)
                Text(title)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .buttonStyle(ActionButtonStyle(selected: selected))
        .disabled(!enabled)
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
                    }
                    .buttonStyle(TagButtonStyle(selected: on))
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
    static func tone(_ recipe: RecipeID) -> Palette.IconTone {
        switch recipe {
        case .summarize, .imageText: return .slate
        case .pdfText, .redact: return .clay
        case .extract, .translate: return .blue
        case .toMarkdown: return .plum
        case .brief: return .ochre
        case .shortcut: return .ochre
        }
    }

    static func symbol(_ id: RecipeID) -> String {
        switch id {
        case .summarize: return "text.alignleft"
        case .extract: return "curlybraces"
        case .imageText: return "text.viewfinder"
        case .pdfText: return "text.viewfinder"
        case .translate: return "globe"
        case .redact: return "shield"
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
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 8) {
            row(Copy.t("读取", "Read"), Copy.t("\(count) 份材料的副本", "Copies of \(count) materials"))
            row(Copy.t("写入", "Write"), write)
            row(Copy.t("网络", "Network"), network)
            row(Copy.t("隔离", "Isolation"), isolation)
        }
        .padding(14)
        .background(Palette.panel2, in: RoundedRectangle(cornerRadius: 12))
    }

    private func row(_ key: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(key)
                .frame(width: 34, alignment: .leading)
                .foregroundStyle(Palette.muted)
            Text(value)
                .foregroundStyle(Palette.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 12))
    }
}
