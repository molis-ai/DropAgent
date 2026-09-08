import SwiftUI

struct OnboardingView: View {
    @ObservedObject var session: AppSession
    var body: some View {
        VStack(alignment: .leading, spacing: 52) {
            Text(Onboarding.headline)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Palette.text)
                .padding(.bottom, 6)
            onboardStep(
                number: "1",
                title: Onboarding.step1Title,
                detail: Onboarding.step1Detail(captureOK: session.hotKeyCaptureOK, captureLabel: session.prefs.captureHotKey.label)
            )
            onboardStep(
                number: "2",
                title: Onboarding.step2Title,
                detail: Onboarding.step2Detail(
                    hasAgent: session.hasAgent,
                    hasRecipe: session.hasRecipe,
                    tuiTitle: session.tuiTitle
                )
            )
            onboardStep(number: "3", title: Onboarding.step3Title, detail: Onboarding.step3Detail)
            Button {
                session.tryOnboardingSample()
            } label: {
                Label(Onboarding.tryTitle, systemImage: "tray.and.arrow.down")
            }
            .buttonStyle(PrimaryButtonStyle())
            .frame(maxWidth: .infinity)
            .accessibilityLabel("放一份示例文稿到架子")
            .accessibilityIdentifier("onboard-try")
            Button {
                session.dismissOnboarding()
            } label: {
                Label(Onboarding.skipTitle, systemImage: "xmark")
            }
            .buttonStyle(QuietButtonStyle())
            .frame(maxWidth: .infinity)
            .accessibilityLabel("跳过第一次说明")
            .accessibilityIdentifier("onboard-skip")
        }
        .padding(.vertical, 18)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("第一次使用")
    }

    private func onboardStep(number: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(number)
                .font(.system(size: 10, weight: .bold))
                .tracking(0.4)
                .foregroundStyle(Palette.muted)
                .padding(.horizontal, 5)
                .frame(height: 18)
                .background(Palette.panel2)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.text)
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.faint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

}
