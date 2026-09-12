import SwiftUI

/// Flexible rows retain their own layout while sharing pointer and keyboard feedback.
struct RowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        RowButtonChrome(pressed: configuration.isPressed) { configuration.label }
    }
}

private struct RowButtonChrome<Label: View>: View {
    let pressed: Bool
    @ViewBuilder var label: () -> Label
    @State private var hovering = false
    @Environment(\.isEnabled) private var enabled
    @Environment(\.isFocused) private var focused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        label()
            .background(enabled && (hovering || pressed) ? Palette.panelHover : Color.clear, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8).strokeBorder(focused ? Palette.accent : Color.clear, lineWidth: 2)
            }
            .opacity(enabled ? 1 : 0.45)
            .onHover { hovering = $0 }
            .animation(reduceMotion ? nil : Palette.motion, value: hovering)
    }
}

struct QuietButtonStyle: ButtonStyle {
    var selected = false
    var danger = false
    var expand = false
    var subtle = false

    func makeBody(configuration: Configuration) -> some View {
        PaperButtonChrome(
            pressed: configuration.isPressed,
            height: 32,
            hug: expand == false,
            semibold: selected,
            kind: subtle ? .quiet : .paper,
            selected: selected,
            danger: danger
        ) {
            configuration.label
        }
    }
}

struct ActionButtonStyle: ButtonStyle {
    var selected = false

    func makeBody(configuration: Configuration) -> some View {
        PaperButtonChrome(pressed: configuration.isPressed, height: 30, hug: true,
                          compact: true, kind: .quiet, selected: selected) {
            configuration.label
        }
    }
}

struct IconButtonStyle: ButtonStyle {
    var selected = false
    var size: CGFloat = 30

    func makeBody(configuration: Configuration) -> some View {
        PaperButtonChrome(
            pressed: configuration.isPressed,
            height: size,
            hug: true,
            square: size,
            kind: .quiet,
            selected: selected
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
            height: 30,
            hug: true,
            compact: true,
            semibold: selected,
            kind: .paper,
            selected: selected
        ) {
            configuration.label
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var expand = false
    var height: CGFloat = 34

    func makeBody(configuration: Configuration) -> some View {
        PaperButtonChrome(
            pressed: configuration.isPressed,
            height: height,
            hug: expand == false,
            semibold: true,
            kind: .accent
        ) {
            configuration.label
        }
    }
}

private struct PaperButtonChrome<Label: View>: View {
    var pressed: Bool
    var height: CGFloat?
    var hug = false
    var square: CGFloat?
    var compact = false
    var semibold = false
    var kind: Kind = .paper
    var selected = false
    var danger = false
    @ViewBuilder var label: () -> Label
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isFocused) private var focused
    @State private var hovering = false

    enum Kind { case paper, quiet, accent }

    var body: some View {
        let down = pressed && isEnabled
        label()
            .labelStyle(.titleAndIcon)
            .font(.system(size: 12, weight: (semibold || selected) ? .semibold : .regular))
            .foregroundStyle(foreground)
            .padding(.horizontal, square == nil ? (compact ? 8 : 12) : 0)
            .frame(width: square, height: square ?? height)
            .frame(maxWidth: hug || square != nil ? nil : .infinity)
            .background(fill)
            .overlay {
                if kind == .paper || focused || selected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(focused ? Palette.accent : selected ? Palette.accent.opacity(0.45) : Palette.line, lineWidth: focused ? 2 : 1)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .shadow(
                color: kind == .accent && isEnabled && down == false ? Color.black.opacity(0.12) : .clear,
                radius: 2,
                y: 1
            )
            .contentShape(Rectangle())
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(down && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : Palette.selectionMotion, value: down)
            .animation(reduceMotion ? nil : Palette.motion, value: hovering)
            .onHover { hovering = $0 }
    }

    private var foreground: Color {
        if kind == .accent {
            return isEnabled ? Palette.onAccent : Palette.muted
        }
        if isEnabled == false { return Palette.faint }
        if danger { return Palette.danger }
        return selected ? Palette.accent : Palette.text
    }

    private var fill: Color {
        if kind == .accent {
            guard isEnabled else { return Palette.panel2 }
            if pressed || hovering { return Palette.accentPressed }
            return Palette.accent
        }
        if selected && isEnabled { return Palette.panelPress }
        if pressed && isEnabled { return Palette.panelPress }
        if hovering && isEnabled { return Palette.panelHover }
        return kind == .quiet ? .clear : Palette.panel
    }
}
