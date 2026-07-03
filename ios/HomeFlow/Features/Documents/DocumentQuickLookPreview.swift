import Foundation
import QuickLook
import SwiftUI

// @covers FR-HOME-03, AC-HOME-13

enum DocumentPreviewLoader {
    static func prepareLocalFile(document: DocumentSummary, remoteURL: URL) async throws -> URL {
        let (data, _) = try await URLSession.shared.data(from: remoteURL)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("document-previews", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent(localFileName(for: document))
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    static func localFileName(for document: DocumentSummary) -> String {
        if let path = document.storagePath {
            let name = (path as NSString).lastPathComponent
            if !name.isEmpty { return name }
        }
        let ext = document.fileExtension?.lowercased() ?? "dat"
        return "\(document.id.uuidString).\(ext)"
    }
}

struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: QLPreviewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        private let item: PreviewItem

        init(url: URL) {
            item = PreviewItem(url: url)
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }

        func previewController(
            _ controller: QLPreviewController,
            previewItemAt index: Int
        ) -> QLPreviewItem {
            item
        }
    }
}

private final class PreviewItem: NSObject, QLPreviewItem {
    let previewItemURL: URL?

    init(url: URL) {
        previewItemURL = url
    }
}
