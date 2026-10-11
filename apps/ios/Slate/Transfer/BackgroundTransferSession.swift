import Foundation

enum BackgroundEvent: Sendable {
    case progress(Int, Int64)
    case completed(Int, Int, TimeInterval?, String?)
    case finishedEvents
}
/// Delegate events are consumed in order by the coordinator's single stream loop.
final class BackgroundTransferSession: NSObject, URLSessionTaskDelegate, URLSessionDelegate, @unchecked Sendable {
    static let identifier = "com.slate.multipart.background.v1"
    let events: AsyncStream<BackgroundEvent>
    private let continuation: AsyncStream<BackgroundEvent>.Continuation
    private(set) var session: URLSession!
    init(identifier: String = BackgroundTransferSession.identifier) {
        var streamContinuation: AsyncStream<BackgroundEvent>.Continuation!
        events = AsyncStream { streamContinuation = $0 }; continuation = streamContinuation
        super.init()
        let configuration = URLSessionConfiguration.background(withIdentifier: identifier)
        configuration.sessionSendsLaunchEvents = true; configuration.isDiscretionary = false
        configuration.waitsForConnectivity = true; configuration.httpMaximumConnectionsPerHost = 2
        configuration.timeoutIntervalForResource = 24 * 60 * 60
        let queue = OperationQueue(); queue.maxConcurrentOperationCount = 1
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: queue)
    }
    func tasks() async -> [URLSessionTask] { await withCheckedContinuation { continuation in session.getAllTasks { continuation.resume(returning: $0) } } }
    func upload(url: URL, file: URL, cellular: Bool, description: String) -> URLSessionUploadTask {
        var request = URLRequest(url: url); request.httpMethod = "PUT"; request.allowsCellularAccess = cellular
        let task = session.uploadTask(with: request, fromFile: file); task.taskDescription = description; return task
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) { continuation.yield(.progress(task.taskIdentifier, totalBytesSent)) }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let response = task.response as? HTTPURLResponse
        continuation.yield(.completed(task.taskIdentifier, response?.statusCode ?? 0, RetryPolicy.retryAfter(response?.value(forHTTPHeaderField: "Retry-After")), error?.localizedDescription))
    }
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) { continuation.yield(.finishedEvents) }
}
