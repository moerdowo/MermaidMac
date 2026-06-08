import SwiftUI

enum MermaidTheme: String, CaseIterable, Identifiable {
    case `default`, dark, forest, neutral, base
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

final class AppSettings: ObservableObject {
    @AppStorage("mermaidTheme") var theme: String = MermaidTheme.default.rawValue
    @AppStorage("autoRender") var autoRender: Bool = true
    @AppStorage("renderDelay") var renderDelay: Double = 0.4
    @AppStorage("editorFontSize") var editorFontSize: Double = 13
    @AppStorage("wrapLines") var wrapLines: Bool = false
    @AppStorage("showLineNumbers") var showLineNumbers: Bool = true
    @AppStorage("previewBackground") var previewBackground: String = "auto" // auto | white | dark | transparent
    @AppStorage("exportScale") var exportScale: Double = 2

    var mermaidTheme: MermaidTheme {
        get { MermaidTheme(rawValue: theme) ?? .default }
        set { theme = newValue.rawValue }
    }
}
