import SwiftUI
import AppKit

/// A minimal, reliable code editor built on a stock TextKit 2 NSTextView.
/// Deliberately avoids a custom layout-manager stack and a custom ruler: those
/// force TextKit 1 and break glyph compositing inside SwiftUI's layer-backed
/// hierarchy. Syntax highlighting is applied directly to the text storage,
/// which TextKit 2 renders correctly.
struct CodeEditor: NSViewRepresentable {
    @Binding var text: String
    var fontSize: Double
    var wrapLines: Bool
    var showLineNumbers: Bool
    var onCursorChange: ((Int) -> Void)? = nil

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true

        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }

        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.usesFindBar = true
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.backgroundColor = .textBackgroundColor
        textView.textColor = .labelColor
        textView.insertionPointColor = .labelColor
        textView.font = NSFont.monospacedSystemFont(ofSize: CGFloat(fontSize), weight: .regular)
        textView.string = text

        context.coordinator.textView = textView
        context.coordinator.applyWrap(wrapLines)
        context.coordinator.highlight()
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }
        context.coordinator.parent = self
        if textView.string != text {
            let sel = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = sel
            context.coordinator.highlight()
        }
        let font = NSFont.monospacedSystemFont(ofSize: CGFloat(fontSize), weight: .regular)
        if textView.font != font {
            textView.font = font
            context.coordinator.highlight()
        }
        context.coordinator.applyWrap(wrapLines)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CodeEditor
        weak var textView: NSTextView?
        private var currentWrap: Bool?

        init(_ parent: CodeEditor) { self.parent = parent }

        func applyWrap(_ wrap: Bool) {
            guard currentWrap != wrap, let tv = textView,
                  let container = tv.textContainer, let scroll = tv.enclosingScrollView else { return }
            currentWrap = wrap
            if wrap {
                container.widthTracksTextView = true
                container.size = NSSize(width: scroll.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
                tv.isHorizontallyResizable = false
                scroll.hasHorizontalScroller = false
            } else {
                container.widthTracksTextView = false
                container.size = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
                tv.isHorizontallyResizable = true
                scroll.hasHorizontalScroller = true
            }
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = textView else { return }
            parent.text = tv.string
            highlight()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let tv = textView else { return }
            parent.onCursorChange?(lineNumber(for: tv.selectedRange().location, in: tv.string))
        }

        private func lineNumber(for location: Int, in string: String) -> Int {
            let ns = string as NSString
            let clamped = min(location, ns.length)
            var line = 1
            ns.enumerateSubstrings(in: NSRange(location: 0, length: clamped), options: .byLines) { _, _, _, _ in
                line += 1
            }
            return line
        }

        func highlight() {
            guard let tv = textView, let storage = tv.textStorage else { return }
            let font = NSFont.monospacedSystemFont(ofSize: CGFloat(parent.fontSize), weight: .regular)
            MermaidHighlighter.apply(to: storage, font: font)
        }
    }
}

// MARK: - Syntax highlighter

enum MermaidHighlighter {
    private struct Rule { let regex: NSRegularExpression; let color: NSColor }

    private static let keywords = [
        "flowchart","graph","sequenceDiagram","classDiagram","stateDiagram-v2","stateDiagram",
        "erDiagram","gantt","pie","gitGraph","mindmap","journey","timeline","quadrantChart",
        "requirementDiagram","C4Context","sankey-beta","xychart-beta","block-beta",
        "subgraph","end","participant","actor","loop","alt","else","opt","par","and","rect",
        "note","activate","deactivate","autonumber","class","state","section","title",
        "dateFormat","axisFormat","branch","checkout","merge","commit","cherry-pick",
        "direction","click","style","classDef","linkStyle","showData"
    ]

    // System semantic colors so the editor stays readable in light or dark mode.
    static let baseColor = NSColor.labelColor

    private static let rules: [Rule] = {
        func rx(_ p: String, _ opts: NSRegularExpression.Options = []) -> NSRegularExpression {
            try! NSRegularExpression(pattern: p, options: opts)
        }
        let kw = "\\b(" + keywords.joined(separator: "|") + ")\\b"
        return [
            Rule(regex: rx("%%.*$", [.anchorsMatchLines]), color: .systemGray),
            Rule(regex: rx(kw), color: .systemPurple),
            Rule(regex: rx("(-{1,3}>|={1,3}>|-\\.->|--x|--o|<-{1,3}|\\.\\.>|==>|--|-\\.-|o--o|x--x|\\|)"), color: .systemPink),
            Rule(regex: rx("\"[^\"]*\""), color: .systemRed),
            Rule(regex: rx("[\\[\\]{}()]"), color: .systemTeal),
            Rule(regex: rx("\\b\\d+(\\.\\d+)?\\b"), color: .systemOrange)
        ]
    }()

    static func apply(to storage: NSTextStorage, font: NSFont) {
        let full = NSRange(location: 0, length: storage.length)
        let text = storage.string
        storage.beginEditing()
        storage.setAttributes([.font: font, .foregroundColor: baseColor], range: full)
        for rule in rules {
            rule.regex.enumerateMatches(in: text, options: [], range: full) { match, _, _ in
                if let r = match?.range {
                    storage.addAttribute(.foregroundColor, value: rule.color, range: r)
                }
            }
        }
        storage.endEditing()
    }
}
