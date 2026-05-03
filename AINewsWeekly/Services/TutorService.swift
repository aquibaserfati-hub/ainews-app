import Foundation

// TutorService — drives a single tutor chat call. Builds the request, opens
// an SSE stream against the Cloudflare Worker, branches on Content-Type
// (text/event-stream vs application/json error envelope), parses chunks,
// and emits AsyncStream events for the view layer.
//
// CONFIGURATION: TutorService.workerURL is set to a placeholder until the
// Worker is deployed. After running `wrangler deploy`, update the URL here
// to match the printed `https://ainews-tutor.<your-subdomain>.workers.dev`.

struct TutorRequestPayload: Encodable {
    let lesson_id: String
    let step_id: String
    let user_message: String
    let completed_step_ids: [String]
}

// Events emitted by the tutor stream, consumed by TutorChatView.
enum TutorStreamEvent: Sendable {
    case textDelta(String)
    case done(totalInputTokens: Int, totalOutputTokens: Int)
    case error(TutorError)
}

enum TutorError: Error, Sendable, Equatable {
    case rateLimit(retryAfterSeconds: Int)
    case circuitBreaker
    case lessonNotFound
    case invalidRequest(message: String)
    case anthropicUpstream(message: String)
    case network(message: String)
    case timeout
    case decoding(message: String)

    var userFacingMessage: String {
        switch self {
        case .rateLimit:
            return "Too many questions, try again later."
        case .circuitBreaker:
            return "Tutor is resting today. Try again tomorrow."
        case .lessonNotFound:
            return "Lesson context unavailable. Try again from the lesson screen."
        case .invalidRequest(let message):
            return "Couldn't send your question — \(message)"
        case .anthropicUpstream(let message):
            return "The tutor model returned an error: \(message)"
        case .network:
            return "Connection lost. Tap Retry to reconnect."
        case .timeout:
            return "Tutor is unreachable. Try again."
        case .decoding(let message):
            return "Couldn't read tutor response: \(message)"
        }
    }
}

// Worker error envelope shape (wire format).
private struct WorkerErrorEnvelope: Decodable {
    let type: String
    let code: String
    let message: String
    let retry_after_seconds: Int?
}

final class TutorService: @unchecked Sendable {
    // PLACEHOLDER — replace with the URL `wrangler deploy` prints after
    // running it the first time.
    static let workerURL = URL(string: "https://ainews-tutor.aquiba.workers.dev/v1/chat")!

    // Time the iOS client waits between connection-open and the first SSE
    // event before giving up. Eng review fix #5.
    static let firstEventTimeout: Duration = .seconds(30)

    private let endpoint: URL
    private let session: URLSession
    private let installToken: () -> String

    init(
        endpoint: URL = TutorService.workerURL,
        session: URLSession = .shared,
        installToken: @escaping () -> String = { InstallTokenStore.token() }
    ) {
        self.endpoint = endpoint
        self.session = session
        self.installToken = installToken
    }

    func stream(payload: TutorRequestPayload) -> AsyncStream<TutorStreamEvent> {
        AsyncStream { continuation in
            let task = Task { [endpoint, session, installToken] in
                await Self.run(
                    endpoint: endpoint,
                    session: session,
                    installToken: installToken(),
                    payload: payload,
                    continuation: continuation
                )
            }
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    // MARK: - Driver

    private static func run(
        endpoint: URL,
        session: URLSession,
        installToken: String,
        payload: TutorRequestPayload,
        continuation: AsyncStream<TutorStreamEvent>.Continuation
    ) async {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(installToken, forHTTPHeaderField: "X-Install-Token")
        request.timeoutInterval = 30
        do {
            request.httpBody = try JSONEncoder().encode(payload)
        } catch {
            continuation.yield(.error(.invalidRequest(message: error.localizedDescription)))
            continuation.finish()
            return
        }

        let upstream: (asyncBytes: URLSession.AsyncBytes, response: URLResponse)
        do {
            upstream = try await session.bytes(for: request)
        } catch {
            continuation.yield(.error(.network(message: error.localizedDescription)))
            continuation.finish()
            return
        }

        guard let http = upstream.response as? HTTPURLResponse else {
            continuation.yield(.error(.network(message: "Unexpected response type")))
            continuation.finish()
            return
        }

        let contentType = http.value(forHTTPHeaderField: "Content-Type")?.lowercased() ?? ""

        // Branch on MIME type before parsing (eng review fix #2).
        if contentType.contains("application/json") {
            // Error envelope path. Drain bytes, parse JSON.
            do {
                let data = try await collectBytes(upstream.asyncBytes, max: 16_384)
                let envelope = try JSONDecoder().decode(WorkerErrorEnvelope.self, from: data)
                continuation.yield(.error(mapEnvelope(envelope)))
            } catch {
                continuation.yield(.error(.decoding(message: error.localizedDescription)))
            }
            continuation.finish()
            return
        }

        if !contentType.contains("text/event-stream") {
            // Unknown success-code MIME — surface as decoding failure.
            continuation.yield(.error(.decoding(message: "Unexpected Content-Type: \(contentType)")))
            continuation.finish()
            return
        }

        // SSE happy path — parse \n\n-delimited events with a first-event timeout.
        await parseSSE(asyncBytes: upstream.asyncBytes, continuation: continuation)
    }

    // MARK: - SSE parsing

    private static func parseSSE(
        asyncBytes: URLSession.AsyncBytes,
        continuation: AsyncStream<TutorStreamEvent>.Continuation
    ) async {
        // Buffer for partial events. Bytes are split on "\n\n"; each event
        // has zero or more `data:` lines.
        var buffer = Data()
        var firstByteSeen = false

        // Race the byte stream against a first-event timeout. If 30s pass
        // without a single byte, abort.
        let timeoutTask = Task {
            try? await Task.sleep(for: TutorService.firstEventTimeout)
            if !firstByteSeen {
                continuation.yield(.error(.timeout))
                continuation.finish()
            }
        }

        do {
            for try await byte in asyncBytes {
                firstByteSeen = true
                buffer.append(byte)
                while let separator = buffer.range(of: Data([0x0A, 0x0A])) { // "\n\n"
                    let eventBlock = buffer.subdata(in: 0..<separator.lowerBound)
                    buffer.removeSubrange(0..<separator.upperBound)
                    handleEventBlock(eventBlock, continuation: continuation)
                }
            }
        } catch {
            timeoutTask.cancel()
            continuation.yield(.error(.network(message: error.localizedDescription)))
            continuation.finish()
            return
        }

        timeoutTask.cancel()
        // Trailing partial event (uncommon; SSE servers always end with \n\n,
        // but be defensive).
        if !buffer.isEmpty {
            handleEventBlock(buffer, continuation: continuation)
        }
        continuation.finish()
    }

    private static func handleEventBlock(
        _ block: Data,
        continuation: AsyncStream<TutorStreamEvent>.Continuation
    ) {
        guard let blockStr = String(data: block, encoding: .utf8) else { return }
        for line in blockStr.split(separator: "\n", omittingEmptySubsequences: true) {
            guard line.hasPrefix("data:") else { continue }
            let payload = line.dropFirst("data:".count).trimmingCharacters(in: .whitespaces)
            guard let payloadData = payload.data(using: .utf8) else { continue }
            decodeServerEvent(payloadData, continuation: continuation)
        }
    }

    // Server (Worker) -> client SSE event shapes.
    private struct TextDeltaEvent: Decodable { let type: String; let delta: String }
    private struct DoneEvent: Decodable {
        let type: String
        let total_input_tokens: Int
        let total_output_tokens: Int
    }
    private struct EventTypeProbe: Decodable { let type: String }

    private static func decodeServerEvent(
        _ data: Data,
        continuation: AsyncStream<TutorStreamEvent>.Continuation
    ) {
        guard let probe = try? JSONDecoder().decode(EventTypeProbe.self, from: data) else { return }
        switch probe.type {
        case "text":
            if let delta = try? JSONDecoder().decode(TextDeltaEvent.self, from: data) {
                continuation.yield(.textDelta(delta.delta))
            }
        case "done":
            if let done = try? JSONDecoder().decode(DoneEvent.self, from: data) {
                continuation.yield(.done(
                    totalInputTokens: done.total_input_tokens,
                    totalOutputTokens: done.total_output_tokens
                ))
            }
        default:
            // Forward-compatible: ignore unknown event types.
            break
        }
    }

    // MARK: - Helpers

    private static func collectBytes(_ bytes: URLSession.AsyncBytes, max: Int) async throws -> Data {
        var buffer = Data()
        for try await byte in bytes {
            buffer.append(byte)
            if buffer.count >= max { break }
        }
        return buffer
    }

    fileprivate static func mapEnvelope(_ envelope: WorkerErrorEnvelope) -> TutorError {
        switch envelope.code {
        case "rate_limit_exceeded":
            return .rateLimit(retryAfterSeconds: envelope.retry_after_seconds ?? 60)
        case "circuit_breaker":
            return .circuitBreaker
        case "lesson_not_found":
            return .lessonNotFound
        case "invalid_request":
            return .invalidRequest(message: envelope.message)
        case "anthropic_error":
            return .anthropicUpstream(message: envelope.message)
        default:
            return .decoding(message: "Unknown error code: \(envelope.code)")
        }
    }
}

// Internal hook for tests.
extension TutorService {
    static func _testMapEnvelope(code: String, message: String, retryAfter: Int? = nil) -> TutorError {
        let envelope = WorkerErrorEnvelope(
            type: "error",
            code: code,
            message: message,
            retry_after_seconds: retryAfter
        )
        return mapEnvelope(envelope)
    }
}
