import SwiftUI

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
