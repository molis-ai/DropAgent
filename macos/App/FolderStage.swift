import DropAgentIngest
import DropAgentShelf
import SwiftUI

struct FolderStage: View {
    let root: URL
    @State private var selected: URL?
    @State private var expanded: Set<String> = []

    var body: some View {
        HStack(spacing: 0) {
            tree
                .frame(width: 220)
            Rectangle()
                .fill(Palette.line)
                .frame(width: 1)
            preview
                .frame(maxWidth: .infinity)
        }
        .onAppear { openRoot() }
        .onChange(of: root.path) { _, _ in
            selected = nil
            expanded = []
            openRoot()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("folder-stage")
    }

    private var tree: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                FolderTreeRows(
                    url: root,
                    root: root,
                    depth: 0,
                    selected: $selected,
                    expanded: $expanded
                )
            }
            .padding(.vertical, 8)
        }
        .background(Palette.panel2)
        .background(AccessibleID(identifier: "folder-tree").frame(width: 0, height: 0).allowsHitTesting(false))
        .accessibilityIdentifier("folder-tree")
    }

    @ViewBuilder
    private var preview: some View {
        let target = selected ?? FolderListing.firstFile(in: root, stayingInside: root)
        ScrollView {
            Group {
                if let target {
                    filePreview(target)
                } else {
                    Text(Copy.t("这个文件夹是空的，或打不开。", "This folder is empty, or it cannot be opened."))
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.faint)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(14)
        }
        .background(AccessibleID(identifier: "folder-file-preview").frame(width: 0, height: 0).allowsHitTesting(false))
        .accessibilityIdentifier("folder-file-preview")
    }

    @ViewBuilder
    private func filePreview(_ url: URL) -> some View {
        switch inspect(url) {
        case .missing:
            Text(Copy.t("这个文件已经不在了。", "This file is no longer here."))
                .font(.system(size: 11))
                .foregroundStyle(Palette.warning)
        case .directory:
            VStack(alignment: .leading, spacing: 6) {
                Text(url.lastPathComponent)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.text)
                Text(Copy.t("文件夹。点左边的文件看内容。", "Folder. Select a file on the left to preview it."))
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.faint)
            }
        case .file:
            ResultPreview(item: previewItem(url), expanded: true)
        }
    }

    private enum Inspect {
        case missing
        case directory
        case file
    }

    private func inspect(_ url: URL) -> Inspect {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else {
            return .missing
        }
        return isDir.boolValue ? .directory : .file
    }

    private func previewItem(_ url: URL) -> Item {
        let kind = IngestService.kind(for: url, isDirectory: false)
        return Item(
            kind: kind,
            title: url.lastPathComponent,
            sourceURL: url,
            parts: [ItemPart(name: url.lastPathComponent, url: url)]
        )
    }

    private func openRoot() {
        expanded.insert(root.path)
        if selected == nil {
            selected = FolderListing.firstFile(in: root, stayingInside: root)
        }
    }
}

struct FolderTreeRows: View {
    let url: URL
    let root: URL
    let depth: Int
    @Binding var selected: URL?
    @Binding var expanded: Set<String>

    var body: some View {
        let kids = FolderListing.children(of: url, stayingInside: root)
        let extra = FolderListing.extraCount(of: url, stayingInside: root)
        ForEach(kids) { entry in
            row(entry)
            if entry.isDirectory,
               expanded.contains(entry.url.path),
               depth + 1 < FolderListing.maxDepth
            {
                FolderTreeRows(
                    url: entry.url,
                    root: root,
                    depth: depth + 1,
                    selected: $selected,
                    expanded: $expanded
                )
            }
        }
        if extra > 0 {
            Text(Copy.t("还有 \(extra) 项未列出。", "\(extra) more items not listed."))
                .font(.system(size: 11))
                .foregroundStyle(Palette.faint)
                .padding(.leading, 8 + CGFloat(depth + 1) * 12)
                .padding(.vertical, 4)
        }
    }

    private func row(_ entry: FolderListing.Entry) -> some View {
        let on = selected?.path == entry.url.path
        let open = expanded.contains(entry.url.path)
        return Button {
            selected = entry.url
            if entry.isDirectory {
                if open {
                    expanded.remove(entry.url.path)
                } else {
                    expanded.insert(entry.url.path)
                }
            }
        } label: {
            HStack(spacing: 6) {
                if entry.isDirectory {
                    Image(systemName: open ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(Palette.faint)
                        .frame(width: 10)
                } else {
                    Color.clear.frame(width: 10)
                }
                Image(systemName: glyph(entry))
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.muted)
                    .frame(width: 14)
                Text(entry.name)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.text)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 0)
            }
            .padding(.leading, 8 + CGFloat(depth) * 12)
            .padding(.trailing, 8)
            .frame(height: 24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(on ? Palette.panelHover : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(entry.name)
        .accessibilityIdentifier("folder-tree-\(entry.name)")
        .accessibilityAddTraits(on ? .isSelected : [])
        .background(AccessibleID(identifier: "folder-tree-\(entry.name)").frame(width: 0, height: 0).allowsHitTesting(false))
    }

    private func glyph(_ entry: FolderListing.Entry) -> String {
        if entry.isDirectory { return "folder" }
        let kind = IngestService.kind(for: entry.url, isDirectory: false)
        let tag = Item(
            kind: kind,
            title: entry.name,
            sourceURL: entry.url,
            parts: [ItemPart(name: entry.name, url: entry.url)]
        ).displayTag
        return FileKindGlyph.symbol(kind: kind, tag: tag)
    }
}

struct FolderFileStage: View {
    let root: URL
    let selected: URL?

    var body: some View {
        let target = selected ?? FolderListing.firstFile(in: root, stayingInside: root)
        Group {
            if let target, FileManager.default.fileExists(atPath: target.path) {
                let isDirectory = (try? target.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
                if isDirectory {
                    Text(Copy.t("选择左侧文件查看内容。", "Select a file on the left to preview it.")).foregroundStyle(Palette.muted)
                } else if target.pathExtension.lowercased() == "pdf" {
                    PDFContentView(url: target)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            Text(target.lastPathComponent).font(.system(size: 12, weight: .medium)).foregroundStyle(Palette.muted)
                            ResultPreview(item: Item(kind: IngestService.kind(for: target, isDirectory: false), title: target.lastPathComponent,
                                                     sourceURL: target, parts: [ItemPart(name: target.lastPathComponent, url: target)]), expanded: true)
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 42).padding(.vertical, 35)
                    }
                }
            } else {
                Text(Copy.t("文件夹为空，或选中的文件已经不在了。", "This folder is empty, or the selected file is no longer available.")).foregroundStyle(Palette.muted).padding(20)
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity).accessibilityIdentifier("folder-file-preview")
    }
}
