import SwiftUI
import AppKit

/// Drives the focused NSTextView's find bar by sending the standard text-finder
/// action down the responder chain with the appropriate tag.
private func textFinder(_ action: NSTextFinder.Action) {
    let item = NSMenuItem()
    item.tag = Int(action.rawValue)
    NSApp.sendAction(#selector(NSTextView.performTextFinderAction(_:)), to: nil, from: item)
}

struct PreviewActions {
    var zoomIn: () -> Void
    var zoomOut: () -> Void
    var resetZoom: () -> Void
    var fitToWindow: () -> Void
    var renderNow: () -> Void
    var exportSVG: () -> Void
    var exportPNG: () -> Void
    var copyImage: () -> Void
    var copySVG: () -> Void
}

private struct PreviewActionsKey: FocusedValueKey {
    typealias Value = PreviewActions
}

extension FocusedValues {
    var previewActions: PreviewActions? {
        get { self[PreviewActionsKey.self] }
        set { self[PreviewActionsKey.self] = newValue }
    }
}

struct MermaidCommands: Commands {
    @FocusedValue(\.previewActions) private var actions

    var body: some Commands {
        CommandGroup(after: .importExport) {
            Divider()
            Button("Export as SVG…") { actions?.exportSVG() }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(actions == nil)
            Button("Export as PNG…") { actions?.exportPNG() }
                .keyboardShortcut("e", modifiers: [.command, .option])
                .disabled(actions == nil)
            Button("Copy Image") { actions?.copyImage() }
                .disabled(actions == nil)
            Button("Copy SVG Code") { actions?.copySVG() }
                .disabled(actions == nil)
        }

        CommandGroup(after: .textEditing) {
            Divider()
            Button("Find…") { textFinder(.showFindInterface) }
                .keyboardShortcut("f", modifiers: [.command])
            Button("Find and Replace…") { textFinder(.showReplaceInterface) }
                .keyboardShortcut("f", modifiers: [.command, .option])
            Button("Find Next") { textFinder(.nextMatch) }
                .keyboardShortcut("g", modifiers: [.command])
            Button("Find Previous") { textFinder(.previousMatch) }
                .keyboardShortcut("g", modifiers: [.command, .shift])
            Button("Use Selection for Find") { textFinder(.setSearchString) }
                .keyboardShortcut("e", modifiers: [.command])
        }

        CommandMenu("Diagram") {
            Button("Render Now") { actions?.renderNow() }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(actions == nil)
            Divider()
            Button("Zoom In") { actions?.zoomIn() }
                .keyboardShortcut("+", modifiers: [.command])
                .disabled(actions == nil)
            Button("Zoom Out") { actions?.zoomOut() }
                .keyboardShortcut("-", modifiers: [.command])
                .disabled(actions == nil)
            Button("Actual Size") { actions?.resetZoom() }
                .keyboardShortcut("0", modifiers: [.command])
                .disabled(actions == nil)
            Button("Fit to Window") { actions?.fitToWindow() }
                .keyboardShortcut("9", modifiers: [.command])
                .disabled(actions == nil)
        }

        CommandGroup(replacing: .help) {
            Link("Mermaid Syntax Documentation",
                 destination: URL(string: "https://mermaid.js.org/intro/")!)
        }
    }
}
