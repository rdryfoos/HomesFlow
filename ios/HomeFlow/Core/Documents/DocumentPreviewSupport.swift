import Foundation
import UIKit

// @covers AC-HOME-13, AC-HOME-14

enum DocumentPreviewIcon {
    static func symbol(for fileExtension: String?) -> String {
        switch fileExtension?.lowercased() {
        case "jpg", "jpeg", "png", "gif", "heic", "heif", "webp", "bmp", "tiff":
            return "photo"
        case "pdf":
            return "doc.richtext"
        case "mp4", "mov", "m4v":
            return "film"
        case "mp3", "m4a", "wav", "aac":
            return "waveform"
        case "txt", "md", "rtf":
            return "doc.text"
        default:
            return "doc.fill"
        }
    }
}

enum DocumentUploadFlow {
    struct Pick: Equatable, Sendable {
        let data: Data
        let fileName: String
    }

    enum Source: String, CaseIterable, Sendable {
        case camera
        case photoLibrary
        case fileBrowser
    }

    /// AC-HOME-14: camera (when available), photo library, and file browser.
    static func offeredSources(cameraAvailable: Bool = UIImagePickerController.isSourceTypeAvailable(.camera)) -> [Source] {
        var sources: [Source] = [.photoLibrary, .fileBrowser]
        if cameraAvailable {
            sources.insert(.camera, at: 0)
        }
        return sources
    }

    /// Applies a picked file into draft metadata; returns nil when data is missing.
    static func applyPick(
        to draft: inout DocumentDraft,
        data: Data?,
        fileName: String
    ) -> Pick? {
        guard let data, !data.isEmpty else { return nil }
        if draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            draft.title = (fileName as NSString).deletingPathExtension
        }
        return Pick(data: data, fileName: fileName)
    }

    static func cameraFileName(date: Date = .now) -> String {
        let stamp = date.formatted(.iso8601.year().month().day())
        return "Photo \(stamp).jpg"
    }
}
