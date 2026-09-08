import DropAgentJob
import DropAgentShelf
import SwiftUI

struct WorkPane: View {
    @ObservedObject var session: AppSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ViewBuilder
    var body: some View {
        if session.isCapturing {
            CapturingBody(reduceMotion: reduceMotion)
        } else if session.offerPrivacySettings || session.offerCaptureRetry {
            EmptyView()
        } else {
            let batch = session.selectedItems
            if batch.isEmpty && session.showsOnboarding {
                OnboardingView(session: session)
            } else if batch.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    RecipeChooser(session: session)
                    Text(HotKeyCopy.workIdleHint(
                        hasAgent: session.hasAgent,
                        hasRecipe: session.hasRecipe,
                        tuiTitle: session.tuiTitle,
                        captureOK: session.hotKeyCaptureOK,
                        hasItems: session.items.isEmpty == false
                    ))
                    .font(.system(size: 11.5))
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    if session.hasAgent == false {
                        Button {
                            session.openTUIInstall(nil)
                        } label: {
                            Label(Copy.t("如何安装终端 Agent", "How to install a terminal agent"), systemImage: "arrow.down.app")
                        }
                            .buttonStyle(QuietButtonStyle())
                            .accessibilityLabel(Copy.t("打开终端 Agent 安装说明", "Open terminal agent install notes"))
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else if batch.contains(where: { $0.status == .confirm }) {
                RecipeConfirmationView(session: session)
            } else if let running = batch.first(where: { $0.status == .running }) {
                WorkRunningView(
                    event: running.event,
                    actor: session.recipeActorLine,
                    waiting: running.event.contains("等待授权"),
                    waitCopy: HotKeyCopy.recipeApprovalWaitLine(tuiTitle: session.tuiTitle),
                    onCancel: { session.cancelRun() },
                    reduceMotion: reduceMotion
                )
            } else if session.isResultTakeaway {
                VStack(spacing: 0) {
                    Spacer(minLength: 8)
                    VStack(spacing: 10) {
                        StatusMark(
                            tone: session.selectedFailureReason == nil ? .ready : .fail,
                            spinning: false,
                            reduceMotion: reduceMotion
                        )
                        if let reason = session.selectedFailureReason {
                            Text(reason)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Palette.danger)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Text(Copy.t("可拖出", "Ready"))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(session.selectedFailureReason == nil ? Palette.accent : Palette.text)
                        Text(session.doneActionHint)
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.muted)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: 280)
                    Spacer(minLength: 8)
                    Button {
                        session.aiTab = .result
                    } label: {
                        Label(Copy.t("打开结果", "Open result"), systemImage: "doc.plaintext")
                    }
                        .buttonStyle(PrimaryButtonStyle())
                        .accessibilityLabel(Copy.t("打开结果", "Open result"))
                    if let recipe = session.failedOutputRetryRecipe {
                        Button {
                            session.chooseRecipe(recipe)
                        } label: {
                            Label(Copy.t("再跑一次", "Run again"), systemImage: "arrow.clockwise")
                        }
                            .buttonStyle(QuietButtonStyle())
                            .frame(maxWidth: .infinity)
                            .accessibilityLabel(Copy.t("再跑一次：\(Copy.recipeFull(recipe))", "Run again: \(Copy.recipeFull(recipe))"))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    if let reason = session.selectedFailureReason {
                        Text(reason)
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.warning)
                            .fixedSize(horizontal: false, vertical: true)
                        if let retry = session.failedRetryLine {
                            Text(retry)
                                .font(.system(size: 11))
                                .foregroundStyle(Palette.faint)
                        }
                    }
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(Copy.t("选择一个动作", "Choose an action"))
                                .font(.system(size: 21, weight: .semibold))
                                .foregroundStyle(Palette.text)
                            Text(Copy.t("已选 \(batch.count) 份材料 · 原件保留", "\(batch.count) selected · Originals stay"))
                                .font(.system(size: 11))
                                .foregroundStyle(Palette.muted)
                        }
                        Spacer(minLength: 4)
                        Button { session.aiTab = .result } label: {
                            Image(systemName: "doc.text.magnifyingglass")
                        }
                        .buttonStyle(QuietButtonStyle())
                        .frame(width: 30)
                        .help(Copy.t("预览材料", "Preview material"))
                        .accessibilityLabel(Copy.t("预览材料", "Preview material"))
                    }
                    .padding(.bottom, 10)
                    RecipeChooser(session: session)
                    Text(session.recipeChooserHint)
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.faint)
                    if session.copiedID != nil, batch.contains(where: { $0.id == session.copiedID }) {
                        Text(Copy.t("已复制到剪贴板", "Copied to the clipboard"))
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.accent)
                    }
                    if session.hasRecipe == false && session.hasAgent == false {
                        Button {
                            session.openTUIInstall(nil)
                        } label: {
                            Label(Copy.t("如何安装终端 Agent", "How to install a terminal agent"), systemImage: "arrow.down.app")
                        }
                        .buttonStyle(QuietButtonStyle())
                        .accessibilityLabel(Copy.t("打开终端 Agent 安装说明", "Open terminal agent install notes"))
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
    }
}
