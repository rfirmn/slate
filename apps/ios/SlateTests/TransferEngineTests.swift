import XCTest
@testable import Slate

final class TransferEngineTests: XCTestCase {
    func testTerminalStatesCannotResumeAndPauseCanResume() {
        XCTAssertFalse(TransferState.completed.canTransition(to: .uploading))
        XCTAssertFalse(TransferState.cancelled.canTransition(to: .ready))
        XCTAssertTrue(TransferState.uploading.canTransition(to: .paused))
        XCTAssertTrue(TransferState.paused.canTransition(to: .ready))
        XCTAssertTrue(TransferState.verifying.canTransition(to: .failed))
    }
    func testRetryBackoffIsBoundedAndHonorsServerDelay() {
        XCTAssertEqual(RetryPolicy.delay(attempt: 1, random: 0), 1)
        XCTAssertEqual(RetryPolicy.delay(attempt: 30, random: 1), 300)
        XCTAssertEqual(RetryPolicy.delay(attempt: 1, retryAfter: 600, random: 0), 600)
        XCTAssertEqual(RetryPolicy.retryAfter("120"), 120)
        let now = Date(timeIntervalSince1970: 0)
        XCTAssertEqual(RetryPolicy.retryAfter("Thu, 01 Jan 1970 00:02:00 GMT", now: now), 120)
        XCTAssertNil(RetryPolicy.retryAfter("invalid"))
    }
    func testStreamingHashAndPartFilesPreserveExactBytes() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let importer = try MediaImporter(root: root)
        let source = root.appendingPathComponent("source.bin")
        try Data("abc".utf8).write(to: source)
        XCTAssertEqual(try MediaImporter.sha256(source), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        let first = try await importer.partFile(source: source, recordID: "sample", part: 1, partSize: 2, totalBytes: 3)
        let last = try await importer.partFile(source: source, recordID: "sample", part: 2, partSize: 2, totalBytes: 3)
        XCTAssertEqual(try Data(contentsOf: first), Data("ab".utf8))
        XCTAssertEqual(try Data(contentsOf: last), Data("c".utf8))
        XCTAssertThrowsError(try importer.remove(root.deletingLastPathComponent().appendingPathComponent("other")))
    }
    func testCoreDataBlobsAreAccountScopedAndSurviveReopening() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("test.sqlite")
        let store = try await LocalStore(storeURL: url)
        let alice = User(id: "alice", email: "alice@example.test", displayName: "Alice")
        let bob = User(id: "bob", email: "bob@example.test", displayName: "Bob")
        try await store.put(alice, key: "same-key", scope: "alice", kind: "user")
        try await store.put(bob, key: "same-key", scope: "bob", kind: "user")
        try await store.close()
        let reopened = try await LocalStore(storeURL: url)
        let a: [User] = try await reopened.values(scope: "alice", kind: "user")
        let b: [User] = try await reopened.values(scope: "bob", kind: "user")
        XCTAssertEqual(a, [alice]); XCTAssertEqual(b, [bob])
        try await reopened.remove(scope: "alice")
        let remaining: [User] = try await reopened.values(scope: "bob", kind: "user")
        XCTAssertEqual(remaining, [bob])
        try await reopened.close()
    }
    func testConcurrentUpsertsHaveOneDurableRecord() async throws {
        let store = try await LocalStore(inMemory: true)
        try await withThrowingTaskGroup(of: Void.self) { group in
            for number in 0..<10 {
                group.addTask { try await store.put(User(id: "same", email: "test@example.test", displayName: String(number)), key: "same", scope: "owner", kind: "user") }
            }
            try await group.waitForAll()
        }
        let users: [User] = try await store.values(scope: "owner", kind: "user")
        XCTAssertEqual(users.count, 1)
    }
    func testCancelledAndUnauthorizedRequestsDoNotBecomeOfflineSuccess() {
        XCTAssertFalse(ProjectRepository.isOffline(URLError(.cancelled)))
        XCTAssertFalse(ProjectRepository.isOffline(APIError(status: 401, message: "Unauthorized", retryAfter: nil)))
        XCTAssertTrue(ProjectRepository.isOffline(URLError(.notConnectedToInternet)))
        XCTAssertTrue(ProjectRepository.definitelyNotSent(URLError(.notConnectedToInternet)))
        XCTAssertTrue(ProjectRepository.definitelyNotSent(URLError(.cannotConnectToHost)))
        XCTAssertFalse(ProjectRepository.definitelyNotSent(URLError(.timedOut)))
        XCTAssertFalse(ProjectRepository.definitelyNotSent(URLError(.networkConnectionLost)))
        XCTAssertTrue(ProjectRepository.isOffline(APIError(status: 503, message: "Unavailable", retryAfter: nil)))
    }
    func testOlderDraftsRequireProofBeforeEditing() throws {
        let data = Data(#"{"id":"draft","payload":{"title":"Draft","description":"Offline","clientId":"client","deliverables":[]},"createdAt":"2026-10-11T00:00:00Z","attempts":1,"error":"Timeout"}"#.utf8)
        let draft = try JSONCoding.decoder().decode(PendingDraft.self, from: data)
        XCTAssertNil(draft.safeToEdit)
        XCTAssertFalse(draft.safeToEdit == true)
    }
    func testFractionalServerDatesDecode() throws {
        let activity = try JSONCoding.decoder().decode(Activity.self, from: Data(#"{"id":"event","action":"PAID","createdAt":"2026-10-11T00:00:00.123Z"}"#.utf8))
        XCTAssertEqual(activity.id, "event")
    }
    func testAssembledTransferResumesVerificationWithoutReuploadingParts() {
        let expiry = Date(timeIntervalSince1970: 1_800_000_000)
        let verifying = TransferSession(id: "session", mediaAssetId: "asset", status: "VERIFYING", totalBytes: 9, partSize: 8, parts: [], expiresAt: expiry)
        let completed = TransferSession(id: "session", mediaAssetId: "asset", status: "COMPLETED", totalBytes: 9, partSize: 8, parts: [], expiresAt: expiry)
        let uploading = TransferSession(id: "session", mediaAssetId: "asset", status: "UPLOADING", totalBytes: 9, partSize: 8, parts: [], expiresAt: expiry)
        XCTAssertTrue(verifying.isAwaitingVerification)
        XCTAssertTrue(completed.isAwaitingVerification)
        XCTAssertFalse(uploading.isAwaitingVerification)
    }
    func testTransferRecordRoundTripKeepsIdempotencyAndTaskBinding() throws {
        let file = ImportedMedia(fileURL: URL(fileURLWithPath: "/tmp/staged"), filename: "clip.mp4", mimeType: "video/mp4", sizeBytes: 10, contentHash: "abc", pixelWidth: nil, pixelHeight: nil, duration: nil)
        let record = TransferRecord(id: "queue", ownerID: "owner", projectID: "project", file: file, createdAt: Date(), state: .uploading, session: nil, uploadedBytes: 0, retryCount: 2, nextRetryAt: Date(), error: nil, bindings: [PartBinding(taskIdentifier: 91, partNumber: 1, fileURL: URL(fileURLWithPath: "/tmp/part"), sizeBytes: 10, sentBytes: 4)], createKey: "create-once", completeKey: "complete-once", cancelKey: "cancel-once")
        let decoded = try JSONCoding.decoder().decode(TransferRecord.self, from: JSONCoding.encoder().encode(record))
        XCTAssertEqual(decoded.createKey, "create-once"); XCTAssertEqual(decoded.completeKey, "complete-once")
        XCTAssertEqual(decoded.bindings.first?.taskIdentifier, 91)
        XCTAssertEqual(decoded.progress, 0.4, accuracy: 0.0001)
    }
}
