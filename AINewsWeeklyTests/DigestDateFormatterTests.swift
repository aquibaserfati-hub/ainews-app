import Testing
import Foundation
@testable import AINewsWeekly

@Suite("DigestDateFormatter (strict UTC ISO-8601)")
struct DigestDateFormatterTests {
    @Test("Decodes a strict UTC date string")
    func decodesStrictUTC() throws {
        let json = "\"2026-04-20T06:00:00Z\"".data(using: .utf8)!
        let date = try DigestDateFormatter.decoder().decode(Date.self, from: json)
        let components = Calendar(identifier: .gregorian).dateComponents(in: TimeZone(identifier: "UTC")!, from: date)
        #expect(components.year == 2026)
        #expect(components.month == 4)
        #expect(components.day == 20)
        #expect(components.hour == 6)
    }

    @Test("Encodes back to the same strict format (no millis, always Z)")
    func encodesStrictUTC() throws {
        let date = ISO8601DateFormatter().date(from: "2026-04-20T06:00:00Z")!
        let encoded = try DigestDateFormatter.encoder().encode(date)
        let str = String(data: encoded, encoding: .utf8)!
        // Encoder wraps in quotes; strip them before comparing.
        #expect(str.contains("2026-04-20T06:00:00Z"))
        #expect(!str.contains(".000"))
        #expect(!str.contains("+00:00"))
    }

    @Test("Rejects fractional-seconds form")
    func rejectsMillis() {
        let json = "\"2026-04-20T06:00:00.123Z\"".data(using: .utf8)!
        #expect(throws: (any Error).self) {
            _ = try DigestDateFormatter.decoder().decode(Date.self, from: json)
        }
    }

    @Test("Rejects non-Z timezone offset")
    func rejectsOffset() {
        let json = "\"2026-04-20T06:00:00+01:00\"".data(using: .utf8)!
        #expect(throws: (any Error).self) {
            _ = try DigestDateFormatter.decoder().decode(Date.self, from: json)
        }
    }

    @Test("Rejects bare timestamp without Z")
    func rejectsNoSuffix() {
        let json = "\"2026-04-20T06:00:00\"".data(using: .utf8)!
        #expect(throws: (any Error).self) {
            _ = try DigestDateFormatter.decoder().decode(Date.self, from: json)
        }
    }
}
