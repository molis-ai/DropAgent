import DropAgentShelf
import SwiftUI

struct ResultPane: View {
    @ObservedObject var session: AppSession

    @ViewBuilder
    var body: some View {
        if session.paneFocus == .result, let record = session.selectedResult, record.output == nil {
            VStack(alignment: .leading, spacing: 14) {
                Label(Copy.t("这次没有生成文件", "No file was produced"), systemImage: "exclamationmark.circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.warning)
                Text(record.failureReason ?? Copy.t("任务未完成，请重新选择动作。", "The task did not finish. Choose an action to try again."))
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Button { session.reselectResultSources(record) } label: {
                    Label(Copy.t("返回材料重试", "Back to materials"), systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("retry-result")
            }
        } else if let item = session.currentResult() {
            VStack(alignment: .leading, spacing: 14) {
                Text(item.output?.lastPathComponent ?? item.title)
                    .font(.system(size: 12, weight: .semibold))
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
                Divider().overlay(Palette.line)
                ResultPreview(item: item)
            }
        } else {
            Text(Copy.t("点左边看输入，点右边结果看产出。", "Select an input on the left, or a result on the right."))
                .font(.system(size: 11))
                .foregroundStyle(Palette.faint)
        }
    }
}
