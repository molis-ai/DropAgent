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
                        .font(.system(size: 12))
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
                            .accessibilityLabel(Copy.t("授权此功能", "Authorize this feature"))
                            .background(AccessibleID(identifier: "error-authorize").frame(width: 0, height: 0).allowsHitTesting(false))
                            .accessibilityIdentifier("error-authorize")
                    }
                    if session.offerCaptureRetry || session.offerPrivacySettings {
                        Button {
                            session.retryCapture()
                        } label: {
                            Label(Copy.t("再试", "Retry"), systemImage: "arrow.clockwise")
                        }
                            .buttonStyle(QuietButtonStyle())
                            .disabled(session.isCapturing)
                            .accessibilityLabel(Copy.t("重试刚才的操作", "Retry the last action"))
                            .background(AccessibleID(identifier: "error-retry").frame(width: 0, height: 0).allowsHitTesting(false))
                            .accessibilityIdentifier("error-retry")
                    }
                    Spacer(minLength: 0)
                    Button(Copy.t("关闭提示", "Dismiss")) { session.dismissError() }
                        .buttonStyle(QuietButtonStyle())
                        .accessibilityLabel(Copy.t("关闭这条提示", "Dismiss this notice"))
                }
            }
            .padding(14)
            .background(Palette.panel2)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .accessibilityElement(children: .contain)
            .background(AccessibleID(identifier: "error-banner").frame(width: 0, height: 0).allowsHitTesting(false))
            .accessibilityIdentifier("error-banner")
        }
    }
}
