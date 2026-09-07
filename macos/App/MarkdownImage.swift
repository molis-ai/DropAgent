import AppKit
import Foundation
import SwiftUI

enum MarkdownImage {
    static func localFile(url raw: String, baseDirectory: URL?) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }
        let lower = trimmed.lowercased()
        if lower.hasPrefix("javascript:") || lower.hasPrefix("data:") { return nil }
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") { return nil }
        guard let baseDirectory else { return nil }
        let root = URL(
            fileURLWithPath: baseDirectory.resolvingSymlinksInPath().standardizedFileURL.path,
            isDirectory: true
        )
        let candidate: URL
        if lower.hasPrefix("file:") {
            guard let parsed = URL(string: trimmed), parsed.isFileURL else { return nil }
            candidate = parsed.resolvingSymlinksInPath().standardizedFileURL
        } else {
            candidate = URL(fileURLWithPath: trimmed, relativeTo: root)
                .resolvingSymlinksInPath()
                .standardizedFileURL
        }
        let prefix = root.path.hasSuffix("/") ? root.path : root.path + "/"
        guard candidate.path == root.path || candidate.path.hasPrefix(prefix) else { return nil }
        return candidate
    }

    static func isRemote(_ raw: String) -> Bool {
        let lower = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return lower.hasPrefix("http://") || lower.hasPrefix("https://")
    }

    static func fetchRemote(_ raw: String) async -> Data? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased() else { return nil }
        guard scheme == "http" || scheme == "https" else { return nil }
        var request = URLRequest(url: url, timeoutInterval: 5)
        request.setValue("image/*,*/*;q=0.8", forHTTPHeaderField: "Accept")
        let session = URLSession(configuration: .ephemeral)
        defer { session.finishTasksAndInvalidate() }
        guard let (data, response) = try? await session.data(for: request) else { return nil }
        if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) == false {
            return nil
        }
        guard data.count <= 2_000_000 else { return nil }
        return data
    }
}

struct ResultMarkdownImage: View {
    let alt: String
    let url: String
    let baseDirectory: URL?
    @State private var image: NSImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 220)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Palette.line))
                if alt.isEmpty == false {
                    Text(alt)
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.faint)
                }
            } else {
                Text(alt.isEmpty ? Copy.t("图片", "Image") : alt)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.muted)
                if let parsed = URL(string: url), SourceLink.isOpenable(parsed) {
                    Button(parsed.absoluteString) { SourceLink.open(parsed) }
                        .buttonStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.ice)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .onHover { hovering in
                            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                        }
                        .accessibilityLabel(Copy.t("打开 \(parsed.absoluteString)", "Open \(parsed.absoluteString)"))
                } else if url.isEmpty == false {
                    Text(url)
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.faint)
                        .textSelection(.enabled)
                }
            }
        }
        .accessibilityLabel(alt.isEmpty ? Copy.t("图片", "Image") : Copy.t("图片 \(alt)", "Image \(alt)"))
        .task { await load() }
    }

    private func load() async {
        if let file = MarkdownImage.localFile(url: url, baseDirectory: baseDirectory) {
            image = NSImage(contentsOf: file)
            return
        }
        guard MarkdownImage.isRemote(url), let data = await MarkdownImage.fetchRemote(url) else { return }
        image = NSImage(data: data)
    }
}
