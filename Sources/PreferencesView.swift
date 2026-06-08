import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        TabView {
            editorTab
                .tabItem { Label("Editor", systemImage: "text.alignleft") }
            previewTab
                .tabItem { Label("Preview", systemImage: "eye") }
        }
        .frame(width: 420, height: 320)
    }

    private var editorTab: some View {
        Form {
            Slider(value: $settings.editorFontSize, in: 9...24, step: 1) {
                Text("Font size: \(Int(settings.editorFontSize)) pt")
            }
            Toggle("Wrap long lines", isOn: $settings.wrapLines)
            Toggle("Show line numbers", isOn: $settings.showLineNumbers)
        }
        .padding(20)
    }

    private var previewTab: some View {
        Form {
            Picker("Theme", selection: $settings.theme) {
                ForEach(MermaidTheme.allCases) { Text($0.label).tag($0.rawValue) }
            }
            Picker("Background", selection: $settings.previewBackground) {
                Text("Auto").tag("auto")
                Text("White").tag("white")
                Text("Dark").tag("dark")
                Text("Transparent").tag("transparent")
            }
            Toggle("Render automatically while typing", isOn: $settings.autoRender)
            if settings.autoRender {
                Slider(value: $settings.renderDelay, in: 0.1...2.0, step: 0.1) {
                    Text("Render delay: \(settings.renderDelay, specifier: "%.1f") s")
                }
            }
            Picker("Export scale", selection: $settings.exportScale) {
                Text("1×").tag(1.0)
                Text("2×").tag(2.0)
                Text("3×").tag(3.0)
                Text("4×").tag(4.0)
            }
        }
        .padding(20)
    }
}
