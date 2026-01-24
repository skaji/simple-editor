import SwiftUI
import AppKit

struct EditorView: NSViewRepresentable {
    @Binding var text: String
    let fontSize: Int
    let wrapLines: Bool
    let onEditorChanged: (Bool) -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = !wrapLines
        scrollView.drawsBackground = false

        let textView = EditorTextView()
        textView.isEditable = true
        textView.isRichText = false
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        if textView.responds(to: NSSelectorFromString("setAutomaticPeriodSubstitutionEnabled:")) {
            textView.setValue(false, forKey: "automaticPeriodSubstitutionEnabled")
        }
        textView.textContainerInset = NSSize(width: 6, height: 6)
        textView.font = .monospacedSystemFont(ofSize: CGFloat(fontSize), weight: .regular)
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.string = text
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        let textContainer = textView.textContainer
        textContainer?.widthTracksTextView = wrapLines
        if !wrapLines {
            textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            textView.isHorizontallyResizable = true
            textView.isVerticallyResizable = true
            textView.autoresizingMask = [.width]
        }

        scrollView.documentView = textView

        let ruler = LineNumberRuler(textView: textView)
        scrollView.verticalRulerView = ruler
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        if textView.hasMarkedText() {
            if textView.font?.pointSize != CGFloat(fontSize) {
                textView.font = .monospacedSystemFont(ofSize: CGFloat(fontSize), weight: .regular)
                nsView.verticalRulerView?.needsDisplay = true
            }
            return
        }
        if textView.string != text {
            textView.string = text
            if let container = textView.textContainer {
                textView.layoutManager?.ensureLayout(for: container)
            }
            nsView.verticalRulerView?.needsDisplay = true
        }
        if textView.font?.pointSize != CGFloat(fontSize) {
            textView.font = .monospacedSystemFont(ofSize: CGFloat(fontSize), weight: .regular)
            nsView.verticalRulerView?.needsDisplay = true
        }
        if let container = textView.textContainer {
            if container.widthTracksTextView != wrapLines {
                container.widthTracksTextView = wrapLines
            }
            if !wrapLines {
                container.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
                nsView.hasHorizontalScroller = true
                textView.isHorizontallyResizable = true
                textView.isVerticallyResizable = true
                textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            } else {
                container.containerSize = NSSize(width: textView.bounds.width, height: CGFloat.greatestFiniteMagnitude)
                nsView.hasHorizontalScroller = false
                textView.isHorizontallyResizable = false
                textView.maxSize = NSSize(width: textView.bounds.width, height: CGFloat.greatestFiniteMagnitude)
            }
        }
        if !context.coordinator.didFocus, nsView.window != nil {
            nsView.window?.makeFirstResponder(textView)
            context.coordinator.didFocus = true
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onEditorChanged: onEditorChanged)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        private var text: Binding<String>
        private let onEditorChanged: (Bool) -> Void
        var didFocus = false

        init(text: Binding<String>, onEditorChanged: @escaping (Bool) -> Void) {
            self.text = text
            self.onEditorChanged = onEditorChanged
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
            textView.enclosingScrollView?.verticalRulerView?.needsDisplay = true
            onEditorChanged(textView.hasMarkedText())
        }
    }
}

final class EditorTextView: NSTextView {
    override func keyDown(with event: NSEvent) {
        if !hasMarkedText() {
            let characters = event.characters
            if event.keyCode == 0x30 {
                insertText("  ", replacementRange: selectedRange())
                return
            }
            if event.keyCode == 0x5D || characters == "¥" {
                insertText("\\", replacementRange: selectedRange())
                return
            }
        }
        super.keyDown(with: event)
    }
}
