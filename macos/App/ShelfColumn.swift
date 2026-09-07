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
        }
        .frame(width: session.shelfWidth)
        .frame(maxHeight: .infinity)
        .background(Palette.panel2)
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
                    Text(Copy.t("拖到这里，或用 + / 搜索加入", "Drop here, or add with + / search"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Palette.muted)
                    Text(HotKeyCopy.emptyHint(hasAgent: session.hasAgent, tuiTitle: session.tuiTitle, captureOK: session.hotKeyCaptureOK))
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.faint)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(spacing: 0) {
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(session.items, id: \.id) { item in
                                ItemRowView(
                                    item: item,
                                    selected: session.shelf.selection.contains(item.id),
                                    multiSelect: session.multiSelect
                                ) { command in
                                    session.toggleSelect(id: item.id, command: command)
                                } onHide: {
                                    session.hideItem(item.id)
                                } onDelete: {
                                    session.deleteItem(item.id)
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.bottom, 8)
                        .animation(reduceMotion ? nil : Palette.motion, value: session.items.map(\.id))
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
