import AppKit
import DropAgentIngest
import DropAgentShelf
import SwiftUI

struct ResultPreview: View {
    let item: Item

    @ViewBuilder
    var body: some View {
        if item.kind == .web {
            webMaterials
        }
        if item.kind == .image {
            imagePreview
        }
        if item.kind == .url {
            urlMaterials
        }
        if item.kind == .clip {
            stagedTextView
        }
        if item.kind == .markdown && item.output == nil, let body = stagedText {
            switch StagedPreview.mode(title: item.title, body: body) {
            case .json:
                ResultBodyView.json(ResultJSON.pretty(body) ?? body)
            case .markdown:
                ResultBodyView.markdown(body, baseDirectory: stagedDirectory)
            case .code:
                ResultBodyView.code(body)
            }
        }
        if item.kind == .folder {
            folderListing
        }
        if item.kind == .pdf && item.output == nil && item.status != .done {
            Text(Copy.t("这是 PDF，拖出到其他应用打开。", "This is a PDF. Drag it out to open elsewhere."))
                .font(.system(size: 11))
                .foregroundStyle(Palette.faint)
        }
        if item.kind == .file && item.output == nil && item.status != .done {
            if PanelInspect.htmlURL(item) != nil {
                htmlReadable
            } else {
                Text(Copy.t("这是文件，拖出到其他应用打开。", "This is a file. Drag it out to open elsewhere."))
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.faint)
            }
        }
        if let output = item.output, let body = try? String(contentsOf: output, encoding: .utf8) {
            resultDocument(body, output: output)
        } else if item.status == .sent {
            Text(Copy.t("材料已送进终端。在「终端」里继续说。", "This material is in the terminal. Keep talking there."))
                .font(.system(size: 11))
                .foregroundStyle(Palette.faint)
        }
    }

    @ViewBuilder
    private func resultDocument(_ body: String, output: URL) -> some View {
        let ext = output.pathExtension.lowercased()
        if ext == "json" {
            ResultBodyView.json(ResultJSON.pretty(body) ?? body)
        } else if ReadableHTML.isHTMLFile(output) {
            htmlExtracted(body, baseURL: output)
        } else {
            ResultBodyView.markdown(body, baseDirectory: output.deletingLastPathComponent())
        }
    }

    @ViewBuilder
    private var htmlReadable: some View {
        if let url = PanelInspect.htmlURL(item), let raw = try? String(contentsOf: url, encoding: .utf8) {
            htmlExtracted(raw, baseURL: url)
        } else {
            Text(Copy.t("这是文件，拖出到其他应用打开。", "This is a file. Drag it out to open elsewhere."))
                .font(.system(size: 11))
                .foregroundStyle(Palette.faint)
        }
    }

    @ViewBuilder
    private func htmlExtracted(_ raw: String, baseURL: URL) -> some View {
        let markdown = ReadableHTML.markdown(from: raw, baseURL: baseURL)
        if markdown.isEmpty {
            Text(Copy.t("抽不出正文。可以拖出到浏览器打开。", "No readable text. Drag it out to open in a browser."))
                .font(.system(size: 11))
                .foregroundStyle(Palette.faint)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text(Copy.htmlExtractedHint)
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.faint)
                ResultBodyView.markdown(markdown, baseDirectory: baseURL.deletingLastPathComponent())
            }
        }
    }

    private var stagedDirectory: URL? {
        item.parts.first?.url.deletingLastPathComponent()
    }

    @ViewBuilder
    private var imagePreview: some View {
        if let url = imageURL, let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 220)
                .frame(maxWidth: .infinity, alignment: .leading)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Palette.line))
                .accessibilityLabel(Copy.t("图片 \(item.title)", "Image \(item.title)"))
                .padding(.bottom, 4)
        } else {
            Text(Copy.t("这张图打不开。可以拖出到其他应用查看。", "This image cannot be opened. Drag it out to view elsewhere."))
                .font(.system(size: 11))
                .foregroundStyle(Palette.warning)
                .padding(.bottom, 4)
        }
    }

    private var imageURL: URL? {
        let imagePart = item.parts.first { part in
            let ext = part.name.lowercased()
            return ext.hasSuffix(".png") || ext.hasSuffix(".jpg") || ext.hasSuffix(".jpeg")
                || ext.hasSuffix(".gif") || ext.hasSuffix(".webp") || ext.hasSuffix(".tif")
                || ext.hasSuffix(".tiff") || ext.hasSuffix(".heic")
        }
        if let imagePart { return imagePart.url }
        if item.sourceURL.isFileURL { return item.sourceURL }
        return nil
    }

    @ViewBuilder
    private var urlMaterials: some View {
        VStack(alignment: .leading, spacing: 6) {
            SourceLinkText(url: item.sourceURL, size: 12)
            Text(Copy.t(
                "这是链接，不会自动抓正文。要网页材料请用 \(HotKeyCenter.shared.captureChord.label)。",
                "This is a link; the page body is not fetched. Capture a page with \(HotKeyCenter.shared.captureChord.label)."
            ))
                .font(.system(size: 11))
                .foregroundStyle(Palette.faint)
        }
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var stagedTextView: some View {
        if let body = stagedText {
            Text(body)
                .font(.system(size: 12))
                .foregroundStyle(Palette.text)
                .textSelection(.enabled)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 4)
        }
    }

    private var stagedText: String? {
        let part = item.parts.first { part in
            let lower = part.name.lowercased()
            return lower.hasSuffix(".txt") || lower.hasSuffix(".md") || lower.hasSuffix(".markdown")
                || lower.hasSuffix(".json") || lower.hasSuffix(".swift") || lower.hasSuffix(".py")
                || lower.hasSuffix(".yaml") || lower.hasSuffix(".yml") || lower.hasSuffix(".xml")
                || lower.hasSuffix(".css")
        } ?? item.parts.first
        guard let part, let body = try? String(contentsOf: part.url, encoding: .utf8) else { return nil }
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    @ViewBuilder
    private var folderListing: some View {
        let names = folderNames
        if names.isEmpty {
            Text(Copy.t("这个文件夹是空的，或打不开。", "This folder is empty, or it cannot be opened."))
                .font(.system(size: 11))
                .foregroundStyle(Palette.faint)
                .padding(.bottom, 4)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(names, id: \.self) { name in
                    Text(name)
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.muted)
                        .lineLimit(1)
                }
                if folderCount > names.count {
                    Text(Copy.t(
                        "还有 \(folderCount - names.count) 项未列出。",
                        "\(folderCount - names.count) more items not listed."
                    ))
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.faint)
                }
            }
            .padding(.bottom, 4)
        }
    }

    private var folderURL: URL {
        item.parts.first?.url ?? item.sourceURL
    }

    private var folderCount: Int {
        let kids = (try? FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)) ?? []
        return kids.filter { $0.lastPathComponent.hasPrefix(".") == false }.count
    }

    private var folderNames: [String] {
        let kids = (try? FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)) ?? []
        return kids
            .map(\.lastPathComponent)
            .filter { $0.hasPrefix(".") == false }
            .sorted()
            .prefix(12)
            .map { $0 }
    }

    @ViewBuilder
    private var webMaterials: some View {
        VStack(alignment: .leading, spacing: 6) {
            SourceLinkText(url: item.sourceURL, size: 12)
            if item.event.isEmpty == false {
                Text(item.event)
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.warning)
            }
            if let png = item.parts.first(where: { $0.name.hasSuffix(".png") }),
               let image = NSImage(contentsOf: png.url)
            {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 140)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Palette.line))
                    .accessibilityLabel(Copy.t("页面截图", "Page screenshot"))
            }
            if let display = webBodyText {
                ResultBodyView.markdown(display, baseDirectory: webMarkdownDirectory)
            }
        }
        .padding(.bottom, 4)
    }

    private var webBodyText: String? {
        guard let md = item.parts.first(where: { $0.name.hasSuffix(".md") }),
              let body = try? String(contentsOf: md.url, encoding: .utf8)
        else { return nil }
        var display = body.trimmingCharacters(in: .whitespacesAndNewlines)
        if display.hasPrefix(item.title) {
            let rest = display.dropFirst(item.title.count).trimmingCharacters(in: .whitespacesAndNewlines)
            if rest.isEmpty == false { display = rest }
        }
        return display.isEmpty ? nil : display
    }

    private var webMarkdownDirectory: URL? {
        item.parts.first(where: { $0.name.hasSuffix(".md") })?.url.deletingLastPathComponent()
    }
}
