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
        ColumnHead(title: Copy.t("文件", "Files")) {
            HStack(spacing: 6) {
                if session.items.isEmpty == false {
                    Button {
                        session.setMultiSelect(!session.multiSelect)
                    } label: {
                        Label(
                            session.multiSelect ? Copy.t("完成", "Done") : Copy.t("多选", "Select"),
                            systemImage: session.multiSelect ? "checkmark.circle.fill" : "checkmark.circle"
                        )
                        .font(.system(size: 12, weight: session.multiSelect ? .semibold : .medium))
                        .foregroundStyle(Palette.text)
                        .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.plain)
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
                    .frame(width: 22, height: 22)
                    .accessibilityIdentifier("shelf-paste")
                Button(action: { session.pickFilesToAdmit() }) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.text)
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Copy.t("添加文件", "Add files"))
                .accessibilityHint(Copy.t("选择文件或文件夹放到架子上", "Choose files or folders to put on the shelf"))
                .accessibilityIdentifier("shelf-add")
            }
        }
    }

    private var listSection: some View {
        ZStack {
            if session.items.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(Copy.t("把材料放在这里", "Drop something here"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Palette.muted)
                    Text(Copy.t("文件、图片、文字或链接。拖入，或点 +。", "Files, images, text, or links. Drop here, or add with +."))
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.faint)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
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
                                onHoverPreview: { on, rect in
                                    if on { session.showHover(item: item, screenRect: rect) }
                                    else { session.hideHover(of: item.id) }
                                },
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
