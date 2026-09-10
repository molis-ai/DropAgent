import DropAgentIngest
import DropAgentShelf
import SwiftUI

struct ContentStage: View {
    let item: Item
    @ObservedObject var session: AppSession

    private var editURL: URL? {
        StageEdit.editableURL(item, inboxRoot: DropAgentPaths.inbox, jobsRoot: DropAgentPaths.jobs)
    }

    private var folderRoot: URL {
        item.parts.first?.url ?? item.sourceURL
    }

    var body: some View {
        Group {
            if item.kind == .folder {
                FolderStage(root: folderRoot)
            } else if let url = editURL, session.stageEditing {
                editor(url)
            } else {
                reading
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: LivePanelChrome.previewStageHeight)
        .background(Palette.panel)
        .clipShape(RoundedRectangle(cornerRadius: LivePanelChrome.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: LivePanelChrome.cardRadius, style: .continuous)
                .stroke(Palette.line)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Copy.t("内容 \(item.title)", "Content \(item.title)"))
        .background(AccessibleID(identifier: "content-stage").frame(width: 0, height: 0).allowsHitTesting(false))
        .accessibilityIdentifier("content-stage")
        .onChange(of: item.id) { _, _ in
            session.stopStageEdit()
        }
        .onChange(of: item.status) { _, status in
            if status == .confirm || status == .running {
                session.stopStageEdit()
            }
        }
        .onDisappear { session.stopStageEdit() }
    }

    @ViewBuilder
    private var reading: some View {
        let preview = ScrollView {
            ResultPreview(item: item, expanded: true)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(16)
        }
        if editURL == nil {
            preview.accessibilityIdentifier("content-stage-read")
        } else {
            preview
                .textSelection(.disabled)
                .contentShape(Rectangle())
                .onTapGesture { session.beginStageEdit() }
                .accessibilityHint(Copy.stageReadHint)
                .accessibilityIdentifier("content-stage-read-editable")
        }
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
