import Testing
import Foundation
@testable import AINewsWeekly

// CRITICAL: cross-repo contract test (v2, parallel to ModelsTests).
// The same curriculum-v1.json fixture is validated against the zod schema
// in ainews-content's tests/curriculum-schema.test.ts. If THIS test passes
// here AND THAT test passes there, the JSON contract is in sync between
// backend and iOS. Schema drift is caught at PR time.

private func loadCurriculumFixture() throws -> Data {
    guard let url = Bundle(for: CurriculumBundleClass.self).url(
        forResource: "curriculum-v1",
        withExtension: "json"
    ) else {
        throw NSError(domain: "TestFixture", code: -1, userInfo: [
            NSLocalizedDescriptionKey: "curriculum-v1.json not in test bundle. Check that AINewsWeeklyTests/Fixtures/curriculum-v1.json is added to the test target's resources."
        ])
    }
    return try Data(contentsOf: url)
}
private final class CurriculumBundleClass {}

@Suite("Curriculum schema (contract test)")
struct CurriculumModelsTests {
    @Test("Decodes the canonical fixture curriculum-v1.json")
    func decodesFixture() throws {
        let data = try loadCurriculumFixture()
        let curriculum = try DigestDateFormatter.decoder().decode(Curriculum.self, from: data)
        #expect(curriculum.schemaVersion == CURRENT_CURRICULUM_SCHEMA_VERSION)
        #expect(curriculum.tracks.count == 3)
        #expect(curriculum.tracks.map(\.id) == ["beginner", "intermediate", "advanced"])
    }

    @Test("First lesson has 7 steps and matches the curated content")
    func firstLessonShape() throws {
        let curriculum = try decode()
        let first = try #require(curriculum.tracks.first?.lessons.first)
        #expect(first.id == "setup-claude-code")
        #expect(first.title == "Setting up Claude Code")
        #expect(first.steps.count == 7)
        #expect(first.estimatedMinutes == 15)
        #expect(first.category == .anthropic)
        #expect(first.isProContent == false)
    }

    @Test("Step IDs follow the no-zero-pad step-N convention")
    func stepIdsValid() throws {
        let curriculum = try decode()
        let regex = #/^step-[1-9]\d*$/#
        for track in curriculum.tracks {
            for lesson in track.lessons {
                for step in lesson.steps {
                    let matched = (try? regex.wholeMatch(in: step.id)) != nil
                    #expect(matched, "step.id '\(step.id)' must match step-N (no zero-pad)")
                }
            }
        }
    }

    @Test("All step types in the fixture are valid StepType cases")
    func stepTypesEnumerated() throws {
        let curriculum = try decode()
        let observed = Set(curriculum.tracks.flatMap { $0.lessons.flatMap { $0.steps.map(\.stepType) } })
        let expected: Set<StepType> = [.read, .runCommand, .verify]
        #expect(observed.isSubset(of: expected))
        // The first lesson is meant to mix all three types — that's the curriculum's whole point.
        #expect(observed.contains(.runCommand))
    }

    @Test("Round-trip: encode then decode matches the original")
    func roundTrip() throws {
        let curriculum = try decode()
        let encoded = try DigestDateFormatter.encoder().encode(curriculum)
        let decoded = try DigestDateFormatter.decoder().decode(Curriculum.self, from: encoded)
        #expect(curriculum == decoded)
    }

    @Test("updatedAt decodes to a UTC-aware instant (decoder accepts the strict format)")
    func updatedAtIsUTC() throws {
        let curriculum = try decode()
        let calendar = Calendar(identifier: .gregorian)
        let comps = calendar.dateComponents(in: TimeZone(identifier: "UTC")!, from: curriculum.updatedAt)
        #expect(comps.year != nil)
        // Strict UTC ISO-8601 has no fractional seconds — verify by re-encoding
        // and checking the result has no '.' before the trailing Z.
        let reencoded = try DigestDateFormatter.encoder().encode(curriculum)
        let reencodedString = String(data: reencoded, encoding: .utf8) ?? ""
        #expect(reencodedString.contains("\"updatedAt\""))
        #expect(!reencodedString.contains(".000Z"))
    }

    @Test("Rejects fractional-second updatedAt (strict UTC contract)")
    func rejectsFractionalSeconds() {
        let bad = #"{"schemaVersion":1,"updatedAt":"2026-04-30T12:00:00.123Z","tracks":[]}"#
        #expect(throws: DecodingError.self) {
            try DigestDateFormatter.decoder().decode(Curriculum.self, from: Data(bad.utf8))
        }
    }

    @Test("Rejects non-UTC offset updatedAt")
    func rejectsNonUTCOffset() {
        let bad = #"{"schemaVersion":1,"updatedAt":"2026-04-30T12:00:00+01:00","tracks":[]}"#
        #expect(throws: DecodingError.self) {
            try DigestDateFormatter.decoder().decode(Curriculum.self, from: Data(bad.utf8))
        }
    }

    @Test("Every prerequisite refers to a lesson that exists")
    func prerequisitesResolve() throws {
        let curriculum = try decode()
        let allLessonIds = Set(curriculum.tracks.flatMap { $0.lessons.map(\.id) })
        for track in curriculum.tracks {
            for lesson in track.lessons {
                for prereq in lesson.prerequisites {
                    #expect(allLessonIds.contains(prereq), "prereq '\(prereq)' missing from curriculum")
                }
            }
        }
    }

    @Test("LessonProgress and TutorMessage round-trip cleanly")
    func progressShapesRoundTrip() throws {
        let msg = TutorMessage(
            id: "msg-1",
            role: .user,
            body: "I'm stuck on step 4",
            timestamp: Date(timeIntervalSince1970: 1735689600) // strict-UTC representable
        )
        let progress = LessonProgress(
            lessonId: "setup-claude-code",
            startedAt: Date(timeIntervalSince1970: 1735689600),
            completedAt: nil,
            completedStepIds: ["step-1", "step-2"],
            tutorTranscript: [msg]
        )
        let encoded = try DigestDateFormatter.encoder().encode(progress)
        let decoded = try DigestDateFormatter.decoder().decode(LessonProgress.self, from: encoded)
        #expect(decoded == progress)
        // Derived count
        let userMessageCount = decoded.tutorTranscript.filter { $0.role == .user }.count
        #expect(userMessageCount == 1)
    }

    // MARK: - Helpers

    private func decode() throws -> Curriculum {
        let data = try loadCurriculumFixture()
        return try DigestDateFormatter.decoder().decode(Curriculum.self, from: data)
    }
}
