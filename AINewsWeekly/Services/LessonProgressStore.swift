import Foundation
import Observation

// LessonProgressStore — persists per-lesson progress (which steps are
// done, when started, when completed, tutor transcript) to UserDefaults.
//
// Mirrors BookmarksStore's pattern: JSON-encoded [String: LessonProgress]
// keyed by lesson.id under a single UserDefaults key. Per-lesson progress
// is local to the device — there is no cross-device sync in v2.
//
// Tutor transcripts ride alongside completion state inside LessonProgress.
// Acknowledged limitation (eng review Q3): if a single lesson's transcript
// grows past ~500 messages, we'll refactor to a dedicated TutorTranscriptStore.
// At v2 scale (5-10 messages per lesson), inlining is fine.
@MainActor
@Observable
final class LessonProgressStore {
    private static let userDefaultsKey = "ainews.lesson-progress.v1"

    private(set) var progress: [String: LessonProgress] = [:]

    private let defaults: UserDefaults
    private let now: () -> Date

    init(defaults: UserDefaults = .standard, now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.now = now
        load()
    }

    // MARK: - Queries

    func progress(for lessonId: String) -> LessonProgress? {
        progress[lessonId]
    }

    func isStepDone(lessonId: String, stepId: String) -> Bool {
        progress[lessonId]?.completedStepIds.contains(stepId) ?? false
    }

    func isLessonComplete(_ lessonId: String) -> Bool {
        progress[lessonId]?.completedAt != nil
    }

    func isLessonStarted(_ lessonId: String) -> Bool {
        progress[lessonId] != nil
    }

    // Track-level progress: count of fully-completed lessons / total non-empty lessons.
    func completedCount(in track: CurriculumTrack) -> Int {
        track.lessons.filter { isLessonComplete($0.id) }.count
    }

    // Per-lesson step progress: completed steps / total steps.
    func stepProgress(for lesson: Lesson) -> (done: Int, total: Int) {
        let total = lesson.steps.count
        let done = progress[lesson.id]?.completedStepIds.count ?? 0
        // Clamp `done` to `total` — completedStepIds may include stale IDs if
        // the lesson's steps are re-numbered after a curriculum republish.
        return (min(done, total), total)
    }

    // True iff the user has done at least one but not all steps of the lesson.
    func isLessonInProgress(_ lesson: Lesson) -> Bool {
        let p = stepProgress(for: lesson)
        return p.done > 0 && p.done < p.total
    }

    // MARK: - Mutations (step completion)

    // Toggle a step's done state. Auto-promotes to "lesson complete" when
    // every step has been marked done. Auto-promotes to "lesson started"
    // on the first step toggled.
    func toggleStep(lesson: Lesson, stepId: String) {
        var current = progress[lesson.id] ?? LessonProgress(
            lessonId: lesson.id,
            startedAt: now(),
            completedAt: nil,
            completedStepIds: [],
            tutorTranscript: []
        )

        var stepIds = current.completedStepIds
        if let idx = stepIds.firstIndex(of: stepId) {
            stepIds.remove(at: idx)
        } else {
            stepIds.append(stepId)
        }

        // Lesson "complete" when EVERY step in the current curriculum.json
        // shape is in stepIds. Use Set semantics in case duplicates somehow
        // crept in.
        let allLessonStepIds = Set(lesson.steps.map(\.id))
        let completedSet = Set(stepIds)
        let isComplete = allLessonStepIds.isSubset(of: completedSet) && !allLessonStepIds.isEmpty
        let completedAt = isComplete ? (current.completedAt ?? now()) : nil

        let updated = LessonProgress(
            lessonId: current.lessonId,
            startedAt: current.startedAt ?? now(),
            completedAt: completedAt,
            completedStepIds: stepIds,
            tutorTranscript: current.tutorTranscript
        )
        progress[lesson.id] = updated
        persist()
    }

    // Reset a lesson's progress (used by Settings → "Reset progress" in v3).
    func reset(lessonId: String) {
        progress.removeValue(forKey: lessonId)
        persist()
    }

    // MARK: - Mutations (tutor transcript) — wired by Weekend 5

    func appendTutorMessage(lessonId: String, message: TutorMessage) {
        let current = progress[lessonId] ?? LessonProgress(
            lessonId: lessonId,
            startedAt: now(),
            completedAt: nil,
            completedStepIds: [],
            tutorTranscript: []
        )
        let updated = LessonProgress(
            lessonId: current.lessonId,
            startedAt: current.startedAt ?? now(),
            completedAt: current.completedAt,
            completedStepIds: current.completedStepIds,
            tutorTranscript: current.tutorTranscript + [message]
        )
        progress[lessonId] = updated
        persist()
    }

    // Replaces the body of the most recent assistant message — used by
    // TutorChatView to grow a streaming assistant response in-place
    // without appending a new TutorMessage per delta.
    func replaceLastAssistantMessage(lessonId: String, body: String) {
        guard let current = progress[lessonId] else { return }
        guard let lastIndex = current.tutorTranscript.lastIndex(where: { $0.role == .assistant }) else { return }
        var transcript = current.tutorTranscript
        let old = transcript[lastIndex]
        transcript[lastIndex] = TutorMessage(
            id: old.id,
            role: old.role,
            body: body,
            timestamp: old.timestamp
        )
        let updated = LessonProgress(
            lessonId: current.lessonId,
            startedAt: current.startedAt,
            completedAt: current.completedAt,
            completedStepIds: current.completedStepIds,
            tutorTranscript: transcript
        )
        progress[lessonId] = updated
        persist()
    }

    // Drops the trailing assistant placeholder when a streamed response
    // errors out before the first delta. Keeps transcript clean of empty
    // assistant bubbles.
    func dropLastAssistantPlaceholder(lessonId: String) {
        guard let current = progress[lessonId] else { return }
        guard let last = current.tutorTranscript.last,
              last.role == .assistant,
              last.body.isEmpty
        else { return }
        let trimmed = Array(current.tutorTranscript.dropLast())
        let updated = LessonProgress(
            lessonId: current.lessonId,
            startedAt: current.startedAt,
            completedAt: current.completedAt,
            completedStepIds: current.completedStepIds,
            tutorTranscript: trimmed
        )
        progress[lessonId] = updated
        persist()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = defaults.data(forKey: Self.userDefaultsKey) else {
            progress = [:]
            return
        }
        do {
            progress = try DigestDateFormatter.decoder().decode([String: LessonProgress].self, from: data)
        } catch {
            // Corrupt store — start fresh. Same loss-of-data policy as BookmarksStore.
            progress = [:]
        }
    }

    private func persist() {
        do {
            let data = try DigestDateFormatter.encoder().encode(progress)
            defaults.set(data, forKey: Self.userDefaultsKey)
        } catch {
            // Best-effort.
        }
    }
}
