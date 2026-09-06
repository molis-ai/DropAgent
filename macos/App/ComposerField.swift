import AppKit
import SwiftUI

struct ComposerField: NSViewRepresentable {
    @Binding var text: String
    @Binding var focused: Bool
    var placeholder: String
    var enabled: Bool
    var onSubmit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, focused: $focused, onSubmit: onSubmit)
    }

    func makeNSView(context: Context) -> NSTextField {
        let field = ComposerTextField(string: "")
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: 12)
        field.delegate = context.coordinator
        field.lineBreakMode = .byTruncatingTail
        field.cell?.usesSingleLineMode = true
        field.cell?.wraps = false
        field.cell?.isScrollable = true
        field.setAccessibilityLabel("写给终端")
        applyChrome(field)
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        context.coordinator.text = $text
        context.coordinator.focused = $focused
        context.coordinator.onSubmit = onSubmit
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        nsView.isEnabled = enabled
        nsView.isEditable = enabled
        applyChrome(nsView)
    }

    private func applyChrome(_ field: NSTextField) {
        field.textColor = enabled
            ? NSColor(calibratedWhite: 17 / 255, alpha: 1)
            : NSColor(calibratedWhite: 90 / 255, alpha: 1)
        field.placeholderAttributedString = NSAttributedString(
            string: placeholder,
            attributes: [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor(calibratedWhite: 120 / 255, alpha: 1),
            ]
        )
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>
        var focused: Binding<Bool>
        var onSubmit: () -> Void

        init(text: Binding<String>, focused: Binding<Bool>, onSubmit: @escaping () -> Void) {
            self.text = text
            self.focused = focused
            self.onSubmit = onSubmit
        }

        func controlTextDidChange(_ obj: Notification) {
            text.wrappedValue = (obj.object as? NSTextField)?.stringValue ?? ""
        }

        func controlTextDidBeginEditing(_ obj: Notification) {
            focused.wrappedValue = true
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            focused.wrappedValue = false
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            guard commandSelector == #selector(NSResponder.insertNewline(_:)) else { return false }
            if textView.hasMarkedText() { return false }
            onSubmit()
            return true
        }
    }
}

private final class ComposerTextField: NSTextField {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func becomeFirstResponder() -> Bool {
        let ok = super.becomeFirstResponder()
        (currentEditor() as? NSTextView)?.insertionPointColor = NSColor(calibratedWhite: 17 / 255, alpha: 1)
        return ok
    }
}
