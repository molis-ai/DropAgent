import SwiftUI

struct ColumnHead<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Palette.text.opacity(0.55))
                    .frame(width: 5, height: 5)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(0.8)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.muted)
            }
            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .frame(minHeight: LivePanelChrome.columnHeadHeight, alignment: .center)
    }
}
