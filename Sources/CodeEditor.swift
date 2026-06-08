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
        // Canonical TextKit 1 stack. We build the storage/layout/container
        // ourselves: scrollableTextView() sizes correctly but forcing it to
        // TextKit 1 (needed for the ruler) broke glyph drawing. An explicit
        // NSLayoutManager both draws glyphs reliably and powers the ruler.
        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let contentSize = scrollView.contentSize
        let storage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        storage.addLayoutManager(layoutManager)
        let container = NSTextContainer(size: NSSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        layoutManager.addTextContainer(container)

        let textView = NSTextView(frame: NSRect(origin: .zero, size: contentSize), textContainer: container)
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.minSize = NSSize(width: 0, height: contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        // Inside SwiftUI's layer-backed hierarchy the text view's layer content
        // wasn't being refreshed, so glyphs never composited on screen even
        // though drawRect produced them. Force the layer to redraw on display
        // and stop the clip view from caching a stale (empty) document.
        textView.layerContentsRedrawPolicy = .onSetNeedsDisplay
        scrollView.documentView = textView
        scrollView.contentView.copiesOnScroll = false
        // Force the text view + clip subtree to render through drawRect into a
        // single layer. Without this, in SwiftUI's layer-backed hierarchy the
        // text view's glyphs are drawn to a bitmap on demand but never make it
        // into the on-screen layer, leaving the editor blank.
        scrollView.wantsLayer = true
        scrollView.canDrawSubviewsIntoLayer = true

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
        textView.drawsBackground = true
        textView.backgroundColor = MermaidHighlighter.backgroundColor
        textView.textColor = MermaidHighlighter.baseColor
        textView.insertionPointColor = MermaidHighlighter.baseColor
        textView.selectedTextAttributes = [.backgroundColor: MermaidHighlighter.selectionColor]
        textView.font = NSFont.monospacedSystemFont(ofSize: CGFloat(fontSize), weight: .regular)

        textView.string = text

        context.coordinator.textView = textView

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
            guard let container = tv.textContainer, let scroll = tv.enclosingScrollView else { return }
            let visibleWidth = scroll.contentSize.width
            if wrap {
                container.widthTracksTextView = true
                container.containerSize = NSSize(width: visibleWidth, height: CGFloat.greatestFiniteMagnitude)
                tv.isHorizontallyResizable = false
                tv.autoresizingMask = [.width]
                scroll.hasHorizontalScroller = false
                tv.setFrameSize(NSSize(width: visibleWidth, height: tv.frame.height))
            } else {
                container.widthTracksTextView = false
                container.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
                tv.isHorizontallyResizable = true
                tv.autoresizingMask = [.width, .height]
                tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
                scroll.hasHorizontalScroller = true
            }
            tv.sizeToFit()
            tv.needsDisplay = true
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
            if let container = tv.textContainer {
                tv.layoutManager?.ensureLayout(for: container)
            }
            tv.needsDisplay = true
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

    // Tokyo Night palette — a dark editor theme with high-contrast tokens.
    static func hex(_ v: Int) -> NSColor {
        NSColor(srgbRed: Double((v >> 16) & 0xff) / 255.0,
                green: Double((v >> 8) & 0xff) / 255.0,
                blue: Double(v & 0xff) / 255.0,
                alpha: 1)
    }
    static let backgroundColor = hex(0x1a1b26)   // editor background
    static let baseColor       = hex(0xc0caf5)   // default text (light lavender)
    static let gutterBackground = hex(0x16161e)  // line-number gutter
    static let gutterText       = hex(0x565f89)  // line numbers
    static let selectionColor   = hex(0x283457)  // selection highlight

    private static let rules: [Rule] = {
        func rx(_ p: String, _ opts: NSRegularExpression.Options = []) -> NSRegularExpression {
            try! NSRegularExpression(pattern: p, options: opts)
        }
        let kw = "\\b(" + keywords.joined(separator: "|") + ")\\b"
        return [
            // Comments — muted blue-grey
            Rule(regex: rx("%%.*$", [.anchorsMatchLines]), color: hex(0x565f89)),
            // Keywords — purple
            Rule(regex: rx(kw), color: hex(0xbb9af7)),
            // Arrows / links — cyan
            Rule(regex: rx("(-{1,3}>|={1,3}>|-\\.->|--x|--o|<-{1,3}|\\.\\.>|==>|--|-\\.-|o--o|x--x|\\|)"), color: hex(0x89ddff)),
            // Strings — green
            Rule(regex: rx("\"[^\"]*\""), color: hex(0x9ece6a)),
            // Node delimiters — blue
            Rule(regex: rx("[\\[\\]{}()]"), color: hex(0x7aa2f7)),
            // Numbers — orange
            Rule(regex: rx("\\b\\d+(\\.\\d+)?\\b"), color: hex(0xff9e64))
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

        MermaidHighlighter.gutterBackground.setFill()
        rect.fill()

        let content = textView.string as NSString
        let visibleRect = textView.visibleRect
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: container)
        let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: max(9, font.pointSize - 2), weight: .regular),
            .foregroundColor: MermaidHighlighter.gutterText
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
