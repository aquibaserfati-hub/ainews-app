import SwiftUI

// Category enum — must match ainews-content/src/schema.ts case names exactly.
// Casing matters: backend writes "anthropic", "openai", "google", "otherLLM",
// "tooling", "founderLens", "other". Codable derived rawValue does this for free.
enum Category: String, Codable, CaseIterable, Hashable, Equatable, Sendable {
    case anthropic
    case openai
    case google
    case otherLLM
    case tooling
    case founderLens
    case other

    var displayName: String {
        switch self {
        case .anthropic: return "Anthropic"
        case .openai: return "OpenAI"
        case .google: return "Google"
        case .otherLLM: return "Other LLM"
        case .tooling: return "Tooling"
        case .founderLens: return "Founder Lens"
        case .other: return "Other"
        }
    }

    // SF Symbol per category. Locked in the design doc.
    var sfSymbol: String {
        switch self {
        case .anthropic: return "sparkles"
        case .openai: return "circle.hexagongrid"
        case .google: return "g.circle"
        case .otherLLM: return "cpu"
        case .tooling: return "hammer"
        case .founderLens: return "quote.bubble"
        case .other: return "ellipsis.circle"
        }
    }

    // Tag colors locked via /design-shotgun on 2026-04-27 — toned-down hues
    // to harmonize with the cream/serif editorial palette. Avoid saturated
    // dark-mode-style accents.
    var tagColor: Color {
        switch self {
        case .anthropic: return Color(red: 0.486, green: 0.373, blue: 0.690)   // muted purple #7C5FB0
        case .openai: return Color(red: 0.247, green: 0.549, blue: 0.494)      // muted teal #3F8C7E
        case .google: return Color(red: 0.722, green: 0.373, blue: 0.373)      // muted red #B85F5F
        case .otherLLM: return Color(red: 0.420, green: 0.447, blue: 0.502)    // muted slate #6B7280
        case .tooling: return Color(red: 0.612, green: 0.373, blue: 0.102)     // amber matches accent #9C5F1A
        case .founderLens: return Color(red: 0.373, green: 0.612, blue: 0.478) // muted green #5F9C7A
        case .other: return Color(red: 0.5, green: 0.5, blue: 0.5)             // neutral gray
        }
    }
}
