import Testing
import Foundation
@testable import AINewsWeekly

// CRITICAL: cross-repo contract test. The same digest-v1.json fixture is
// validated against the zod schema in ainews-content's tests/schema.test.ts.
// If THIS test passes here AND THAT test passes there, the JSON contract is
// in sync between backend and iOS. If either side breaks, its own test fails
// first — schema drift is caught at PR time, not at App Store submission time.

private func loadFixture() throws -> Data {
    guard let url = Bundle(for: BundleClass.self).url(forResource: "digest-v1", withExtension: "json") else {
        throw NSError(domain: "TestFixture", code: -1, userInfo: [
            NSLocalizedDescriptionKey: "digest-v1.json not in test bundle. Check that AINewsWeeklyTests/Fixtures/digest-v1.json is added to the test target's resources."
        ])
    }
    return try Data(contentsOf: url)
}
private final class BundleClass {}

@Suite("Digest schema (contract test)")
struct ModelsTests {
    @Test("Decodes the canonical fixture digest-v1.json")
    func decodesFixture() throws {
        let data = try loadFixture()
        let decoder = DigestDateFormatter.decoder()
        let digest = try decoder.decode(Digest.self, from: data)
        #expect(digest.schemaVersion == 1)
        #expect(digest.report.count >= 1)
        #expect(digest.learn.count >= 1)
        #expect(digest.report.allSatisfy { (0...10).contains($0.significance) })
    }

    @Test("Round-trips: encode then decode the fixture matches the original")
    func roundTrip() throws {
        let data = try loadFixture()
        let decoder = DigestDateFormatter.decoder()
        let digest = try decoder.decode(Digest.self, from: data)
        let encoded = try DigestDateFormatter.encoder().encode(digest)
        let decoded = try decoder.decode(Digest.self, from: encoded)
        #expect(digest == decoded)
    }

    @Test("Date fields decode to UTC instants matching the literal strings")
    func datesDecodeToUTC() throws {
        let data = try loadFixture()
        let digest = try DigestDateFormatter.decoder().decode(Digest.self, from: data)
        // The fixture's weekOf is "2026-04-20T00:00:00Z" — Monday of week 17.
        let calendar = Calendar(identifier: .gregorian)
        var components = calendar.dateComponents(in: TimeZone(identifier: "UTC")!, from: digest.weekOf)
        #expect(components.year == 2026)
        #expect(components.month == 4)
        #expect(components.day == 20)
        #expect(components.hour == 0)
        #expect(components.minute == 0)
        #expect(components.second == 0)
    }

    @Test("Rejects ISO-8601 dates with fractional seconds (strict UTC contract)")
    func rejectsFractionalSeconds() {
        let bad = """
        {
          "schemaVersion": 1,
          "weekOf": "2026-04-20T00:00:00.123Z",
          "reportGeneratedAt": "2026-04-27T06:00:00Z",
          "learnGeneratedAt": "2026-04-23T06:00:00Z",
          "report": [],
          "learn": []
        }
        """.data(using: .utf8)!
        #expect(throws: (any Error).self) {
            _ = try DigestDateFormatter.decoder().decode(Digest.self, from: bad)
        }
    }

    @Test("Rejects ISO-8601 dates with timezone offset instead of Z")
    func rejectsTimezoneOffset() {
        let bad = """
        {
          "schemaVersion": 1,
          "weekOf": "2026-04-20T00:00:00+01:00",
          "reportGeneratedAt": "2026-04-27T06:00:00Z",
          "learnGeneratedAt": "2026-04-23T06:00:00Z",
          "report": [],
          "learn": []
        }
        """.data(using: .utf8)!
        #expect(throws: (any Error).self) {
            _ = try DigestDateFormatter.decoder().decode(Digest.self, from: bad)
        }
    }

    @Test("Decodes all Category enum cases")
    func decodesAllCategories() throws {
        for c in AINewsWeekly.Category.allCases {
            let json = "\"\(c.rawValue)\"".data(using: .utf8)!
            let decoded = try JSONDecoder().decode(AINewsWeekly.Category.self, from: json)
            #expect(decoded == c)
        }
    }

    @Test("Rejects unknown category values")
    func rejectsUnknownCategory() {
        let json = "\"deepmind\"".data(using: .utf8)!  // not in our enum
        #expect(throws: (any Error).self) {
            _ = try JSONDecoder().decode(AINewsWeekly.Category.self, from: json)
        }
    }
}
