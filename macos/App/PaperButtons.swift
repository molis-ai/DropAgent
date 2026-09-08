import SwiftUI

struct RecipeButtonStyle: ButtonStyle {
    var selected = false

    func makeBody(configuration: Configuration) -> some View {
        PaperButtonChrome(
            pressed: configuration.isPressed,
            height: nil,
            labelStyle: false,
            semibold: false,
            inkOnPaper: true,
            selected: selected,
            stroked: false
        ) {
            configuration.label
        }
    }
}

struct QuietButtonStyle: ButtonStyle {
    var selected = false

    func makeBody(configuration: Configuration) -> some View {
        PaperButtonChrome(
            pressed: configuration.isPressed,
            height: 34,
            labelStyle: true,
            semibold: false,
            inkOnPaper: true,
            selected: selected,
            stroked: false
        ) {
            configuration.label
        }
    }
}

struct TagButtonStyle: ButtonStyle {
    var selected = false

    func makeBody(configuration: Configuration) -> some View {
        PaperButtonChrome(
            pressed: configuration.isPressed,
            height: 28,
            labelStyle: false,
            semibold: selected,
            inkOnPaper: true,
            selected: selected,
            stroked: false,
            compact: true
        ) {
            configuration.label
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PaperButtonChrome(
            pressed: configuration.isPressed,
            height: 38,
            labelStyle: true,
            semibold: true,
            inkOnPaper: false,
            stroked: false
        ) {
            configuration.label
        }
    }
}

private struct PaperButtonChrome<Label: View>: View {
    var pressed: Bool
    var height: CGFloat?
    var labelStyle: Bool
    var semibold: Bool
    var inkOnPaper: Bool
    var selected = false
    var stroked = true
    var compact = false
    @ViewBuilder var label: () -> Label
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false

    var body: some View {
        let down = pressed && isEnabled
        styledLabel
            .font(.system(size: compact ? 12 : 12, weight: (semibold || selected) ? .semibold : .regular))
            .foregroundStyle(foreground)
            .padding(.horizontal, compact ? 10 : 0)
            .frame(maxWidth: compact ? nil : .infinity, maxHeight: height == nil ? nil : .infinity)
            .frame(height: height)
            .background(fill)
            .overlay {
                if stroked {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Palette.line)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: inkOnPaper ? .clear : Palette.blue.opacity(down ? 0 : 0.15), radius: 4, x: 0, y: 2)
            .contentShape(Rectangle())
            .opacity(isEnabled ? 1 : (inkOnPaper ? 0.45 : 0.55))
            .offset(y: down ? 1 : 0)
            .animation(reduceMotion ? nil : Palette.motion, value: down)
            .animation(reduceMotion ? nil : Palette.motion, value: hovering)
            .onHover { hovering = $0 }

    }

    @ViewBuilder
    private var styledLabel: some View {
        if labelStyle {
            label().labelStyle(.titleAndIcon)
        } else {
            label()
        }
    }

    private var foreground: Color {
        if inkOnPaper {
            if isEnabled == false { return Palette.faint }
            if compact && selected == false { return Palette.muted }
            return Palette.text
        }
        return isEnabled ? Palette.onAccent : Palette.muted
    }

    private var fill: Color {
        if inkOnPaper {
            if selected && isEnabled { return Palette.panelPress }
            if stroked {
                return Palette.controlFill(enabled: isEnabled, hovering: hovering, pressed: pressed)
            }
            if pressed && isEnabled { return Palette.panelPress }
            if hovering && isEnabled { return Palette.panelHover }
            return Color.clear
        }
        guard isEnabled else { return Palette.panel2 }
        if pressed || hovering { return Palette.bluePress }
        return Palette.blue
    }
}
