import Foundation

// Curriculum schema (v2). Independent schemaVersion from Digest — the two
// content artifacts are published separately. The iOS Codable shapes here
// must match ainews-content/src/schema.ts exactly. Cross-repo contract is
// enforced by CurriculumModelsTests decoding the same curriculum-v1.json
// fixture the backend zod test validates.
let CURRENT_CURRICULUM_SCHEMA_VERSION = 1

struct Curriculum: Codable, Equatable {
    let schemaVersion: Int
    let updatedAt: Date
    let tracks: [CurriculumTrack]
}

struct CurriculumTrack: Codable, Equatable, Identifiable, Hashable {
    let id: String                  // "beginner" | "intermediate" | "advanced"
    let title: String
    let description: String
    let order: Int
    let lessons: [Lesson]
}

struct Lesson: Codable, Equatable, Identifiable, Hashable {
    let id: String                  // stable kebab id, e.g. "setup-claude-code"
    let trackId: String
    let title: String
    let oneLineDescription: String
    let estimatedMinutes: Int
    let category: Category
    let prerequisites: [String]
    let youtubeURL: URL?
    let steps: [LessonStep]
    let isProContent: Bool          // ships false in v2; v2.1 will toggle
}

struct LessonStep: Codable, Equatable, Identifiable, Hashable {
    let id: String                  // step-N, no zero-pad
    let title: String
    let body: String                // markdown
    let stepType: StepType
    let validationHint: String?
}

enum StepType: String, Codable, Hashable, Equatable, Sendable {
    case read
    case runCommand
    case verify
}

// LessonProgress — LOCAL ONLY, never appears in curriculum.json.
// Stored in UserDefaults via LessonProgressStore (Weekend 3).
// Defined here so the data model lives in one place even though
// the store lands later.
struct LessonProgress: Codable, Equatable, Hashable {
    let lessonId: String
    let startedAt: Date?
    let completedAt: Date?
    let completedStepIds: [String]
    let tutorTranscript: [TutorMessage]
    // tutor message count is derived: tutorTranscript.filter { $0.role == .user }.count
}

struct TutorMessage: Codable, Equatable, Identifiable, Hashable {
    let id: String                  // UUID per message
    let role: TutorRole
    let body: String                // markdown for assistant, plain for user
    let timestamp: Date
}

enum TutorRole: String, Codable, Hashable, Equatable, Sendable {
    case user
    case assistant
}

// Mirrors the SchemaMismatchError pattern in Models.swift, kept distinct so
// Digest and Curriculum mismatches surface independent UX states.
struct CurriculumSchemaMismatchError: Error, LocalizedError {
    let receivedVersion: Int
    let knownVersion: Int

    var errorDescription: String? {
        "Update AINews — this curriculum uses schema v\(receivedVersion), this build understands v\(knownVersion)."
    }
}
