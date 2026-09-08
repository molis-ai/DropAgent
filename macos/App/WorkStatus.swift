import SwiftUI

enum WorkTone {
    case run, wait, fail, sent, ready, confirm, capture

    var ink: Color {
        switch self {
        case .run: return Palette.run
        case .wait: return Palette.warning
        case .fail: return Palette.danger
        case .sent: return Palette.ice
        case .ready: return Palette.accent
        case .confirm: return Palette.text
        case .capture: return Palette.run
        }
    }

    var wash: Color { ink.opacity(0.14) }

    var symbol: String {
        switch self {
        case .run: return "arrow.triangle.2.circlepath"
        case .wait: return "exclamationmark.triangle.fill"
        case .fail: return "xmark.circle.fill"
        case .sent: return "apple.terminal"
        case .ready: return "square.and.arrow.up"
        case .confirm: return "play.circle"
        case .capture: return "safari"
        }
    }
}

struct StatusMark: View {
    var tone: WorkTone
    var spinning: Bool
    var reduceMotion: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(tone.wash)
                .frame(width: 56, height: 56)
            if spinning && freeze == false {
                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(.regular)
                    .tint(tone.ink)
            } else {
                Image(systemName: tone.symbol)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(tone.ink)
                    .symbolRenderingMode(.hierarchical)
            }
        }
        .accessibilityHidden(true)
    }

    private var freeze: Bool {
        reduceMotion
            || ProcessInfo.processInfo.arguments.contains("--preview")
            || ProcessInfo.processInfo.arguments.contains("--e2e")
    }
}

struct WorkRunningView: View {
    let event: String
    let actor: String
    let waiting: Bool
    let waitCopy: String
    let onCancel: () -> Void
    var reduceMotion: Bool

    var body: some View {
        let tone: WorkTone = waiting ? .wait : (event.contains("失败") ? .fail : .run)
        VStack(spacing: 0) {
            Spacer(minLength: 12)
            VStack(spacing: 12) {
                StatusMark(tone: tone, spinning: tone == .run, reduceMotion: reduceMotion)
                Text(waiting ? Copy.t("等待授权", "Waiting for approval") : Copy.t("正在运行", "Running"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tone.ink)
                Text(event.isEmpty ? Copy.t("正在准备副本", "Preparing a copy") : event)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.text)
                    .multilineTextAlignment(.center)
                Text(actor)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.muted)
                    .multilineTextAlignment(.center)
                if waiting {
                    Text(waitCopy)
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.muted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: 280)
            Spacer(minLength: 12)
            Button(action: onCancel) {
                Label(Copy.t("取消", "Cancel"), systemImage: "xmark")
            }
            .buttonStyle(QuietButtonStyle())
            .accessibilityLabel(Copy.t("取消这次副本任务", "Cancel this copy job"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(waiting ? Copy.t("等待授权", "Waiting for approval") : Copy.t("正在运行", "Running"))
        .accessibilityValue(event)
    }
}
