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
        field.setAccessibilityLabel(Copy.t("写给终端", "Write to terminal"))
        applyChrome(field)
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        context.coordinator.text = $text
        context.coordinator.focused = $focused
        context.coordinator.onSubmit = onSubmit
        let composing = (nsView.currentEditor() as? NSTextView)?.hasMarkedText() == true
        if nsView.stringValue != text && composing == false {
            nsView.stringValue = text
        }
        nsView.isEnabled = enabled
        nsView.isEditable = enabled
        applyChrome(nsView)
        (nsView as? ComposerTextField)?.focusRequested = focused && enabled
    }

    private func applyChrome(_ field: NSTextField) {
        field.textColor = enabled ? Palette.textNS : Palette.mutedNS
        field.placeholderAttributedString = NSAttributedString(
            string: placeholder,
            attributes: [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: Palette.faintNS,
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
    var focusRequested = false {
        didSet { if focusRequested { requestFocusIfNeeded() } }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        requestFocusIfNeeded()
    }

    private func requestFocusIfNeeded() {
        guard focusRequested, window != nil, currentEditor() == nil else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.focusRequested, self.currentEditor() == nil else { return }
            self.window?.makeFirstResponder(self)
        }
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func becomeFirstResponder() -> Bool {
        let ok = super.becomeFirstResponder()
        (currentEditor() as? NSTextView)?.insertionPointColor = Palette.textNS
        return ok
    }
}
