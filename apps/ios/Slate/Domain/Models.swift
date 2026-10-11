import Foundation

struct User: Codable, Sendable, Equatable { let id: String; let email: String; let displayName: String }
struct AuthResponse: Codable, Sendable { let token: String; let user: User }
struct Client: Codable, Sendable, Identifiable, Equatable { let id: String; let name: String; let email: String; let phone: String? }
enum ProjectStatus: String, Codable, Sendable, CaseIterable { case draft = "DRAFT", confirmed = "CONFIRMED", inProgress = "IN_PROGRESS", readyForDelivery = "READY_FOR_DELIVERY", delivered = "DELIVERED", completed = "COMPLETED", cancelled = "CANCELLED" }
enum InvoiceStatus: String, Codable, Sendable { case draft = "DRAFT", issued = "ISSUED", paid = "PAID", void = "VOID" }
struct Deliverable: Codable, Sendable, Identifiable { let id: String; let title: String; let type: String; let expectedQuantity: Int }
struct Activity: Codable, Sendable, Identifiable { let id: String; let action: String; let createdAt: Date }
struct InvoiceItem: Codable, Sendable, Identifiable { let id: String; let description: String; let quantity: Int; let unitPriceMinor: Int64; let lineTotalMinor: Int64 }
struct Payment: Codable, Sendable, Identifiable { let id: String; let status: String; let provider: String; let createdAt: Date; let amountMinor: Int64 }
struct Invoice: Codable, Sendable, Identifiable { let id: String; let invoiceNumber: String; let status: InvoiceStatus; let totalMinor: Int64; let currency: String; let dueAt: Date?; let paidAt: Date?; let items: [InvoiceItem]; let payments: [Payment] }
struct MediaAsset: Codable, Sendable, Identifiable { let id: String; let filename: String; let mimeType: String; let sizeBytes: Int64; let status: String; let contentHash: String; let verifiedAt: Date?; let previewURL: URL? }
struct Project: Codable, Sendable, Identifiable { let id: String; let title: String; let description: String; let status: ProjectStatus; let currency: String; let version: Int; let createdAt: Date; let client: Client; let deliverables: [Deliverable]; let invoice: Invoice?; let media: [MediaAsset]; let deliveryStatus: String; let activity: [Activity] }
struct DeliverableDraft: Codable, Sendable { var title: String; var type: String; var expectedQuantity: Int }
struct ProjectDraft: Codable, Sendable { var title: String; var description: String; var clientId: String; var deliverables: [DeliverableDraft] }
struct InvoiceItemDraft: Codable, Sendable { var description: String; var quantity: Int; var unitPriceMinor: Int64 }
struct ShareLink: Codable, Sendable { let token: String; let url: URL }
struct DeliveryResult: Codable, Sendable { let status: String }
struct OKResponse: Codable, Sendable { let ok: Bool }
struct TransferSession: Codable, Sendable {
    let id: String
    let mediaAssetId: String
    let status: String
    let totalBytes: Int64
    let partSize: Int64
    let parts: [TransferPart]
    let expiresAt: Date
    /// The object exists in private storage and needs server-side digest verification.
    var isAwaitingVerification: Bool { status == "VERIFYING" || status == "COMPLETED" }
}
struct TransferPart: Codable, Sendable { let partNumber: Int; let sizeBytes: Int64; let storageETag: String }
struct SignedPart: Codable, Sendable { let url: URL }
struct CompletedTransfer: Codable, Sendable { let mediaAsset: MediaAsset }

/// Supports both PostgreSQL fractional timestamps and whole-second ISO8601.
enum JSONCoding {
    static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            let fractional = ISO8601DateFormatter(); fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractional.date(from: text) ?? ISO8601DateFormatter().date(from: text) { return date }
            throw DecodingError.dataCorruptedError(in: try decoder.singleValueContainer(), debugDescription: "Invalid ISO8601 date")
        }
        return d
    }
    static func encoder() -> JSONEncoder { let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; e.outputFormatting = [.sortedKeys]; return e }
}
