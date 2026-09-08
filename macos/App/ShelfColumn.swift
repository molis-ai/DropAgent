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
            HStack {
                Button { session.pasteFromClipboard() } label: {
                    Label(Copy.t("粘贴", "Paste"), systemImage: "doc.on.clipboard")
                }
                .buttonStyle(QuietButtonStyle())
                .fixedSize()
                .help(session.prefs.pasteHotKey.label)
                .accessibilityIdentifier("shelf-paste")
                Spacer(minLength: 0)
                Text(Copy.t("\(session.items.count) 项", "\(session.items.count) items"))
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(Palette.faint)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 8)
        }
        .frame(width: session.fillsShelf ? nil : session.shelfWidth)
        .frame(maxWidth: session.fillsShelf ? .infinity : nil)
        .frame(maxHeight: .infinity)
        .background(Palette.panel2)
        .background(AccessibleID(identifier: "shelf-column").frame(width: 0, height: 0).allowsHitTesting(false))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Copy.t("输入", "Input"))
        .accessibilityIdentifier("shelf-column")
        .onDrop(of: IncomingDrop.contentTypes, delegate: AdmitDropDelegate(targeted: $listHot) { providers in
            session.admitDrop(providers: providers)
        })
    }

    private var columnHead: some View {
        ColumnHead(title: Copy.t("输入", "Input")) {
            HStack(spacing: 6) {
                if session.items.isEmpty == false {
                    Button {
                        session.setMultiSelect(!session.multiSelect)
                    } label: {
                        Text(session.multiSelect ? Copy.t("完成", "Done") : Copy.t("多选", "Select"))
                            .font(.system(size: 11, weight: session.multiSelect ? .semibold : .medium))
                            .foregroundStyle(Palette.text)
                            .padding(.horizontal, 8)
                            .frame(height: 22)
                            .background(session.multiSelect ? Palette.panelPress : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(session.multiSelect ? Copy.t("完成多选", "Done selecting") : Copy.t("多选", "Select"))
                    .accessibilityHint(Copy.t("点行前圆圈加减选择，也可以 Command 点", "Use the circles, or Command-click"))
                    .accessibilityIdentifier("multi-select")
                }
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
                VStack(spacing: 10) {
                    Image(systemName: "tray.and.arrow.down")
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(Palette.text)
                        .accessibilityHidden(true)
                    Text(Copy.t("把材料放在这里", "Drop something here"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Palette.muted)
                    Text(Copy.t("文件、图片、文字或链接\n拖入，或点 + 选择文件", "Files, images, text, or links\nDrop here, or add with +"))
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.faint)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(spacing: 0) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 5) {
                                ForEach(session.items, id: \.id) { item in
                                    ItemRowView(
                                        item: item,
                                        selected: session.paneFocus == .input && session.shelf.selection.contains(item.id),
                                        multiSelect: session.multiSelect
                                    ) { command in
                                        session.toggleSelect(id: item.id, command: command)
                                    } onHide: {
                                        session.hideItem(item.id)
                                    } onDelete: {
                                        session.deleteItem(item.id)
                                    }
                                    .id(item.id)
                                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.bottom, 8)
                            .animation(reduceMotion ? nil : Palette.motion, value: session.items.map(\.id))
                        }
                        .onChange(of: session.selectedItems.map(\.id)) { _, ids in
                            guard !session.multiSelect, ids.count == 1, let id = ids.first else { return }
                            withAnimation(reduceMotion ? nil : Palette.motion) { proxy.scrollTo(id) }
                        }
                    }
                    Color.clear
                        .frame(width: LivePanelChrome.scrollGutter)
                        .allowsHitTesting(false)
                }
            }
            DropZoneOverlay(title: Copy.t("加入架子", "Add to shelf"), offered: session.systemDragActive, hot: listHot, reduceMotion: reduceMotion)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Copy.t("架子", "Shelf"))
    }
}
