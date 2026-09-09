import DropAgentShelf
import SwiftUI

enum FileKindGlyph {
    static func symbol(for item: Item) -> String {
        symbol(kind: item.kind, tag: item.displayTag)
    }

    static func symbol(kind: ItemKind, tag: String) -> String {
        switch tag.uppercased() {
        case "JSON": return "curlybraces"
        case "ZIP": return "archivebox"
        case "HTML", "HTM": return "chevron.left.forwardslash.chevron.right"
        case "SWIFT", "PY", "CSS", "YAML", "YML", "XML": return "chevron.left.forwardslash.chevron.right"
        case "JPG", "JPEG", "PNG", "GIF", "HEIC", "WEBP", "TIF", "TIFF": return "photo"
        default: break
        }
        switch kind {
        case .pdf: return "doc.richtext"
        case .image: return "photo"
        case .url: return "link"
        case .web: return "globe"
        case .markdown: return "text.alignleft"
        case .clip: return "doc.on.clipboard"
        case .folder: return "folder.fill"
        case .file: return "doc"
        }
    }
}

struct FileKindMark: View {
    let kind: ItemKind
    let tag: String
    var compact = false

    init(item: Item, compact: Bool = false) {
        kind = item.kind
        tag = item.displayTag
        self.compact = compact
    }

    init(kind: ItemKind, tag: String, compact: Bool = false) {
        self.kind = kind
        self.tag = tag
        self.compact = compact
    }

    var body: some View {
        if compact {
            chip
        } else {
            tile
        }
    }

    private var fill: Color { Palette.tagFill(kind: kind, tag: tag) }
    private var ink: Color { Palette.tagInk(kind: kind, tag: tag) }

    private var tile: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(fill)
            Image(systemName: FileKindGlyph.symbol(kind: kind, tag: tag))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(ink)
                .symbolRenderingMode(.monochrome)
        }
        .frame(width: 32, height: 32)
        .accessibilityHidden(true)
    }

    private var chip: some View {
        HStack(spacing: 4) {
            Image(systemName: FileKindGlyph.symbol(kind: kind, tag: tag))
                .font(.system(size: 10, weight: .semibold))
                .symbolRenderingMode(.monochrome)
            Text(tag)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
        }
        .foregroundStyle(ink)
        .padding(.horizontal, 6)
        .frame(height: 18)
        .background(fill)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .accessibilityHidden(true)
    }
}
