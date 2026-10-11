import Foundation

enum TransferState: String, Codable, Sendable, CaseIterable {
    case queued, preparing, ready, uploading, paused, retryWaiting, verifying, completed, failed, cancelled
    var isTerminal: Bool { self == .completed || self == .cancelled }
    func canTransition(to next: TransferState) -> Bool {
        if self == next { return true }
        switch self {
        case .queued: return [.preparing, .paused, .cancelled, .failed].contains(next)
        case .preparing: return [.ready, .uploading, .retryWaiting, .paused, .failed, .cancelled].contains(next)
        case .ready: return [.uploading, .verifying, .paused, .retryWaiting, .failed, .cancelled].contains(next)
        case .uploading: return [.ready, .paused, .retryWaiting, .verifying, .failed, .cancelled].contains(next)
        case .paused: return [.ready, .cancelled].contains(next)
        case .retryWaiting: return [.ready, .uploading, .verifying, .failed, .paused, .cancelled].contains(next)
        case .verifying: return [.completed, .retryWaiting, .failed, .paused, .cancelled].contains(next)
        case .failed: return [.ready, .cancelled].contains(next)
        case .completed, .cancelled: return false
        }
    }
}
struct TransferRecord: Codable, Sendable, Identifiable {
    let id: String
    let ownerID: String
    let projectID: String
    let file: ImportedMedia
    let createdAt: Date
    var state: TransferState
    var session: TransferSession?
    var uploadedBytes: Int64
    var retryCount: Int
    var nextRetryAt: Date?
    var error: String?
    var bindings: [PartBinding]
    let createKey: String
    let completeKey: String
    let cancelKey: String
    var cancelConfirmed: Bool?
    var filename: String { file.filename }
    var totalBytes: Int64 { file.sizeBytes }
    var progress: Double {
        let confirmed = Set(session?.parts.map(\.partNumber) ?? [])
        let sending = bindings.filter { !confirmed.contains($0.partNumber) }.reduce(Int64(0)) { $0 + min($1.sentBytes, $1.sizeBytes) }
        return totalBytes == 0 ? 0 : min(1, Double(uploadedBytes + sending) / Double(totalBytes))
    }
}
struct PartBinding: Codable, Sendable {
    let taskIdentifier: Int
    let partNumber: Int
    let fileURL: URL
    let sizeBytes: Int64
    var sentBytes: Int64
}
enum RetryPolicy {
    static let maximumAttempts = 6
    static func delay(attempt: Int, retryAfter: TimeInterval? = nil, random: Double = Double.random(in: 0...1)) -> TimeInterval { max(retryAfter ?? 0, min(300, pow(2, Double(max(0, attempt)))) * (0.5 + min(1, max(0, random)) * 0.5)) }
    static func retryAfter(_ value: String?, now: Date = Date()) -> TimeInterval? {
        guard let value else { return nil }
        if let seconds = Double(value) { return max(0, seconds) }
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = TimeZone(secondsFromGMT: 0); formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
        return formatter.date(from: value).map { max(0, $0.timeIntervalSince(now)) }
    }
}
