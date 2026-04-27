import Foundation

// Strict UTC ISO-8601 date formatter — locked via /plan-eng-review.
// Format: yyyy-MM-ddTHH:mm:ssZ (e.g. "2026-04-27T15:09:37Z").
// NO fractional seconds. ALWAYS Z (UTC), never +00:00 offsets.
//
// Matches ainews-content's src/utc.ts. Bare .iso8601 is too permissive
// and rejects edge cases inconsistently — don't use it here.
enum DigestDateFormatter {
    static let shared: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        f.timeZone = TimeZone(identifier: "UTC")
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    // Strict UTC ISO-8601 regex — matches src/schema.ts on the backend.
    // DateFormatter alone is permissive about trailing characters in some
    // configurations, so we regex-gate every input before parsing.
    private static let strictRegex = #"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$"#

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            guard str.range(of: strictRegex, options: .regularExpression) != nil else {
                throw DecodingError.dataCorrupted(
                    .init(
                        codingPath: decoder.codingPath,
                        debugDescription: "Date '\(str)' does not match strict UTC ISO-8601 (yyyy-MM-ddTHH:mm:ssZ)"
                    )
                )
            }
            guard let date = shared.date(from: str) else {
                throw DecodingError.dataCorrupted(
                    .init(
                        codingPath: decoder.codingPath,
                        debugDescription: "Could not parse date '\(str)'"
                    )
                )
            }
            return date
        }
        return decoder
    }

    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .formatted(shared)
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
