import DropAgentCapture
import Foundation

public enum ReadableHTML {
    public static func markdown(from html: String, baseURL: URL? = nil) -> String {
        HTMLMarkdown.convert(html, baseURL: baseURL)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func isHTMLFile(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ext == "html" || ext == "htm"
    }
}
