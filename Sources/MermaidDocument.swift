import SwiftUI
import UniformTypeIdentifiers

struct MermaidDocument: FileDocument {
    var text: String

    init(text: String = MermaidTemplate.welcome) {
        self.text = text
    }

    static var readableContentTypes: [UTType] {
        [.mermaid, .plainText, .text]
    }

    static var writableContentTypes: [UTType] {
        [.mermaid, .plainText]
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text = string
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = Data(text.utf8)
        return FileWrapper(regularFileWithContents: data)
    }
}
