import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let mermaid = UTType(exportedAs: "com.moerdowo.mermaid")
}

@main
struct MermaidMacApp: App {
    @StateObject private var settings = AppSettings()

    var body: some Scene {
        DocumentGroup(newDocument: MermaidDocument()) { config in
            ContentView(document: config.$document, fileURL: config.fileURL)
                .environmentObject(settings)
                .frame(minWidth: 760, minHeight: 480)
        }
        .commands {
            MermaidCommands()
        }

        Settings {
            PreferencesView()
                .environmentObject(settings)
        }
    }
}
