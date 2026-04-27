import Foundation
import Observation

// DigestService — fetches the weekly digest from the backend's gh-pages URL,
// caches it on disk, falls back to cache on network failure.
//
// Cache-bust strategy (locked via /plan-eng-review Issue 10): every default
// fetch appends ?t=<floor(now/3600)> so the URL changes once per hour.
// GitHub Pages CDN caches per-hour-URL — users get max 1-hour stale on
// the default path. Force-refresh uses a more aggressive ?t=<unix> + a
// reload cache policy.

private let digestURL = URL(string: "https://aquibaserfati-hub.github.io/ainews-content/digest.json")!

private let cachedDigestFilename = "digest.json"

@MainActor
@Observable
final class DigestService {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded(Digest, isStale: Bool)
        case empty
        case schemaMismatch(received: Int, known: Int)
        case failed(message: String)
    }

    private(set) var state: LoadState = .idle

    private let session: URLSession
    private let fileManager: FileManager
    private let documentsDirectory: URL
    private let now: () -> Date

    init(
        session: URLSession = .shared,
        fileManager: FileManager = .default,
        now: @escaping () -> Date = Date.init
    ) {
        self.session = session
        self.fileManager = fileManager
        self.documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.now = now
    }

    // Default fetch on launch / pull-to-refresh. Uses the hour-bucket
    // cache-bust so users get max 1-hour stale content from the CDN.
    func loadDigest() async {
        await load(forceFresh: false)
    }

    // Force refresh — Settings → "Force refresh". Uses unix-timestamp
    // cache-bust + reloadIgnoringLocalAndRemoteCacheData policy.
    func forceRefresh() async {
        await load(forceFresh: true)
    }

    private func load(forceFresh: Bool) async {
        state = .loading

        do {
            let url = forceFresh ? aggressiveFetchURL() : hourBucketFetchURL()
            var request = URLRequest(url: url)
            if forceFresh {
                request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            }
            let (data, response) = try await session.data(for: request)
            try assertSuccessHTTP(response)
            let digest = try decode(data: data)
            try writeCache(data: data)
            state = .loaded(digest, isStale: isStale(digest: digest))
            return
        } catch let mismatch as SchemaMismatchError {
            state = .schemaMismatch(received: mismatch.receivedVersion, known: mismatch.knownVersion)
            return
        } catch {
            // Fetch failed (network, HTTP, decode). Fall back to cache.
            if let cachedDigest = readCachedDigest() {
                state = .loaded(cachedDigest, isStale: true)
                return
            }
            state = .empty
        }
    }

    // MARK: - URL building

    private func hourBucketFetchURL() -> URL {
        let bucket = Int(now().timeIntervalSince1970 / 3600)
        return digestURL.appending(queryItems: [URLQueryItem(name: "t", value: String(bucket))])
    }

    private func aggressiveFetchURL() -> URL {
        let unix = Int(now().timeIntervalSince1970)
        return digestURL.appending(queryItems: [URLQueryItem(name: "t", value: String(unix))])
    }

    // MARK: - Decoding

    private func decode(data: Data) throws -> Digest {
        // Decode the schemaVersion FIRST — if it's higher than what we know,
        // throw SchemaMismatchError before the strict full decode (which
        // might fail on shape changes that schemaVersion was meant to gate).
        struct VersionProbe: Decodable {
            let schemaVersion: Int
        }
        let probe = try JSONDecoder().decode(VersionProbe.self, from: data)
        if probe.schemaVersion > CURRENT_SCHEMA_VERSION {
            throw SchemaMismatchError(
                receivedVersion: probe.schemaVersion,
                knownVersion: CURRENT_SCHEMA_VERSION
            )
        }
        return try DigestDateFormatter.decoder().decode(Digest.self, from: data)
    }

    private func assertSuccessHTTP(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    // MARK: - Cache (Documents/digest.json)

    private var cacheURL: URL {
        documentsDirectory.appendingPathComponent(cachedDigestFilename)
    }

    private func writeCache(data: Data) throws {
        try data.write(to: cacheURL, options: [.atomic])
    }

    private func readCachedDigest() -> Digest? {
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }
        return try? decode(data: data)
    }

    // MARK: - Staleness

    // Stale when reportGeneratedAt is older than 8 days. Daily refresh runs
    // every 24h, so 8 days gives a 1-day grace for cron drift / DST / transient
    // CI failures. Locked via /plan-eng-review.
    private func isStale(digest: Digest) -> Bool {
        let elapsed = now().timeIntervalSince(digest.reportGeneratedAt)
        return elapsed > 8 * 24 * 60 * 60
    }
}
