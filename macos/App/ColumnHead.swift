import SwiftUI

struct ColumnHead<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Palette.text.opacity(0.55))
                .frame(width: 5, height: 5)
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(Palette.muted)
            Spacer(minLength: 0)
            trailing()
        }
        .padding(.horizontal, 14)
        .frame(height: LivePanelChrome.columnHeadHeight)
    }
}
