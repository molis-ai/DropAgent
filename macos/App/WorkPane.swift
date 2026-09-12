import SwiftUI

struct WorkPane: View {
    @ObservedObject var session: AppSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ViewBuilder
    var body: some View {
        if session.isCapturing {
            CapturingBody(reduceMotion: reduceMotion)
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
        } else {
            let batch = session.paneFocus == .input ? session.selectedItems : []
            if batch.isEmpty && session.showsOnboarding {
                OnboardingView(session: session)
            } else if batch.isEmpty && session.showsCaptureBanner && session.errorText == nil {
                CaptureReadyBanner(session: session)
                    .padding(.bottom, 4)
            } else if batch.contains(where: { $0.status == .confirm }) {
                RecipeConfirmationView(session: session)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            } else if let running = batch.first(where: { $0.status == .running }) {
                WorkRunningView(
                    event: running.event,
                    actor: session.recipeActorLine,
                    waiting: running.event.contains("等待授权"),
                    waitCopy: HotKeyCopy.recipeApprovalWaitLine(tuiTitle: session.tuiTitle),
                    onCancel: { session.cancelRun() },
                    reduceMotion: reduceMotion
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            } else if session.paneFocus == .input, let reason = session.selectedFailureReason {
                VStack(alignment: .leading, spacing: 4) {
                    Text(reason)
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.warning)
                    if let retry = session.failedRetryLine {
                        Text(retry)
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.faint)
                    }
                    if let retry = session.failedOutputRetryRecipe {
                        Button {
                            session.chooseRecipe(retry)
                        } label: {
                            Text(Copy.t("再跑一次", "Run again"))
                        }
                        .buttonStyle(QuietButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
            }
        }
        if !session.isCapturing && session.errorText != nil && (session.paneFocus != .input || session.selectedFailureReason == nil) {
            ErrorBanner(session: session)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
    }
}
