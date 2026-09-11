import SwiftUI

struct OnboardingView: View {
    @ObservedObject var session: AppSession

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 48) {
                    welcome.frame(minWidth: 320, maxWidth: .infinity, alignment: .leading)
                    route.frame(width: 244)
                }
                VStack(alignment: .leading, spacing: 24) {
                    welcome
                    route
                }
            }
            HStack(spacing: 8) {
                Image(systemName: "lock.shield")
                    .foregroundStyle(Palette.accent)
                Text(Copy.t("本次体验在本机完成，无需 Agent、授权或网络。", "This sample runs on your Mac. No agent, permissions, or internet needed."))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Button(Copy.t("跳过引导", "Skip introduction")) { session.dismissOnboarding() }
                    .buttonStyle(QuietButtonStyle(subtle: true))
                    .accessibilityIdentifier("onboard-skip")
            }
            .font(.system(size: 11.5))
            .foregroundStyle(Palette.muted)
        }
        .padding(24)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Copy.t("第一次使用", "First use"))
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Onboarding.title)
                .font(.system(size: 26, weight: .semibold))
                .tracking(-0.6)
                .foregroundStyle(Palette.text)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(Onboarding.intro)
                .font(.system(size: 13))
                .foregroundStyle(Palette.muted)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 440, alignment: .leading)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { sampleButton; fileButton }
                VStack(alignment: .leading, spacing: 8) { sampleButton; fileButton }
            }
            .padding(.top, 8)
        }
    }

    private var sampleButton: some View {
        Button { session.tryOnboardingSample() } label: {
            Label(Onboarding.tryTitle, systemImage: "arrow.right")
        }
        .buttonStyle(PrimaryButtonStyle(height: 36))
        .accessibilityIdentifier("onboard-try")
    }

    private var fileButton: some View {
        Button(Copy.t("选择文件…", "Choose a file…")) { session.pickFilesToAdmit() }
            .buttonStyle(QuietButtonStyle())
            .accessibilityIdentifier("onboard-pick")
    }

    private var route: some View {
        VStack(alignment: .leading, spacing: 0) {
            routeStep(1, Copy.t("添加材料", "Add a file"), Copy.t("拖入文件，或使用示例", "Drop a file or try the sample"), active: true)
            routeStep(2, Copy.t("选择动作", "Choose an action"), Copy.t("确认范围，在副本上处理", "Review the scope, then run"))
            routeStep(3, Copy.t("导出结果", "Export the result"), Copy.t("复制文件，或直接拖出", "Copy the file or drag it out"), last: true)
        }
        .accessibilityElement(children: .combine)
    }

    private func routeStep(_ number: Int, _ title: String, _ detail: String, active: Bool = false, last: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 4) {
                Text("\(number)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(active ? Palette.onAccent : Palette.muted)
                    .frame(width: 26, height: 26)
                    .background(active ? Palette.accent : Palette.panel2, in: Circle())
                if !last {
                    Rectangle().fill(Palette.line).frame(width: 1, height: 22)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.text)
                Text(detail).font(.system(size: 11.5)).foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, last ? 0 : 8)
    }
}

struct SampleActionGuide: View {
    @ObservedObject var session: AppSession

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "text.viewfinder")
                .font(.system(size: 20))
                .foregroundStyle(Palette.accent)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(Copy.t("示例已添加", "Sample added"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.text)
                Text(Copy.t("第 2 步，共 3 步 · 先确认处理范围，再提取文字。", "Step 2 of 3 · Review the scope before extracting text."))
                    .font(.system(size: 11.5))
                    .foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 0)
            Button { session.chooseRecipe(.pdfText) } label: {
                Label(Copy.t("提取文字…", "Extract text…"), systemImage: "arrow.right")
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityIdentifier("onboard-extract")
            Button { session.dismissFirstActionHint() } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(IconButtonStyle())
            .accessibilityLabel(Copy.t("关闭操作提示", "Dismiss the guide"))
            .accessibilityIdentifier("onboard-coach-dismiss")
        }
        .padding(12)
        .background(Palette.panel, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboard-coach")
    }
}

struct JourneyEcho: View {
    var label: String? = nil
    var strong: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            JourneyMark()
                .padding(.top, 4)
            if let label, label.isEmpty == false {
                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.muted)
            }
            Text(strong)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Palette.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

struct JourneyMark: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(Palette.accent)
            .frame(width: 5, height: 5)
            .accessibilityHidden(true)
    }
}

enum JourneyLinkKind {
    case nav
    case skip
}

enum JourneyArrow {
    case none
    case forward
    case back
}

struct JourneyLink: View {
    var title: String
    var arrow: JourneyArrow = .none
    var kind: JourneyLinkKind = .nav
    var subdued = false
    var action: () -> Void
    @State private var hovering = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if arrow == .back {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 10, weight: .semibold))
                        .offset(x: arrowShift)
                }
                Text(title)
                if arrow == .forward {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .semibold))
                        .offset(x: arrowShift)
                }
            }
        }
        .buttonStyle(JourneyButtonStyle(kind: kind, subdued: subdued, hovering: hovering && isEnabled))
        .onHover { hovering = $0 }
        .animation(reduceMotion ? nil : Palette.motion, value: hovering)
    }

    private var arrowShift: CGFloat {
        guard hovering, isEnabled, reduceMotion == false else { return 0 }
        return arrow == .back ? -2 : 2
    }
}

private struct JourneyButtonStyle: ButtonStyle {
    var kind: JourneyLinkKind
    var subdued: Bool
    var hovering: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: kind == .skip ? 11 : 10.5, weight: kind == .skip ? .regular : .semibold))
            .foregroundStyle(ink(pressed: configuration.isPressed))
            .opacity(configuration.isPressed ? 0.62 : 1)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
    }

    private func ink(pressed: Bool) -> Color {
        if hovering || pressed { return Palette.accent }
        return subdued || kind == .skip ? Palette.muted : Palette.text
    }
}
