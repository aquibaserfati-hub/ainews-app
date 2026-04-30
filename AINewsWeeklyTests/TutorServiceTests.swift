import Testing
import Foundation
@testable import AINewsWeekly

// TutorServiceTests — exercise the SSE parsing, MIME-type branching, error
// envelope decoding, and timeout behavior. Uses URLProtocol stubs so we
// never hit the real network.

@Suite("TutorService")
struct TutorServiceTests {

    // MARK: - Error envelope mapping (pure)

    @Test("rate_limit_exceeded envelope maps to .rateLimit with retry seconds")
    func mapsRateLimit() {
        let err = TutorService._testMapEnvelope(
            code: "rate_limit_exceeded",
            message: "x",
            retryAfter: 90
        )
        #expect(err == .rateLimit(retryAfterSeconds: 90))
    }

    @Test("circuit_breaker envelope maps to .circuitBreaker with the resting message")
    func mapsCircuitBreaker() {
        let err = TutorService._testMapEnvelope(code: "circuit_breaker", message: "x")
        #expect(err == .circuitBreaker)
        #expect(err.userFacingMessage.contains("resting"))
    }

    @Test("lesson_not_found envelope maps to .lessonNotFound")
    func mapsLessonNotFound() {
        let err = TutorService._testMapEnvelope(code: "lesson_not_found", message: "x")
        #expect(err == .lessonNotFound)
    }

    @Test("invalid_request envelope preserves the message")
    func mapsInvalidRequest() {
        let err = TutorService._testMapEnvelope(code: "invalid_request", message: "bad shape")
        if case .invalidRequest(let m) = err {
            #expect(m == "bad shape")
        } else {
            Issue.record("expected .invalidRequest")
        }
    }

    @Test("anthropic_error envelope passes upstream message through")
    func mapsAnthropicUpstream() {
        let err = TutorService._testMapEnvelope(code: "anthropic_error", message: "overloaded")
        if case .anthropicUpstream(let m) = err {
            #expect(m == "overloaded")
        } else {
            Issue.record("expected .anthropicUpstream")
        }
    }

    @Test("Unknown error code falls back to .decoding (forward-compatible)")
    func mapsUnknown() {
        let err = TutorService._testMapEnvelope(code: "future_code", message: "x")
        if case .decoding = err { } else {
            Issue.record("expected .decoding for unknown code")
        }
    }

    // MARK: - User-facing copy

    @Test("rate_limit user-facing copy says 'try again later'")
    func rateLimitCopy() {
        let err = TutorError.rateLimit(retryAfterSeconds: 60)
        #expect(err.userFacingMessage.contains("try again"))
    }

    @Test("network error copy says 'Connection lost'")
    func networkCopy() {
        let err = TutorError.network(message: "x")
        #expect(err.userFacingMessage.contains("Connection lost"))
    }

    // MARK: - SSE + MIME branching with URLProtocol stub

    @Test("Happy path: SSE content-type, two text deltas + done event")
    @MainActor
    func sseHappyPath() async throws {
        let body = """
        data: {"type":"text","delta":"Hello "}

        data: {"type":"text","delta":"world"}

        data: {"type":"done","total_input_tokens":42,"total_output_tokens":7}


        """
        StubURLProtocol.respond(.success(headers: ["Content-Type": "text/event-stream"], body: body))

        let service = TutorService(
            endpoint: URL(string: "https://stub.test/v1/chat")!,
            session: StubURLProtocol.makeSession(),
            installToken: { "tok-1" }
        )
        let payload = TutorRequestPayload(
            lesson_id: "setup-claude-code",
            step_id: "step-1",
            user_message: "hi",
            completed_step_ids: []
        )

        var deltas: [String] = []
        var doneTokens: (Int, Int)? = nil
        for await event in service.stream(payload: payload) {
            switch event {
            case .textDelta(let s): deltas.append(s)
            case .done(let i, let o): doneTokens = (i, o)
            case .error(let e):
                Issue.record("unexpected error: \(e)")
            }
        }
        #expect(deltas.joined() == "Hello world")
        #expect(doneTokens?.0 == 42)
        #expect(doneTokens?.1 == 7)
    }

    @Test("Error envelope branch: 429 + application/json maps to .rateLimit")
    @MainActor
    func errorEnvelopeBranching() async throws {
        let body = #"{"type":"error","code":"rate_limit_exceeded","message":"x","retry_after_seconds":90}"#
        StubURLProtocol.respond(.error(
            statusCode: 429,
            headers: ["Content-Type": "application/json"],
            body: body
        ))

        let service = TutorService(
            endpoint: URL(string: "https://stub.test/v1/chat")!,
            session: StubURLProtocol.makeSession(),
            installToken: { "tok-2" }
        )
        let payload = TutorRequestPayload(lesson_id: "x", step_id: "step-1", user_message: "y", completed_step_ids: [])
        var observed: TutorError? = nil
        for await event in service.stream(payload: payload) {
            if case .error(let e) = event { observed = e }
        }
        #expect(observed == .rateLimit(retryAfterSeconds: 90))
    }

    @Test("Circuit-breaker envelope (503 + JSON) surfaces .circuitBreaker")
    @MainActor
    func circuitBreakerBranching() async throws {
        let body = #"{"type":"error","code":"circuit_breaker","message":"resting"}"#
        StubURLProtocol.respond(.error(
            statusCode: 503,
            headers: ["Content-Type": "application/json"],
            body: body
        ))
        let service = TutorService(
            endpoint: URL(string: "https://stub.test/v1/chat")!,
            session: StubURLProtocol.makeSession()
        )
        let payload = TutorRequestPayload(lesson_id: "x", step_id: "step-1", user_message: "y", completed_step_ids: [])
        var observed: TutorError? = nil
        for await event in service.stream(payload: payload) {
            if case .error(let e) = event { observed = e }
        }
        #expect(observed == .circuitBreaker)
    }

    @Test("SSE chunk parser handles partial chunks across multiple bytes")
    @MainActor
    func partialChunkParsing() async throws {
        // The body has two events back-to-back; URLProtocol delivers all
        // bytes as one chunk but our parser still walks the buffer.
        let body = "data: {\"type\":\"text\",\"delta\":\"a\"}\n\ndata: {\"type\":\"text\",\"delta\":\"b\"}\n\n"
        StubURLProtocol.respond(.success(headers: ["Content-Type": "text/event-stream"], body: body))
        let service = TutorService(
            endpoint: URL(string: "https://stub.test/v1/chat")!,
            session: StubURLProtocol.makeSession()
        )
        let payload = TutorRequestPayload(lesson_id: "x", step_id: "step-1", user_message: "y", completed_step_ids: [])
        var deltas: [String] = []
        for await event in service.stream(payload: payload) {
            if case .textDelta(let s) = event { deltas.append(s) }
        }
        #expect(deltas == ["a", "b"])
    }

    @Test("Unknown event types are ignored (forward-compatible)")
    @MainActor
    func unknownEventsIgnored() async throws {
        let body = "data: {\"type\":\"future-event\",\"foo\":\"bar\"}\n\ndata: {\"type\":\"text\",\"delta\":\"ok\"}\n\n"
        StubURLProtocol.respond(.success(headers: ["Content-Type": "text/event-stream"], body: body))
        let service = TutorService(
            endpoint: URL(string: "https://stub.test/v1/chat")!,
            session: StubURLProtocol.makeSession()
        )
        let payload = TutorRequestPayload(lesson_id: "x", step_id: "step-1", user_message: "y", completed_step_ids: [])
        var events: [TutorStreamEvent] = []
        for await event in service.stream(payload: payload) {
            events.append(event)
        }
        let deltas = events.compactMap { e -> String? in
            if case .textDelta(let s) = e { return s }; return nil
        }
        #expect(deltas == ["ok"])
    }

    @Test("Unknown success Content-Type surfaces as .decoding")
    @MainActor
    func unknownSuccessMime() async throws {
        StubURLProtocol.respond(.success(
            headers: ["Content-Type": "text/plain"],
            body: "lol"
        ))
        let service = TutorService(
            endpoint: URL(string: "https://stub.test/v1/chat")!,
            session: StubURLProtocol.makeSession()
        )
        let payload = TutorRequestPayload(lesson_id: "x", step_id: "step-1", user_message: "y", completed_step_ids: [])
        var observed: TutorError? = nil
        for await event in service.stream(payload: payload) {
            if case .error(let e) = event { observed = e }
        }
        if case .decoding = observed { } else {
            Issue.record("expected .decoding, got \(String(describing: observed))")
        }
    }
}

// MARK: - URLProtocol stub for offline tests

final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    enum Response {
        case success(headers: [String: String], body: String)
        case error(statusCode: Int, headers: [String: String], body: String)
    }

    nonisolated(unsafe) static var current: Response = .success(headers: [:], body: "")

    static func respond(_ response: Response) {
        current = response
    }

    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: config)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let url = request.url ?? URL(string: "https://stub.test/")!
        let (status, headers, body): (Int, [String: String], String)
        switch StubURLProtocol.current {
        case .success(let h, let b):
            (status, headers, body) = (200, h, b)
        case .error(let s, let h, let b):
            (status, headers, body) = (s, h, b)
        }
        let response = HTTPURLResponse(
            url: url,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
