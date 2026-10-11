import Foundation
import CryptoKit
import UniformTypeIdentifiers
import ImageIO
import AVFoundation

struct ImportedMedia: Codable, Sendable {
    let fileURL: URL
    let filename: String
    let mimeType: String
    let sizeBytes: Int64
    let contentHash: String
    let pixelWidth: Int?
    let pixelHeight: Int?
    let duration: Double?
}
struct MediaImportError: Error, LocalizedError { let message: String; var errorDescription: String? { message } }
struct MediaImporter: Sendable {
    static let supportedMIMETypes: Set<String> = ["image/jpeg", "image/png", "image/webp", "image/heic", "image/heif", "video/mp4", "video/quicktime", "application/pdf"]
    let root: URL
    init(root: URL? = nil) throws {
        self.root = try root ?? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("Slate/Staging", isDirectory: true)
        try FileManager.default.createDirectory(at: self.root, withIntermediateDirectories: true)
        var excluded = self.root; var values = URLResourceValues(); values.isExcludedFromBackup = true; try excluded.setResourceValues(values)
    }
    /// Call inside NSItemProvider's file callback; its temporary URL expires when that callback returns.
    func copyTemporaryFile(_ source: URL, filename: String, mimeType: String) throws -> URL {
        guard Self.supportedMIMETypes.contains(mimeType) else { throw MediaImportError(message: "Use JPEG, PNG, WebP, HEIF, MP4, MOV or PDF files.") }
        let destination = root.appendingPathComponent(UUID().uuidString).appendingPathExtension(source.pathExtension)
        let scoped = source.startAccessingSecurityScopedResource(); defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        var coordinatorError: NSError?
        var copyError: Error?
        NSFileCoordinator().coordinate(readingItemAt: source, options: [], error: &coordinatorError) { coordinated in
            do { try FileManager.default.copyItem(at: coordinated, to: destination) } catch { copyError = error }
        }
        if let error = coordinatorError ?? copyError as NSError? { throw error }
        do { try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: destination.path) }
        catch { try? FileManager.default.removeItem(at: destination); throw error }
        return destination
    }
    func inspect(_ fileURL: URL, filename: String, mimeType: String) async throws -> ImportedMedia {
        try await Task.detached(priority: .utility) {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            let size = (attributes[.size] as? NSNumber)?.int64Value ?? 0
            guard Self.supportedMIMETypes.contains(mimeType), size > 0, size <= 8 * 1024 * 1024 * 10_000 else { throw MediaImportError(message: "Select a supported, nonempty file under 80 GiB.") }
            let hash = try Self.sha256(fileURL)
            var width: Int?, height: Int?, duration: Double?
            if mimeType.hasPrefix("image/"), let source = CGImageSourceCreateWithURL(fileURL as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary), let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] { width = properties[kCGImagePropertyPixelWidth] as? Int; height = properties[kCGImagePropertyPixelHeight] as? Int }
            if mimeType.hasPrefix("video/") { let time = try await AVURLAsset(url: fileURL).load(.duration); duration = time.seconds.isFinite ? time.seconds : nil }
            return ImportedMedia(fileURL: fileURL, filename: URL(fileURLWithPath: filename).lastPathComponent, mimeType: mimeType, sizeBytes: size, contentHash: hash, pixelWidth: width, pixelHeight: height, duration: duration)
        }.value
    }
    static func sha256(_ url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
        var hasher = SHA256()
        while let data = try handle.read(upToCount: 1024 * 1024), !data.isEmpty { hasher.update(data: data) }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
    func remove(_ url: URL) throws {
        guard url.deletingLastPathComponent().standardizedFileURL == root.standardizedFileURL else { throw MediaImportError(message: "File is outside Slate staging.") }
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }
    func partFile(source: URL, recordID: String, part: Int, partSize: Int64, totalBytes: Int64) async throws -> URL {
        let destination = root.appendingPathComponent("\(recordID)-part-\(part)")
        return try await Task.detached(priority: .utility) {
            let offset = Int64(part - 1) * partSize
            let size = min(partSize, totalBytes - offset)
            guard part > 0, size > 0, partSize > 0 else { throw MediaImportError(message: "Invalid multipart size.") }
            let input = try FileHandle(forReadingFrom: source); defer { try? input.close() }
            try input.seek(toOffset: UInt64(offset))
            let temporary = destination.appendingPathExtension("tmp")
            FileManager.default.createFile(atPath: temporary.path, contents: nil)
            let output = try FileHandle(forWritingTo: temporary)
            do {
                var remaining = size
                while remaining > 0 {
                    guard let data = try input.read(upToCount: Int(min(remaining, 1024 * 1024))), !data.isEmpty else { throw MediaImportError(message: "Staged source is truncated.") }
                    try output.write(contentsOf: data); remaining -= Int64(data.count)
                }
                try output.close()
                if FileManager.default.fileExists(atPath: destination.path) { try FileManager.default.removeItem(at: destination) }
                try FileManager.default.moveItem(at: temporary, to: destination)
                try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: destination.path)
                return destination
            } catch { try? output.close(); try? FileManager.default.removeItem(at: temporary); throw error }
        }.value
    }
}
