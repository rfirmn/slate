import Foundation

actor TransferCoordinator {
    private let api: APIClient
    private let store: LocalStore
    private let media: MediaImporter
    private let background: BackgroundTransferSession
    private var records: [String: TransferRecord] = [:]
    private var ownerID: String?
    private var scheduling = false
    private var scheduleRequested = false
    private var cellularAllowed = false
    private var retryWake: Task<Void, Never>?
    private var backgroundCompletion: (@MainActor @Sendable () -> Void)?
    private var finishedBackgroundEvents = false
    private let maximumConcurrentParts = 2
    init(api: APIClient, store: LocalStore, media: MediaImporter, backgroundIdentifier: String = BackgroundTransferSession.identifier) async {
        self.api = api; self.store = store; self.media = media; background = BackgroundTransferSession(identifier: backgroundIdentifier)
        let events = background.events
        Task { [weak self] in for await event in events { await self?.receive(event) } }
    }
    func transfers() -> [TransferRecord] { records.values.sorted { $0.createdAt < $1.createdAt } }
    func setCellularAllowed(_ allowed: Bool) async {
        let changed = cellularAllowed != allowed
        cellularAllowed = allowed
        UserDefaults.standard.set(allowed, forKey: "SlateCellularTransfers")
        // URLRequests retain cellular policy; recreate on a real preference change.
        if changed {
            for task in await background.tasks() { task.cancel() }
        }
        await schedule()
    }
    func handleBackgroundEvents(completion: @escaping @MainActor @Sendable () -> Void) async {
        backgroundCompletion = completion
        if finishedBackgroundEvents { await finishBackgroundEvents() }
    }
    func setAccount(ownerID newOwner: String?) async throws {
        if ownerID == newOwner { if newOwner != nil { try await restore() }; return }
        if ownerID != newOwner {
            retryWake?.cancel()
            if ownerID != nil || newOwner == nil { for task in await background.tasks() { task.cancel() } }
            records = [:]; ownerID = newOwner
        }
        guard let newOwner else { return }
        cellularAllowed = UserDefaults.standard.bool(forKey: "SlateCellularTransfers")
        let saved: [TransferRecord] = try await store.values(scope: newOwner, kind: "transfer")
        records = Dictionary(uniqueKeysWithValues: saved.map { ($0.id, $0) })
        try await restore()
    }
    func restore() async throws {
        guard let ownerID else { return }
        let tasks = await background.tasks()
        let liveIDs = Set(tasks.map(\.taskIdentifier))
        for task in tasks {
            guard let record = records.values.first(where: { $0.bindings.contains(where: { $0.taskIdentifier == task.taskIdentifier }) }), record.ownerID == ownerID, !record.state.isTerminal else { task.cancel(); continue }
            if record.state == .paused { task.cancel() } else { task.resume() }
        }
        for id in Array(records.keys) {
            guard var record = records[id] else { continue }
            if record.state == .completed { await cleanupIfSafe(id); continue }
            let gone = record.bindings.filter { !liveIDs.contains($0.taskIdentifier) }
            record.bindings.removeAll { !liveIDs.contains($0.taskIdentifier) }
            records[id] = record; try await persist(id)
            for binding in gone { try? media.remove(binding.fileURL) }
            if record.state == .cancelled { await finishCancellation(id); continue }
            if let session = record.session {
                do { let remote: TransferSession = try await api.get("transfers/\(session.id)"); try await apply(remote, id: id) }
                catch { if record.state != .paused { await fail(id, error: error) } }
            }
            if let current = records[id], [.preparing, .uploading, .verifying].contains(current.state), current.bindings.isEmpty { try await transition(id, to: .ready) }
        }
        await schedule()
    }
    @discardableResult func enqueue(projectID: String, file: ImportedMedia) async throws -> TransferRecord {
        guard let ownerID else { throw APIError(status: 401, message: "Sign in before uploading.", retryAfter: nil) }
        guard FileManager.default.fileExists(atPath: file.fileURL.path), file.fileURL.deletingLastPathComponent().standardizedFileURL == media.root.standardizedFileURL else { throw MediaImportError(message: "Import a durable staged file before queueing.") }
        guard !records.values.contains(where: { !$0.state.isTerminal && $0.file.fileURL == file.fileURL }) else { throw MediaImportError(message: "This staged file is already queued.") }
        let record = TransferRecord(id: UUID().uuidString, ownerID: ownerID, projectID: projectID, file: file, createdAt: Date(), state: .queued, session: nil, uploadedBytes: 0, retryCount: 0, nextRetryAt: nil, error: nil, bindings: [], createKey: UUID().uuidString, completeKey: UUID().uuidString, cancelKey: UUID().uuidString)
        records[record.id] = record
        do { try await persist(record.id) } catch { records.removeValue(forKey: record.id); throw error }
        Task { await self.schedule() }; return record
    }
    func pause(id: String) async throws {
        guard let record = records[id], !record.state.isTerminal else { return }
        try await transition(id, to: .paused)
        for task in await background.tasks() where record.bindings.contains(where: { $0.taskIdentifier == task.taskIdentifier }) { task.cancel() }
    }
    func resume(id: String) async throws {
        guard records[id]?.state == .paused else { return }
        records[id]?.nextRetryAt = nil; records[id]?.error = nil
        try await transition(id, to: .ready)
        let bindings = records[id]?.bindings ?? []
        for task in await background.tasks() where bindings.contains(where: { $0.taskIdentifier == task.taskIdentifier }) { task.resume() }
        await schedule()
    }
    func retry(id: String) async throws {
        guard var record = records[id], record.state == .failed || record.state == .retryWaiting else { return }
        record.retryCount = 0; record.error = nil; record.nextRetryAt = nil; records[id] = record
        try await transition(id, to: .ready); await schedule()
    }
    func cancel(id: String) async throws {
        guard let record = records[id], !record.state.isTerminal else { return }
        try await transition(id, to: .cancelled)
        for task in await background.tasks() where record.bindings.contains(where: { $0.taskIdentifier == task.taskIdentifier }) { task.cancel() }
        await finishCancellation(id)
        await schedule()
    }
    private func transition(_ id: String, to state: TransferState) async throws {
        guard var record = records[id] else { return }
        guard record.state.canTransition(to: state) else { throw MediaImportError(message: "Invalid transfer transition \(record.state.rawValue) → \(state.rawValue).") }
        record.state = state; records[id] = record; try await persist(id)
    }
    private func persist(_ id: String) async throws { if let record = records[id] { try await store.put(record, key: id, scope: record.ownerID, kind: "transfer") } }
    private func apply(_ remote: TransferSession, id: String) async throws {
        guard var record = records[id], record.ownerID == ownerID else { return }
        guard remote.totalBytes == record.file.sizeBytes, remote.partSize >= 5 * 1024 * 1024, remote.partSize <= 128 * 1024 * 1024 else { throw MediaImportError(message: "Server returned inconsistent multipart metadata.") }
        let count = Int((remote.totalBytes + remote.partSize - 1) / remote.partSize)
        guard count <= 10_000, Set(remote.parts.map(\.partNumber)).count == remote.parts.count, remote.parts.allSatisfy({ part in part.partNumber > 0 && part.partNumber <= count && part.sizeBytes == min(remote.partSize, remote.totalBytes - Int64(part.partNumber - 1) * remote.partSize) }) else { throw MediaImportError(message: "Server returned inconsistent part metadata.") }
        if remote.parts.reduce(0, { $0 + $1.sizeBytes }) > record.uploadedBytes { record.retryCount = 0; record.nextRetryAt = nil; record.error = nil }
        record.session = remote; record.uploadedBytes = remote.isAwaitingVerification ? record.file.sizeBytes : remote.parts.reduce(0) { $0 + $1.sizeBytes }; records[id] = record; try await persist(id)
    }
    private func schedule() async {
        guard ownerID != nil else { return }
        if scheduling { scheduleRequested = true; return }
        scheduling = true
        defer {
            scheduling = false; armRetryWake()
            if scheduleRequested { scheduleRequested = false; Task { await self.schedule() } }
        }
        for id in records.values.sorted(by: { $0.createdAt < $1.createdAt }).map(\.id) {
            guard var record = records[id], record.ownerID == ownerID, [.queued, .ready, .uploading, .retryWaiting, .verifying].contains(record.state) else { continue }
            if let retry = record.nextRetryAt, retry > Date() { continue }
            if records.values.reduce(0, { $0 + $1.bindings.count }) >= maximumConcurrentParts { break }
            do {
                if record.session == nil {
                    if record.state == .queued { try await transition(id, to: .preparing) }
                    struct Input: Encodable, Sendable { let projectId: String; let filename: String; let mimeType: String; let sizeBytes: Int64; let contentHash: String }
                    let remote: TransferSession = try await api.mutate("transfers", body: Input(projectId: record.projectID, filename: record.file.filename, mimeType: record.file.mimeType, sizeBytes: record.file.sizeBytes, contentHash: record.file.contentHash), idempotencyKey: record.createKey)
                    try await apply(remote, id: id)
                } else if let session = record.session {
                    let remote: TransferSession = try await api.get("transfers/\(session.id)"); try await apply(remote, id: id)
                }
                if records[id]?.state == .cancelled { await finishCancellation(id); continue }
                guard let latest = records[id], latest.ownerID == ownerID, latest.state != .paused, !latest.state.isTerminal, let session = latest.session else { continue }
                record = latest
                if session.status == "CANCELLED" || (session.status != "COMPLETED" && session.expiresAt <= Date()) { throw APIError(status: 410, message: "Upload session expired. Cancel and import again to restart safely.", retryAfter: nil) }
                let count = Int((record.file.sizeBytes + session.partSize - 1) / session.partSize)
                let done = Set(session.parts.map(\.partNumber))
                if session.isAwaitingVerification || done.count == count {
                    if !record.bindings.isEmpty { continue }
                    try await transition(id, to: .verifying)
                    let result: CompletedTransfer = try await api.mutate("transfers/\(session.id)/complete", body: EmptyBody(), idempotencyKey: record.completeKey)
                    guard result.mediaAsset.status == "VERIFIED", result.mediaAsset.contentHash == record.file.contentHash, result.mediaAsset.sizeBytes == record.file.sizeBytes else { throw MediaImportError(message: "Server integrity verification failed; delivery remains blocked.") }
                    guard records[id]?.state == .verifying else { continue }
                    records[id]?.uploadedBytes = record.file.sizeBytes; records[id]?.error = nil; try await transition(id, to: .completed); await cleanupIfSafe(id); continue
                }
                if record.state != .uploading { try await transition(id, to: .uploading) }
                for part in 1...count where !done.contains(part) && !(records[id]?.bindings.contains(where: { $0.partNumber == part }) ?? true) {
                    if records.values.reduce(0, { $0 + $1.bindings.count }) >= maximumConcurrentParts { break }
                    let signed: SignedPart = try await api.mutate("transfers/\(session.id)/parts/\(part)/sign", body: EmptyBody())
                    guard signed.url.scheme == "https" || (api.baseURL.scheme == "http" && signed.url.scheme == "http") else { throw MediaImportError(message: "Invalid upload authorization URL.") }
                    let file = try await media.partFile(source: record.file.fileURL, recordID: id, part: part, partSize: session.partSize, totalBytes: record.file.sizeBytes)
                    guard let current = records[id], current.ownerID == ownerID, current.state == .uploading else { try? media.remove(file); break }
                    let task = background.upload(url: signed.url, file: file, cellular: cellularAllowed, description: "\(id):\(part)")
                    let size = min(session.partSize, record.file.sizeBytes - Int64(part - 1) * session.partSize)
                    records[id]?.bindings.append(PartBinding(taskIdentifier: task.taskIdentifier, partNumber: part, fileURL: file, sizeBytes: size, sentBytes: 0))
                    do { try await persist(id); task.resume() } catch { task.cancel(); throw error }
                }
            } catch { await fail(id, error: error) }
        }
    }
    private func fail(_ id: String, error: Error, retryAfter: TimeInterval? = nil) async {
        guard var record = records[id], record.ownerID == ownerID, !record.state.isTerminal, record.state != .paused else { return }
        record.retryCount += 1; record.error = error.localizedDescription
        let retryable = ProjectRepository.isOffline(error)
        let next: TransferState = retryable && record.retryCount <= RetryPolicy.maximumAttempts ? .retryWaiting : .failed
        record.nextRetryAt = next == .retryWaiting ? Date().addingTimeInterval(RetryPolicy.delay(attempt: record.retryCount, retryAfter: retryAfter ?? (error as? APIError)?.retryAfter)) : nil
        record.state = next; records[id] = record
        do { try await persist(id) } catch { records[id]?.error = "Queue persistence failed. \(error.localizedDescription)" }
    }
    private func receive(_ event: BackgroundEvent) async {
        switch event {
        case .finishedEvents: finishedBackgroundEvents = true; await finishBackgroundEvents()
        case let .progress(taskID, sent):
            guard let id = records.values.first(where: { $0.bindings.contains(where: { $0.taskIdentifier == taskID }) })?.id, let index = records[id]?.bindings.firstIndex(where: { $0.taskIdentifier == taskID }) else { return }
            records[id]?.bindings[index].sentBytes = sent
        case let .completed(taskID, status, retryAfter, message):
            guard let id = records.values.first(where: { $0.bindings.contains(where: { $0.taskIdentifier == taskID }) })?.id, let binding = records[id]?.bindings.first(where: { $0.taskIdentifier == taskID }) else { return }
            records[id]?.bindings.removeAll { $0.taskIdentifier == taskID }
            do { try await persist(id); try media.remove(binding.fileURL) }
            catch { await fail(id, error: error); return }
            if records[id]?.state.isTerminal == true { await cleanupIfSafe(id); await schedule(); return }
            if (200...299).contains(status), message == nil {
                // URLSession success is provisional: schedule always reads authoritative ListParts.
                records[id]?.nextRetryAt = nil
            } else if records[id]?.state != .paused {
                let error = APIError(status: status == 0 || status == 403 ? 503 : status, message: message ?? "Upload part returned HTTP \(status).", retryAfter: retryAfter)
                await fail(id, error: error, retryAfter: retryAfter)
            }
            await schedule()
        }
    }
    private func finishCancellation(_ id: String) async {
        guard let record = records[id], record.state == .cancelled, record.ownerID == ownerID else { return }
        if record.cancelConfirmed == true { await cleanupIfSafe(id); return }
        do {
            var session = record.session
            if session == nil {
                // Replay the durable create key to discover a session created before a lost response.
                struct Input: Encodable, Sendable { let projectId: String; let filename: String; let mimeType: String; let sizeBytes: Int64; let contentHash: String }
                session = try await api.mutate("transfers", body: Input(projectId: record.projectID, filename: record.file.filename, mimeType: record.file.mimeType, sizeBytes: record.file.sizeBytes, contentHash: record.file.contentHash), idempotencyKey: record.createKey)
                guard records[id]?.ownerID == ownerID else { return }
                records[id]?.session = session; try await persist(id)
            }
            if let session {
                let _: OKResponse = try await api.mutate("transfers/\(session.id)/cancel", body: EmptyBody(), idempotencyKey: record.cancelKey)
            }
            guard records[id]?.ownerID == ownerID else { return }
            records[id]?.cancelConfirmed = true; records[id]?.error = nil; try await persist(id); await cleanupIfSafe(id)
        } catch {
            if (error as? APIError)?.status == 409, let session = records[id]?.session {
                do {
                    let remote: TransferSession = try await api.get("transfers/\(session.id)")
                    if remote.status == "COMPLETED" {
                        let result: CompletedTransfer = try await api.mutate("transfers/\(session.id)/complete", body: EmptyBody(), idempotencyKey: record.completeKey)
                        guard result.mediaAsset.status == "VERIFIED", result.mediaAsset.sizeBytes == record.file.sizeBytes, result.mediaAsset.contentHash == record.file.contentHash else { throw MediaImportError(message: "Server integrity verification failed.") }
                        guard records[id]?.ownerID == ownerID else { return }
                        // A verified server completion wins a cancellation that arrived too late.
                        records[id]?.session = remote; records[id]?.state = .completed
                        records[id]?.uploadedBytes = record.file.sizeBytes; records[id]?.error = nil
                        try await persist(id); await cleanupIfSafe(id); return
                    }
                } catch { records[id]?.error = "Cancellation reconciliation failed. \(error.localizedDescription)"; try? await persist(id); return }
            }
            records[id]?.error = "Cancelled locally; server abort will retry on next restore. \(error.localizedDescription)"
            try? await persist(id)
        }
    }
    private func cleanupIfSafe(_ id: String) async {
        guard let record = records[id], record.state.isTerminal, record.bindings.isEmpty, record.error == nil, record.state != .cancelled || record.cancelConfirmed == true else { return }
        do { try media.remove(record.file.fileURL) } catch { records[id]?.error = "Upload finished; local cleanup failed. \(error.localizedDescription)"; try? await persist(id) }
    }
    private func armRetryWake() {
        retryWake?.cancel()
        guard let retry = records.values.filter({ $0.state == .retryWaiting }).compactMap(\.nextRetryAt).filter({ $0 > Date() }).min() else { return }
        retryWake = Task { [weak self] in do { try await Task.sleep(for: .seconds(max(0.1, retry.timeIntervalSinceNow))); await self?.schedule() } catch {} }
    }
    private func finishBackgroundEvents() async {
        guard finishedBackgroundEvents, let completion = backgroundCompletion else { return }
        backgroundCompletion = nil; finishedBackgroundEvents = false
        await completion()
    }
}
