import AppKit
import DropAgentShelf
import SwiftUI

struct WorkbenchDetail: View {
    @ObservedObject var session: AppSession

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                if session.paneFocus == .result, let result = session.selectedResult {
                    resultTools(result)
                    if let reason = result.failureReason {
                        HStack {
                            Text(reason).font(.system(size: 12)).foregroundStyle(Palette.warning)
                            Spacer()
                            Button(Copy.t("返回材料重试", "Retry from materials")) { session.reselectResultSources(result) }.buttonStyle(QuietButtonStyle(subtle: true))
                        }.padding(10)
                    }
                    if session.guidedSample != nil && result.status != .failed {
                        HStack {
                            Text(Copy.t("新文件已生成 · 可以复制文件或拖出", "File ready · Copy it or drag it out"))
                            Spacer()
                            Button(Copy.t("完成引导", "Finish guide")) { session.dismissFirstActionHint() }
                                .buttonStyle(QuietButtonStyle(subtle: true)).accessibilityIdentifier("onboard-result-dismiss")
                        }.font(.system(size: 12)).foregroundStyle(Palette.muted).padding(.horizontal, 16).accessibilityIdentifier("onboard-result")
                    }
                }
                preview
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .layoutPriority(1)
                if session.otherOpen || session.canOpenTerminalTab {
                    AIPane(session: session)
                        .frame(height: session.showsFloat ? chatHeight(in: geometry.size.height) : 0)
                        .clipped().opacity(session.showsFloat ? 1 : 0)
                        .allowsHitTesting(session.showsFloat).accessibilityHidden(!session.showsFloat)
                        .background(AccessibleID(identifier: "ai-pane").frame(width: 0, height: 0))
                }
                if showsTaskDrawer {
                    Divider().overlay(Palette.line)
                    ScrollView {
                        if session.shortcutDraft != nil { ShortcutComposer(session: session) }
                        else { WorkPane(session: session) }
                    }
                    .frame(maxHeight: min(310, geometry.size.height * 0.48))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("task-drawer")
                }
                Divider().overlay(Palette.line)
                RecipeChooser(session: session)
                    .padding(.horizontal, 13).padding(.vertical, 8)
                    .background(Palette.panel)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("workbench-detail")
    }

    private var showsTaskDrawer: Bool {
        session.shortcutDraft != nil || session.isCapturing || session.errorText != nil
            || session.paneFocus == .input && session.selectedItems.contains { $0.status == .confirm || $0.status == .running || $0.status == .failed }
    }

    private func chatHeight(in total: CGFloat) -> CGFloat {
        showsTaskDrawer ? min(160, total * 0.28) : min(280, total * 0.48)
    }

    @ViewBuilder private var preview: some View {
        if session.paneFocus == .clipboard {
            ClipboardStage(session: session)
        } else if session.paneFocus == .result && session.comparingResult {
            GeometryReader { geometry in
                if geometry.size.width >= 640 {
                    HStack(spacing: 0) {
                        sourceStage.frame(width: (geometry.size.width - 1) / 2)
                        Divider().overlay(Palette.line)
                        if let item = session.stagedItem { ContentStage(item: item, session: session).frame(width: (geometry.size.width - 1) / 2) }
                    }
                } else {
                    VStack(spacing: 0) {
                        sourceStage.frame(height: geometry.size.height * 0.44)
                        Divider().overlay(Palette.line)
                        if let item = session.stagedItem { ContentStage(item: item, session: session) }
                    }
                }
            }
            .accessibilityIdentifier("result-comparison")
        } else if let item = session.stagedItem {
            ContentStage(item: item, session: session)
        } else if session.showsOnboarding {
            ScrollView { OnboardingView(session: session).padding(.top, 30) }
        } else {
            VStack(spacing: 12) {
                Image(systemName: "doc.text.magnifyingglass").font(.system(size: 32, weight: .ultraLight)).foregroundStyle(Palette.muted)
                Text(Copy.t("选择一份材料", "Select a file")).font(.system(size: 17, weight: .medium))
                Text(Copy.t("在这里预览，使用下方指令处理副本。", "Preview it here, then run an action on its copy below."))
                    .font(.system(size: 12)).foregroundStyle(Palette.muted)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder private var sourceStage: some View {
        VStack(spacing: 0) {
            if session.comparisonSources.count > 1 {
                Picker(Copy.t("原文", "Source"), selection: Binding(get: { session.comparisonSource?.id }, set: { session.comparisonSourceID = $0 })) {
                    ForEach(session.comparisonSources, id: \.id) { Text($0.title).tag(Optional($0.id)) }
                }.font(.system(size: 11)).padding(10)
            }
            if let item = session.comparisonSource {
                ContentStage(item: item, session: session, readOnly: true)
            } else {
                Text(Copy.t("原材料已不在工作区，无法对照。", "The source material is no longer in this workspace."))
                    .font(.system(size: 12)).foregroundStyle(Palette.muted).padding(20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func resultTools(_ result: ResultRecord) -> some View {
        HStack(spacing: 6) {
            Button { session.toggleComparison() } label: {
                Label(Copy.t("对照原文", "Compare source"), systemImage: "rectangle.split.2x1")
            }.buttonStyle(QuietButtonStyle(selected: session.comparingResult))
            .accessibilityIdentifier("compare-result")
            .background(AccessibleID(identifier: "compare-result").frame(width: 0, height: 0))
            Spacer(minLength: 0)
            Button { session.copySelected() } label: { Label(session.copiedID?.rawValue == result.id.rawValue ? Copy.t("已复制", "Copied") : Copy.t("复制文件", "Copy file"), systemImage: "doc.on.doc") }
                .accessibilityIdentifier("take-copy")
            Button { session.importSelectedResults() } label: { Label(Copy.t("用作材料", "Use as input"), systemImage: "tray.and.arrow.down") }
                .accessibilityIdentifier("import-result")
                .background(AccessibleID(identifier: "import-result").frame(width: 0, height: 0))
        }
        .buttonStyle(QuietButtonStyle()).disabled(result.output == nil)
        .padding(.horizontal, 10).frame(height: 42)
    }
}

struct ClipboardStage: View {
    @ObservedObject var session: AppSession
    @State private var selectedFile: String?

    var body: some View {
        VStack(spacing: 0) {
            if let record = session.selectedClipboard {
                HStack(spacing: 8) {
                    Image(systemName: "clipboard").foregroundStyle(Palette.IconTone.ochre.ink)
                    Text(record.title).lineLimit(1)
                    Spacer(minLength: 0)
                    Button(Copy.t("复制", "Copy")) { session.makeClipCurrent(record.id) }
                        .disabled(session.clipboardPayload(for: record) == nil).accessibilityIdentifier("clip-copy")
                    Button(session.clipSelection.count > 1 ? Copy.t("加入 \(session.clipSelection.count) 条材料", "Add \(session.clipSelection.count) clips") : Copy.t("加入材料", "Add to materials")) { session.admitSelectedClips() }
                        .disabled(session.clipRecords.filter { session.clipSelection.contains($0.id) }.allSatisfy { session.clipboardPayload(for: $0) == nil })
                        .accessibilityIdentifier("clip-admit")
                }.buttonStyle(QuietButtonStyle()).font(.system(size: 12)).padding(.horizontal, 14).frame(height: 44)
                Divider().overlay(Palette.line)
                if session.clipboardPayload(for: record) == nil {
                    Text(Copy.t("文件或图片已丢失，可以删除这条记录后重新复制。", "The file or image is missing. Delete this clip and copy it again."))
                        .font(.system(size: 13)).foregroundStyle(Palette.warning).padding(24).frame(maxHeight: .infinity)
                } else if record.kind == .files, let first = record.filePaths.first {
                    let path = selectedFile.flatMap { record.filePaths.contains($0) ? $0 : nil } ?? first
                    VStack(spacing: 0) {
                        if record.filePaths.count > 1 {
                            Picker(Copy.t("文件", "File"), selection: Binding(get: { path }, set: { selectedFile = $0 })) {
                                ForEach(record.filePaths, id: \.self) { Text(URL(fileURLWithPath: $0).lastPathComponent).tag($0) }
                            }.padding(12)
                        }
                        FolderFileStage(root: URL(fileURLWithPath: path).deletingLastPathComponent(), selected: URL(fileURLWithPath: path))
                    }
                } else {
                    ScrollView {
                        Group {
                            if let text = record.text {
                                Text(text).font(.system(size: 14)).textSelection(.enabled).lineSpacing(6)
                            } else if record.kind == .image, let data = session.clipHistory.imageData(for: record.id), let image = NSImage(data: data) {
                                Image(nsImage: image).resizable().scaledToFit()
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 42).padding(.vertical, 35)
                    }
                }
                Text(Copy.t("仅预览历史记录 · 加入材料后可运行指令", "Previewing a saved clip · Add it to materials to run actions"))
                    .font(.system(size: 11)).foregroundStyle(Palette.faint).padding(12)
            } else {
                Text(Copy.t("选择一条剪贴板记录", "Select a clipboard entry"))
                    .font(.system(size: 14)).foregroundStyle(Palette.muted).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }.foregroundStyle(Palette.text).accessibilityIdentifier("clipboard-stage")
    }
}
