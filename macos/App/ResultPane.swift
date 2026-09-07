import DropAgentShelf
import SwiftUI

struct ResultPane: View {
    @ObservedObject var session: AppSession

    @ViewBuilder
    var body: some View {
        if let item = session.currentResult() {
            VStack(alignment: .leading, spacing: 8) {
                Text(item.output?.lastPathComponent ?? item.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.text)
                if let reason = item.failureReason {
                    Text(reason)
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.warning)
                }
                if let isolation = session.resultIsolationLine {
                    Text(isolation)
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.faint)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ResultPreview(item: item)
            }
        } else {
            Text(Copy.t("点左边看输入，点右边结果看产出。", "Select an input on the left, or a result on the right."))
                .font(.system(size: 11))
                .foregroundStyle(Palette.faint)
        }
    }
}
