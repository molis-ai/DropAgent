import SwiftUI

struct ErrorBanner: View {
    @ObservedObject var session: AppSession

    @ViewBuilder
    var body: some View {
        if session.isCapturing == false, let error = session.errorText {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Palette.text)
                        .accessibilityHidden(true)
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 6) {
                    if session.offerPrivacySettings {
                        Button {
                            session.openPrivacySettings()
                        } label: {
                            Label(Copy.t("去授权", "Authorize"), systemImage: "lock.shield")
                        }
                            .buttonStyle(QuietButtonStyle())
                            .frame(width: 88)
                            .accessibilityLabel(Copy.t("打开辅助功能授权", "Open Accessibility settings"))
                    }
                    if session.offerCaptureRetry || session.offerPrivacySettings {
                        Button {
                            session.retryCapture()
                        } label: {
                            Label(Copy.t("再试", "Retry"), systemImage: "arrow.clockwise")
                        }
                            .buttonStyle(QuietButtonStyle())
                            .frame(width: 68)
                            .disabled(session.isCapturing)
                            .accessibilityLabel(Copy.t("再抓一次当前页", "Capture the current page again"))
                    }
                    Spacer(minLength: 0)
                    Button(Copy.t("好", "OK")) { session.dismissError() }
                        .buttonStyle(QuietButtonStyle())
                        .frame(width: 44)
                        .accessibilityLabel(Copy.t("关闭这条提示", "Dismiss this notice"))
                }
            }
            .padding(8)
            .background(Palette.panel2)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.line))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
