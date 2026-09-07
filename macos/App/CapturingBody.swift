import SwiftUI

struct CapturingBody: View {
    var reduceMotion: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 12)
            VStack(spacing: 12) {
                StatusMark(tone: .capture, spinning: true, reduceMotion: reduceMotion)
                Text("正在抓当前页")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.run)
                Text("读前台浏览器的地址、正文和截图。缺的会标明，不会造假文件。")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                meter
            }
            .frame(maxWidth: 280)
            Spacer(minLength: 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("正在抓当前页")
    }

    @ViewBuilder
    private var meter: some View {
        let freeze = reduceMotion || ProcessInfo.processInfo.arguments.contains("--preview")
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Palette.panel2)
                .frame(width: 88, height: 3)
            if freeze {
                Capsule()
                    .fill(Palette.text)
                    .frame(width: 36, height: 3)
            } else {
                TimelineView(.animation(minimumInterval: 1 / 30, paused: false)) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    let phase = t.truncatingRemainder(dividingBy: 1.15) / 1.15
                    let x = 52 * (0.5 - 0.5 * cos(phase * .pi * 2))
                    Capsule()
                        .fill(Palette.text)
                        .frame(width: 36, height: 3)
                        .offset(x: x)
                }
                .frame(width: 88, height: 3)
            }
        }
        .accessibilityHidden(true)
    }
}
