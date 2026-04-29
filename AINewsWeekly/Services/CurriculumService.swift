import Foundation
import Observation

// CurriculumService — fetches curriculum.json from gh-pages, caches on disk,
// falls back to cache on network failure. Mirrors DigestService one-for-one
// (hour-bucket cache-bust, schemaVersion gate, force-refresh path) so v1 and
// v2 content artifacts share a behavior model.

private let curriculumURL = URL(string: "https://aquibaserfati-hub.github.io/ainews-content/curriculum.json")!

private let cachedCurriculumFilename = "curriculum.json"

@MainActor
@Observable
final class CurriculumService {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded(Curriculum)
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

    func loadCurriculum() async {
        await load(forceFresh: false)
    }

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
            let curriculum = try decode(data: data)
            try writeCache(data: data)
            state = .loaded(curriculum)
            return
        } catch let mismatch as CurriculumSchemaMismatchError {
            state = .schemaMismatch(received: mismatch.receivedVersion, known: mismatch.knownVersion)
            return
        } catch {
            if let cached = readCachedCurriculum() {
                state = .loaded(cached)
                return
            }
            state = .empty
        }
    }

    // MARK: - URL building

    private func hourBucketFetchURL() -> URL {
        let bucket = Int(now().timeIntervalSince1970 / 3600)
        return curriculumURL.appending(queryItems: [URLQueryItem(name: "t", value: String(bucket))])
    }

    private func aggressiveFetchURL() -> URL {
        let unix = Int(now().timeIntervalSince1970)
        return curriculumURL.appending(queryItems: [URLQueryItem(name: "t", value: String(unix))])
    }

    // MARK: - Decoding

    private func decode(data: Data) throws -> Curriculum {
        struct VersionProbe: Decodable { let schemaVersion: Int }
        let probe = try JSONDecoder().decode(VersionProbe.self, from: data)
        if probe.schemaVersion > CURRENT_CURRICULUM_SCHEMA_VERSION {
            throw CurriculumSchemaMismatchError(
                receivedVersion: probe.schemaVersion,
                knownVersion: CURRENT_CURRICULUM_SCHEMA_VERSION
            )
        }
        return try DigestDateFormatter.decoder().decode(Curriculum.self, from: data)
    }

    private func assertSuccessHTTP(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    // MARK: - Cache (Documents/curriculum.json)

    private var cacheURL: URL {
        documentsDirectory.appendingPathComponent(cachedCurriculumFilename)
    }

    private func writeCache(data: Data) throws {
        try data.write(to: cacheURL, options: [.atomic])
    }

    private func readCachedCurriculum() -> Curriculum? {
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }
        return try? decode(data: data)
    }
}
