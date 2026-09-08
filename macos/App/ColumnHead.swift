import SwiftUI

struct ColumnHead<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.muted)
            Spacer(minLength: 0)
            trailing()
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
    }
}
