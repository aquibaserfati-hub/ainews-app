import Foundation

// Schema version of the local Codable model. If the backend's digest.json
// schemaVersion exceeds this, the app shows an "Update AINews" prompt
// instead of trying to decode and crashing.
//
// Any change here MUST be paired with a matching change to:
//   - ainews-content/src/schema.ts
//   - test-fixtures/digest-v1.json (in BOTH repos)
//   - the contract tests on both sides
// Treat schema bumps with the same rigor as database migrations.
let CURRENT_SCHEMA_VERSION = 1

struct Digest: Codable, Equatable {
    let schemaVersion: Int
    let weekOf: Date
    let reportGeneratedAt: Date
    let learnGeneratedAt: Date
    let report: [ReportBullet]
    let learn: [LearnItem]
}

struct ReportBullet: Codable, Equatable, Identifiable, Hashable {
    let id: String
    let title: String
    let summary: String
    let category: Category
    let sourceURL: URL
    let significance: Int
}

struct LearnItem: Codable, Equatable, Identifiable, Hashable {
    let id: String
    let name: String
    let category: Category
    let oneLineDescription: String
    let estimatedSetupMinutes: Int?
    let detail: LearnDetail
}

struct LearnDetail: Codable, Equatable, Hashable {
    let whatItDoes: String
    let whoItsFor: String
    let pros: [String]
    let cons: [String]
    let setupGuideMarkdown: String
    let sourceURL: URL
}

// SchemaMismatch — thrown when the fetched JSON's schemaVersion is greater
// than what this build of the app understands. The UI handles it by
// showing a "Update AINews to see this week's digest" message with an
// App Store deep-link instead of a generic decode failure.
struct SchemaMismatchError: Error, LocalizedError {
    let receivedVersion: Int
    let knownVersion: Int

    var errorDescription: String? {
        "Update AINews — this digest uses schema v\(receivedVersion), this build understands v\(knownVersion)."
    }
}
