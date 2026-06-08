import SwiftUI
import AppKit

struct ContentView: View {
    @Binding var document: MermaidDocument
    var fileURL: URL?
    @EnvironmentObject var settings: AppSettings

    @StateObject private var preview = PreviewController()
    @State private var renderTask: Task<Void, Never>?
    @State private var cursorLine: Int = 1
    @State private var showTemplates = false

    private var background: String {
        switch settings.previewBackground {
        case "white": return "white"
        case "dark": return "dark"
        case "transparent": return "transparent"
        default: // auto -> follow theme
            return settings.mermaidTheme == .dark ? "dark" : "white"
        }
    }

    var body: some View {
        HSplitView {
            editorPane
                .frame(minWidth: 280)
            previewPane
                .frame(minWidth: 280)
        }
        .toolbar { toolbarContent }
        .focusedSceneValue(\.previewActions, makeActions())
        .onAppear { scheduleRender(immediate: true) }
        .onChange(of: document.text) { scheduleRender() }
        .onChange(of: settings.theme) { scheduleRender(immediate: true) }
        .onChange(of: settings.previewBackground) { scheduleRender(immediate: true) }
        .onChange(of: settings.autoRender) { if settings.autoRender { scheduleRender(immediate: true) } }
    }

    // MARK: - Panes

    private var editorPane: some View {
        VStack(spacing: 0) {
            CodeEditor(
                text: $document.text,
                fontSize: settings.editorFontSize,
                wrapLines: settings.wrapLines,
                showLineNumbers: settings.showLineNumbers,
                onCursorChange: { cursorLine = $0 }
            )
            Divider()
            statusBar
        }
    }

    private var previewPane: some View {
        ZStack(alignment: .topTrailing) {
            MermaidWebView(controller: preview)
            previewOverlay
        }
        .overlay(alignment: .bottom) { errorBanner }
    }

    @ViewBuilder
    private var errorBanner: some View {
        if case let .error(message) = preview.status {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.white)
                Text(message)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .textSelection(.enabled)
                Spacer(minLength: 0)
            }
            .padding(10)
            .background(.red.opacity(0.9), in: RoundedRectangle(cornerRadius: 8))
            .shadow(radius: 6, y: 2)
            .padding(10)
            .frame(maxWidth: 520)
            .allowsHitTesting(false)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var previewOverlay: some View {
        HStack(spacing: 2) {
            overlayButton("minus.magnifyingglass") { preview.zoomOut() }
            Text("\(Int(preview.zoomScale * 100))%")
                .font(.system(size: 11, design: .monospaced))
                .frame(width: 42)
                .foregroundStyle(.secondary)
            overlayButton("plus.magnifyingglass") { preview.zoomIn() }
            Divider().frame(height: 16)
            overlayButton("arrow.up.left.and.arrow.down.right") { preview.fitToWindow() }
            overlayButton("1.magnifyingglass") { preview.resetZoom() }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.primary.opacity(0.08)))
        .padding(10)
    }

    private func overlayButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 22, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Status bar

    private var statusBar: some View {
        HStack(spacing: 12) {
            statusIndicator
            Spacer()
            Text(diagramKind)
                .foregroundStyle(.secondary)
            Text("Ln \(cursorLine)")
                .foregroundStyle(.secondary)
            Text("\(document.text.count) chars")
                .foregroundStyle(.secondary)
        }
        .font(.system(size: 11))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.bar)
    }

    @ViewBuilder
    private var statusIndicator: some View {
        switch preview.status {
        case .loading:
            Label("Loading…", systemImage: "circle.dotted").foregroundStyle(.secondary)
        case .ok:
            Label("Rendered", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        case .empty:
            Label("Empty", systemImage: "circle").foregroundStyle(.secondary)
        case .error:
            Label("Syntax error", systemImage: "xmark.octagon.fill").foregroundStyle(.red)
        }
    }

    private var diagramKind: String {
        let firstLine = document.text
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first(where: { !$0.isEmpty && !$0.hasPrefix("%%") }) ?? ""
        let token = firstLine.split(separator: " ").first.map(String.init) ?? ""
        return token.isEmpty ? "—" : token
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Menu {
                ForEach(MermaidTemplate.all) { tpl in
                    Button {
                        insert(template: tpl.code)
                    } label: {
                        Label(tpl.name, systemImage: tpl.symbol)
                    }
                }
            } label: {
                Label("Templates", systemImage: "plus.rectangle.on.rectangle")
            }
            .help("Insert a diagram template")
        }

        ToolbarItemGroup(placement: .primaryAction) {
            Picker("Theme", selection: $settings.theme) {
                ForEach(MermaidTheme.allCases) { t in
                    Text(t.label).tag(t.rawValue)
                }
            }
            .pickerStyle(.menu)
            .help("Mermaid theme")

            Menu {
                Picker("Background", selection: $settings.previewBackground) {
                    Text("Auto").tag("auto")
                    Text("White").tag("white")
                    Text("Dark").tag("dark")
                    Text("Transparent").tag("transparent")
                }
                .pickerStyle(.inline)
            } label: {
                Label("Background", systemImage: "square.on.square.dashed")
            }

            if !settings.autoRender {
                Button { scheduleRender(immediate: true) } label: {
                    Label("Render", systemImage: "play.fill")
                }
                .help("Render now")
            }

            Menu {
                Button("Export SVG…") { exportSVG() }
                Button("Export PNG…") { exportPNG() }
                Divider()
                Button("Copy Image") { copyImage() }
                Button("Copy SVG Code") { copySVG() }
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .help("Export the diagram")
        }
    }

    // MARK: - Rendering

    private func scheduleRender(immediate: Bool = false) {
        renderTask?.cancel()
        let code = document.text
        let theme = settings.mermaidTheme.rawValue
        let bg = background
        if immediate || !settings.autoRender && immediate {
            preview.render(code: code, theme: theme, background: bg)
            return
        }
        if !settings.autoRender { return }
        let delay = settings.renderDelay
        renderTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            if Task.isCancelled { return }
            await MainActor.run {
                preview.render(code: code, theme: theme, background: bg)
            }
        }
    }

    // MARK: - Template insertion

    private func insert(template: String) {
        // A Mermaid file holds a single diagram, so a template replaces the
        // current content rather than appending (appending two diagram types
        // into one document is invalid Mermaid and fails to render).
        let current = document.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let isReplaceable = current.isEmpty
            || document.text == MermaidTemplate.welcome
            || current.hasPrefix("%% Welcome")

        if !isReplaceable {
            let alert = NSAlert()
            alert.messageText = "Replace the current diagram?"
            alert.informativeText = "Inserting a template will replace the editor contents. This can be undone."
            alert.addButton(withTitle: "Replace")
            alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }

        document.text = template
        scheduleRender(immediate: true)
    }

    // MARK: - Export helpers

    private func defaultName(ext: String) -> String {
        let base = fileURL?.deletingPathExtension().lastPathComponent ?? "diagram"
        return "\(base).\(ext)"
    }

    private func exportSVG() {
        preview.exportSVG { svg in
            guard let svg, !svg.isEmpty else { return }
            savePanel(ext: "svg") { url in
                try? svg.data(using: .utf8)?.write(to: url)
            }
        }
    }

    private func exportPNG() {
        preview.exportPNG(scale: settings.exportScale) { data in
            guard let data else { return }
            savePanel(ext: "png") { url in
                try? data.write(to: url)
            }
        }
    }

    private func copyImage() {
        preview.exportPNG(scale: settings.exportScale) { data in
            guard let data, let image = NSImage(data: data) else { return }
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.writeObjects([image])
        }
    }

    private func copySVG() {
        preview.exportSVG { svg in
            guard let svg, !svg.isEmpty else { return }
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(svg, forType: .string)
        }
    }

    private func savePanel(ext: String, write: @escaping (URL) -> Void) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = defaultName(ext: ext)
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.begin { response in
            if response == .OK, let url = panel.url {
                write(url)
            }
        }
    }

    // MARK: - Focused actions for menu commands

    private func makeActions() -> PreviewActions {
        PreviewActions(
            zoomIn: { preview.zoomIn() },
            zoomOut: { preview.zoomOut() },
            resetZoom: { preview.resetZoom() },
            fitToWindow: { preview.fitToWindow() },
            renderNow: { scheduleRender(immediate: true) },
            exportSVG: exportSVG,
            exportPNG: exportPNG,
            copyImage: copyImage,
            copySVG: copySVG
        )
    }
}
