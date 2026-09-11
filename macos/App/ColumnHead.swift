import SwiftUI

struct ColumnHead<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.muted)
                    .accessibilityAddTraits(.isHeader)
            }
            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(minHeight: LivePanelChrome.columnHeadHeight, alignment: .center)
    }
}
