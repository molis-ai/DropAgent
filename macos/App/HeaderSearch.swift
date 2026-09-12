import SwiftUI

struct HeaderSearchField: View {
    @ObservedObject var session: AppSession
    var autofocus = false
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Palette.faint)
                .accessibilityHidden(true)
            TextField(
                Copy.t("搜索本机文件", "Search this Mac"),
                text: Binding(
                    get: { session.spotlight.text },
                    set: { session.spotlight.setText($0) }
                )
            )
            .textFieldStyle(.plain)
            .focused($focused)
            .font(.system(size: 12))
            .foregroundStyle(Palette.text)
            .accessibilityIdentifier("shelf-search")
            .background(AccessibleID(identifier: "shelf-search").frame(width: 0, height: 0).allowsHitTesting(false))
            if session.spotlight.text.isEmpty == false {
                Button {
                    session.spotlight.setText("")
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .semibold))
                }
                .buttonStyle(IconButtonStyle(size: 22))
                .accessibilityLabel(Copy.t("清除搜索", "Clear search"))
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 28)
        .background(Palette.field)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(focused ? Palette.accent : Color.clear)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onAppear { if autofocus { focused = true } }
    }
}

struct HeaderSearchMenu: View {
    @ObservedObject var session: AppSession

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if session.spotlight.gathering && session.spotlight.hits.isEmpty {
                Text(Copy.t("正在搜索…", "Searching…"))
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.muted)
                    .padding(12)
            } else if session.spotlight.hits.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(Copy.t("没有叫这个名字的文件", "No files with that name"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Palette.text)
                    Text(Copy.t("会找桌面、文稿、下载。也可以点 + 直接选。", "Looks in Desktop, Documents, and Downloads. Or add with +."))
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.faint)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(session.spotlight.hits) { hit in
                            Button {
                                session.admitSpotlight(hit)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: hit.folder ? "folder" : "doc")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(Palette.muted)
                                        .frame(width: 16)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(hit.name)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(Palette.text)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                        Text(Copy.displayPath(hit.url))
                                            .font(.system(size: 11))
                                            .foregroundStyle(Palette.faint)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(RowButtonStyle())
                            .accessibilityLabel(Copy.t("加入 \(hit.name)", "Add \(hit.name)"))
                            .accessibilityIdentifier("spotlight-hit")
                        }
                    }
                }
                .frame(maxHeight: 240)
            }
        }
        .frame(width: 320, alignment: .leading)
        .background(Palette.panel)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Palette.line)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: Color.black.opacity(0.14), radius: 16, x: 0, y: 8)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Copy.t("搜索结果", "Search results"))
    }
}
