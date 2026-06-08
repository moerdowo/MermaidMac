import SwiftUI
import AppKit

struct CodeEditor: NSViewRepresentable {
    @Binding var text: String
    var fontSize: Double
    var wrapLines: Bool
    var showLineNumbers: Bool
    var onCursorChange: ((Int) -> Void)? = nil

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.appearance = NSAppearance(named: .aqua)

        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
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
        textView.textContainerInset = NSSize(width: 6, height: 8)
        // Pin to a fixed light theme so token colors are always high-contrast,
        // regardless of system dark/light mode.
        textView.appearance = NSAppearance(named: .aqua)
        textView.drawsBackground = true
        textView.backgroundColor = MermaidHighlighter.backgroundColor
        textView.textColor = MermaidHighlighter.baseColor
        textView.insertionPointColor = MermaidHighlighter.baseColor
        textView.font = NSFont.monospacedSystemFont(ofSize: CGFloat(fontSize), weight: .regular)

        // Critical sizing so the text view actually lays out and shows content.
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: 400, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true

        textView.string = text

        context.coordinator.textView = textView
        scrollView.documentView = textView

        let ruler = LineNumberRulerView(textView: textView)
        scrollView.verticalRulerView = ruler
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = showLineNumbers
        context.coordinator.ruler = ruler

        context.coordinator.configure(fontSize: fontSize, wrap: wrapLines)
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
        context.coordinator.configure(fontSize: fontSize, wrap: wrapLines)
        scrollView.rulersVisible = showLineNumbers
        context.coordinator.ruler?.needsDisplay = true
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CodeEditor
        weak var textView: NSTextView?
        weak var ruler: LineNumberRulerView?
        private var currentFontSize: Double = 0
        private var currentWrap: Bool?

        init(_ parent: CodeEditor) { self.parent = parent }

        func configure(fontSize: Double, wrap: Bool) {
            guard let tv = textView else { return }
            let font = NSFont.monospacedSystemFont(ofSize: CGFloat(fontSize), weight: .regular)
            if currentFontSize != fontSize {
                tv.font = font
                currentFontSize = fontSize
                highlight()
            }
            ruler?.font = font
            if currentWrap != wrap {
                applyWrap(wrap, to: tv)
                currentWrap = wrap
            }
        }

        private func applyWrap(_ wrap: Bool, to tv: NSTextView) {
            guard let container = tv.textContainer else { return }
            if wrap {
                container.widthTracksTextView = true
                container.containerSize = NSSize(width: tv.bounds.width, height: CGFloat.greatestFiniteMagnitude)
                tv.isHorizontallyResizable = false
                tv.enclosingScrollView?.hasHorizontalScroller = false
            } else {
                container.widthTracksTextView = false
                container.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
                tv.isHorizontallyResizable = true
                tv.enclosingScrollView?.hasHorizontalScroller = true
                tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            }
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = textView else { return }
            parent.text = tv.string
            highlight()
            ruler?.needsDisplay = true
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let tv = textView else { return }
            let line = lineNumber(for: tv.selectedRange().location, in: tv.string)
            parent.onCursorChange?(line)
            ruler?.needsDisplay = true
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
            let font = NSFont.monospacedSystemFont(ofSize: CGFloat(currentFontSize > 0 ? currentFontSize : parent.fontSize), weight: .regular)
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

    // Explicit, appearance-independent palette tuned for a light editor
    // background so tokens are always readable regardless of system mode.
    static let baseColor = NSColor(srgbRed: 0.13, green: 0.14, blue: 0.16, alpha: 1)      // near-black
    static let backgroundColor = NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)         // white

    private static func c(_ r: Double, _ g: Double, _ b: Double) -> NSColor {
        NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
    }

    private static let rules: [Rule] = {
        func rx(_ p: String, _ opts: NSRegularExpression.Options = []) -> NSRegularExpression {
            try! NSRegularExpression(pattern: p, options: opts)
        }
        let kw = "\\b(" + keywords.joined(separator: "|") + ")\\b"
        return [
            // Comments
            Rule(regex: rx("%%.*$", [.anchorsMatchLines]), color: c(0.42, 0.46, 0.51)),
            // Keywords
            Rule(regex: rx(kw), color: c(0.49, 0.18, 0.74)),
            // Arrows / links
            Rule(regex: rx("(-{1,3}>|={1,3}>|-\\.->|--x|--o|<-{1,3}|\\.\\.>|==>|--|-\\.-|o--o|x--x|\\|)"), color: c(0.78, 0.15, 0.47)),
            // Strings
            Rule(regex: rx("\"[^\"]*\""), color: c(0.69, 0.13, 0.13)),
            // Node text in brackets/braces/parens
            Rule(regex: rx("[\\[\\]{}()]"), color: c(0.0, 0.45, 0.6)),
            // Numbers
            Rule(regex: rx("\\b\\d+(\\.\\d+)?\\b"), color: c(0.6, 0.36, 0.0))
        ]
    }()

    static func apply(to storage: NSTextStorage, font: NSFont) {
        let full = NSRange(location: 0, length: storage.length)
        let text = storage.string
        storage.beginEditing()
        storage.setAttributes([
            .font: font,
            .foregroundColor: baseColor
        ], range: full)
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

// MARK: - Line number ruler

final class LineNumberRulerView: NSRulerView {
    var font: NSFont = .monospacedSystemFont(ofSize: 11, weight: .regular) {
        didSet { needsDisplay = true }
    }

    init(textView: NSTextView) {
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        self.clientView = textView
        self.ruleThickness = 40
    }

    required init(coder: NSCoder) { fatalError() }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = clientView as? NSTextView,
              let layoutManager = textView.layoutManager,
              let container = textView.textContainer else { return }

        let bg = NSColor.textBackgroundColor.blended(withFraction: 0.04, of: .labelColor) ?? .textBackgroundColor
        bg.setFill()
        rect.fill()

        let content = textView.string as NSString
        let visibleRect = textView.visibleRect
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: container)
        let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: max(9, font.pointSize - 2), weight: .regular),
            .foregroundColor: NSColor.tertiaryLabelColor
        ]

        // Determine starting line number
        var lineNumber = 1
        content.enumerateSubstrings(in: NSRange(location: 0, length: charRange.location), options: .byLines) { _, _, _, _ in
            lineNumber += 1
        }

        let inset = textView.textContainerInset.height
        var index = charRange.location

        while index <= NSMaxRange(charRange) && index <= content.length {
            let lineRange = content.lineRange(for: NSRange(location: index, length: 0))
            let rectArray = layoutManager.boundingRect(
                forGlyphRange: layoutManager.glyphRange(forCharacterRange: lineRange, actualCharacterRange: nil),
                in: container)
            let y = rectArray.minY + inset - visibleRect.minY
            let label = "\(lineNumber)" as NSString
            let size = label.size(withAttributes: attrs)
            label.draw(at: NSPoint(x: ruleThickness - size.width - 5, y: y + (rectArray.height - size.height) / 2),
                       withAttributes: attrs)

            lineNumber += 1
            if lineRange.length == 0 { break }
            index = NSMaxRange(lineRange)
            if index == content.length {
                // handle trailing newline producing an extra empty line
                if content.length > 0 && content.character(at: content.length - 1) == 10 {
                    let extraY = layoutManager.usedRect(for: container).maxY + inset - visibleRect.minY
                    ("\(lineNumber)" as NSString).draw(
                        at: NSPoint(x: ruleThickness - ("\(lineNumber)" as NSString).size(withAttributes: attrs).width - 5,
                                    y: extraY),
                        withAttributes: attrs)
                }
                break
            }
        }
    }
}
