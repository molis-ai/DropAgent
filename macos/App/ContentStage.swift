import DropAgentIngest
import DropAgentShelf
import SwiftUI

struct ContentStage: View {
    let item: Item
    @ObservedObject var session: AppSession
    var readOnly = false

    private var editURL: URL? {
        readOnly ? nil : StageEdit.editableURL(item, inboxRoot: DropAgentPaths.inbox, jobsRoot: DropAgentPaths.jobs)
    }

    private var folderRoot: URL {
        item.parts.first?.url ?? item.sourceURL
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(item.title)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if !readOnly && session.paneFocus == .input && session.selectedItems.count > 1 {
                    Text(Copy.t("等 \(session.selectedItems.count) 份材料", "of \(session.selectedItems.count) selected"))
                        .foregroundStyle(Palette.muted).lineLimit(1)
                }
                Spacer(minLength: 8)
                Text("\(readOnly ? Copy.t("原文", "Source") : session.paneFocus == .result ? Copy.t("结果", "Result") : Copy.t("材料", "Material")) · \(item.displayTag)")
                    .font(.system(size: 11)).foregroundStyle(Palette.muted).lineLimit(1)
                if editURL != nil {
                    Button {
                        if session.stageEditing { session.stopStageEdit() } else { session.beginStageEdit() }
                    } label: {
                        Image(systemName: session.stageEditing ? "checkmark" : "square.and.pencil")
                    }
                    .buttonStyle(IconButtonStyle(size: 24))
                    .disabled(item.status == .confirm || item.status == .running)
                    .help(session.stageEditing ? Copy.t("完成编辑", "Done editing") : Copy.t("编辑副本", "Edit copy"))
                    .accessibilityLabel(session.stageEditing ? Copy.t("完成编辑", "Done editing") : Copy.t("编辑副本", "Edit copy"))
                    .accessibilityIdentifier("stage-edit")
                }
            }
            .font(.system(size: 12))
            .foregroundStyle(Palette.text)
            .padding(.horizontal, 20)
            .frame(height: 41)
            Divider().overlay(Palette.line)
            if item.kind == .folder {
                FolderFileStage(root: folderRoot, selected: readOnly ? nil : session.folderPreviewURL)
            } else if item.kind == .pdf {
                let url = item.parts.first?.url ?? item.sourceURL
                if FileManager.default.fileExists(atPath: url.path) {
                    PDFContentView(url: url)
                } else {
                    Text(Copy.t("这份 PDF 已经不在了，请重新添加。", "This PDF is no longer available. Add it again."))
                        .font(.system(size: 12)).foregroundStyle(Palette.warning).padding(20)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else if let url = editURL, session.stageEditing {
                editor(url)
            } else {
                reading
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.panel)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Copy.t("内容 \(item.title)", "Content \(item.title)"))
        .background(AccessibleID(identifier: "content-stage").frame(width: 0, height: 0).allowsHitTesting(false))
        .accessibilityIdentifier("content-stage")
        .onChange(of: item.id) { _, _ in
            if !readOnly { session.stopStageEdit() }
        }
        .onChange(of: item.status) { _, status in
            if !readOnly && (status == .confirm || status == .running) {
                session.stopStageEdit()
            }
        }
        .onDisappear { if !readOnly { session.stopStageEdit() } }
    }

    @ViewBuilder
    private var reading: some View {
        let preview = ScrollView {
            ResultPreview(item: item, expanded: true)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.horizontal, session.comparingResult ? 22 : 42)
                .padding(.top, session.comparingResult ? 24 : 35)
                .padding(.bottom, 32)
        }
        preview.accessibilityIdentifier("content-stage-read")
    }

    private func editor(_ url: URL) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(Copy.stageEditHint)
                .font(.system(size: 11))
                .foregroundStyle(Palette.faint)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 6)
            if item.kind == .web {
                SourceLinkText(url: item.sourceURL, size: 12)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
            StageEditor(
                itemID: item.id,
                url: url,
                inboxRoot: DropAgentPaths.inbox,
                jobsRoot: DropAgentPaths.jobs,
                usesCodeFont: usesCodeFont(url),
                onCancel: { session.stopStageEdit() }
            )
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
    }

    private func usesCodeFont(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ext != "md" && ext != "txt" && ext != "markdown"
    }
}
