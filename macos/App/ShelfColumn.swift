import DropAgentPasteboard
import DropAgentShelf
import SwiftUI

struct ShelfColumn: View {
    @ObservedObject var session: AppSession
    @State private var listHot = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            columnHead
            listSection
            if let item = session.stagedItem,
               session.paneFocus == .result || !session.selectedItems.contains(where: { $0.status == .confirm || $0.status == .running }) {
                ContentStage(item: item, session: session)
            }
            if session.shortcutDraft != nil, session.settingsOpen == false {
                ShortcutComposer(session: session)
            }
            if session.showsActionBar {
                RecipeChooser(session: session)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Palette.panel2)
        .background(AccessibleID(identifier: "shelf-column").frame(width: 0, height: 0).allowsHitTesting(false))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Copy.t("文件", "Files"))
        .accessibilityIdentifier("shelf-column")
        .onDrop(of: IncomingDrop.contentTypes, delegate: AdmitDropDelegate(targeted: $listHot) { providers in
            session.admitDrop(providers: providers)
        })
    }

    private var columnHead: some View {
        ColumnHead(title: Copy.t("材料", "Materials")) {
            HStack(spacing: 6) {
                if session.items.isEmpty == false {
                    Button {
                        session.setMultiSelect(!session.multiSelect)
                    } label: {
                        Label(
                            session.multiSelect ? Copy.t("完成", "Done") : Copy.t("多选", "Select"),
                            systemImage: session.multiSelect ? "checkmark.circle.fill" : "checkmark.circle"
                        )
                    }
                    .buttonStyle(QuietButtonStyle(selected: session.multiSelect))
                    .accessibilityLabel(session.multiSelect ? Copy.t("完成多选", "Done selecting") : Copy.t("多选", "Select"))
                    .accessibilityHint(Copy.t("点行前圆圈加减选择，也可以 Command 点", "Use the circles, or Command-click"))
                    .accessibilityIdentifier("multi-select")
                }
                Spacer(minLength: 0)
                if session.selectedItems.isEmpty == false {
                    Text(Copy.t("已选 \(session.selectedItems.count)", "\(session.selectedItems.count) selected"))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Palette.muted)
                }
                ClipHistoryButton(session: session)
                    .accessibilityIdentifier("shelf-paste")
                Button(action: { session.pickFilesToAdmit() }) {
                    Label(Copy.t("添加文件", "Add files"), systemImage: "plus")
                }
                .buttonStyle(QuietButtonStyle())
                .accessibilityLabel(Copy.t("添加文件", "Add files"))
                .accessibilityHint(Copy.t("选择文件或文件夹放到架子上", "Choose files or folders to put on the shelf"))
                .accessibilityIdentifier("shelf-add")
            }
        }
    }

    private var listSection: some View {
        ZStack {
            if session.items.isEmpty {
                HStack(spacing: 14) {
                    Image(systemName: "tray.and.arrow.down")
                        .font(.system(size: 26, weight: .light))
                        .foregroundStyle(listHot ? Palette.accent : Palette.muted)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(Copy.t("拖入材料", "Drop files here"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Palette.text)
                        Text(Copy.t("支持文件、图片、文字和链接，也可直接粘贴。", "Files, images, text, and links. You can also paste."))
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.muted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 22)
                .padding(.vertical, 18)
                .background {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Palette.line, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(session.items, id: \.id) { item in
                            FileCard(
                                item: item,
                                selected: session.paneFocus == .input && session.shelf.selection.contains(item.id),
                                dragGroup: session.selectedItems,
                                onSelect: { command in
                                    session.toggleSelect(id: item.id, command: command || session.multiSelect)
                                },
                                onOpen: { session.openItem(item) },
                                onHide: { session.hideItem(item.id) },
                                onDelete: { session.deleteItem(item.id) },
                                onBeginDrag: {
                                    let ids = PasteboardService.exportGroup(
                                        starting: item,
                                        selection: session.selectedItems
                                    ).map(\.id)
                                    session.beginShelfDrag(ids: ids)
                                }
                            )
                            .id(item.id)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 10)
                }
            }
            DropZoneOverlay(title: Copy.t("加入架子", "Add to shelf"), offered: session.systemDragActive, hot: listHot, reduceMotion: reduceMotion)
        }
        .frame(minHeight: LivePanelChrome.fileCardHeight + 16)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Copy.t("架子", "Shelf"))
    }
}
