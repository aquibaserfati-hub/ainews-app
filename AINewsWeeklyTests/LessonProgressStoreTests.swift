import Testing
import Foundation
@testable import AINewsWeekly

// LessonProgressStoreTests — verifies the UserDefaults-backed progress store
// behaves correctly across step toggles, lesson completion auto-promotion,
// app restart (round-trip via UserDefaults), and corrupt-data recovery.

@Suite("LessonProgressStore")
@MainActor
struct LessonProgressStoreTests {
    // Builds a fresh, isolated store backed by an in-memory UserDefaults
    // suite so tests don't pollute each other or the real device defaults.
    private func makeStore(
        suiteName: String = "LessonProgressStoreTests-\(UUID().uuidString)",
        now: @escaping () -> Date = { Date(timeIntervalSince1970: 1_735_689_600) }
    ) -> (store: LessonProgressStore, defaults: UserDefaults, suiteName: String) {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let store = LessonProgressStore(defaults: defaults, now: now)
        return (store, defaults, suiteName)
    }

    private func sampleLesson(stepCount: Int = 3, id: String = "setup-test") -> Lesson {
        let steps = (1...stepCount).map { i in
            LessonStep(
                id: "step-\(i)",
                title: "Step \(i)",
                body: "body \(i)",
                stepType: .read,
                validationHint: nil
            )
        }
        return Lesson(
            id: id,
            trackId: "beginner",
            title: "Test Lesson",
            oneLineDescription: "test",
            estimatedMinutes: 10,
            category: .anthropic,
            prerequisites: [],
            youtubeURL: nil,
            steps: steps,
            isProContent: false
        )
    }

    @Test("Empty by default")
    func emptyByDefault() {
        let (store, _, _) = makeStore()
        #expect(store.progress.isEmpty)
        #expect(store.isStepDone(lessonId: "setup-test", stepId: "step-1") == false)
        #expect(store.isLessonComplete("setup-test") == false)
        #expect(store.isLessonStarted("setup-test") == false)
    }

    @Test("Toggle marks a step done and back to undone")
    func toggleStep() {
        let (store, _, _) = makeStore()
        let lesson = sampleLesson(stepCount: 3)
        store.toggleStep(lesson: lesson, stepId: "step-1")
        #expect(store.isStepDone(lessonId: lesson.id, stepId: "step-1"))
        #expect(store.isLessonStarted(lesson.id))

        store.toggleStep(lesson: lesson, stepId: "step-1")
        #expect(store.isStepDone(lessonId: lesson.id, stepId: "step-1") == false)
    }

    @Test("Lesson auto-completes when every step is marked done")
    func autoCompleteWhenAllSteps() {
        let (store, _, _) = makeStore()
        let lesson = sampleLesson(stepCount: 3)
        store.toggleStep(lesson: lesson, stepId: "step-1")
        store.toggleStep(lesson: lesson, stepId: "step-2")
        #expect(store.isLessonComplete(lesson.id) == false)

        store.toggleStep(lesson: lesson, stepId: "step-3")
        #expect(store.isLessonComplete(lesson.id))
        #expect(store.progress[lesson.id]?.completedAt != nil)
    }

    @Test("Un-toggling a step re-opens a completed lesson")
    func uncompletes() {
        let (store, _, _) = makeStore()
        let lesson = sampleLesson(stepCount: 2)
        store.toggleStep(lesson: lesson, stepId: "step-1")
        store.toggleStep(lesson: lesson, stepId: "step-2")
        #expect(store.isLessonComplete(lesson.id))

        store.toggleStep(lesson: lesson, stepId: "step-2")
        #expect(store.isLessonComplete(lesson.id) == false)
        #expect(store.progress[lesson.id]?.completedAt == nil)
    }

    @Test("stepProgress returns done/total counts")
    func stepProgressCounts() {
        let (store, _, _) = makeStore()
        let lesson = sampleLesson(stepCount: 5)
        store.toggleStep(lesson: lesson, stepId: "step-1")
        store.toggleStep(lesson: lesson, stepId: "step-3")

        let p = store.stepProgress(for: lesson)
        #expect(p.done == 2)
        #expect(p.total == 5)
    }

    @Test("isLessonInProgress is true with partial completion, false at zero or full")
    func lessonInProgress() {
        let (store, _, _) = makeStore()
        let lesson = sampleLesson(stepCount: 3)
        #expect(store.isLessonInProgress(lesson) == false)

        store.toggleStep(lesson: lesson, stepId: "step-1")
        #expect(store.isLessonInProgress(lesson))

        store.toggleStep(lesson: lesson, stepId: "step-2")
        store.toggleStep(lesson: lesson, stepId: "step-3")
        #expect(store.isLessonInProgress(lesson) == false)  // complete, not in-progress
    }

    @Test("Progress survives across instances (UserDefaults round-trip)")
    func roundTripsAcrossInstances() {
        let (store1, defaults, suite) = makeStore()
        let lesson = sampleLesson(stepCount: 3)
        store1.toggleStep(lesson: lesson, stepId: "step-1")
        store1.toggleStep(lesson: lesson, stepId: "step-2")

        // Simulate app relaunch: a brand-new store reads the same defaults.
        let store2 = LessonProgressStore(defaults: defaults)
        #expect(store2.isStepDone(lessonId: lesson.id, stepId: "step-1"))
        #expect(store2.isStepDone(lessonId: lesson.id, stepId: "step-2"))
        #expect(store2.isStepDone(lessonId: lesson.id, stepId: "step-3") == false)
        let p = store2.stepProgress(for: lesson)
        #expect(p.done == 2 && p.total == 3)

        defaults.removePersistentDomain(forName: suite)
    }

    @Test("Reset clears one lesson without touching others")
    func resetIsolated() {
        let (store, _, _) = makeStore()
        let l1 = sampleLesson(stepCount: 2, id: "lesson-a")
        let l2 = sampleLesson(stepCount: 2, id: "lesson-b")
        store.toggleStep(lesson: l1, stepId: "step-1")
        store.toggleStep(lesson: l2, stepId: "step-1")

        store.reset(lessonId: l1.id)
        #expect(store.progress[l1.id] == nil)
        #expect(store.isStepDone(lessonId: l2.id, stepId: "step-1"))
    }

    @Test("Tutor message append accumulates ordered transcript")
    func appendTutorMessage() {
        let (store, _, _) = makeStore()
        let lessonId = "setup-test"
        let m1 = TutorMessage(id: "m1", role: .user, body: "hi", timestamp: Date(timeIntervalSince1970: 1))
        let m2 = TutorMessage(id: "m2", role: .assistant, body: "hi back", timestamp: Date(timeIntervalSince1970: 2))
        store.appendTutorMessage(lessonId: lessonId, message: m1)
        store.appendTutorMessage(lessonId: lessonId, message: m2)

        let transcript = store.progress[lessonId]?.tutorTranscript ?? []
        #expect(transcript.map(\.id) == ["m1", "m2"])
        let userCount = transcript.filter { $0.role == .user }.count
        #expect(userCount == 1)
    }

    @Test("Corrupt UserDefaults data does not crash; store reads as empty")
    func corruptDataRecovery() {
        let suite = "LessonProgressStoreTests-corrupt-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.set(Data([0xFF, 0x00, 0xDE, 0xAD]), forKey: "ainews.lesson-progress.v1")

        let store = LessonProgressStore(defaults: defaults)
        #expect(store.progress.isEmpty)

        defaults.removePersistentDomain(forName: suite)
    }

    @Test("completedCount(in:) reflects only fully-finished lessons in the track")
    func trackCompletedCount() {
        let (store, _, _) = makeStore()
        let l1 = sampleLesson(stepCount: 2, id: "lesson-a")
        let l2 = sampleLesson(stepCount: 2, id: "lesson-b")
        let track = CurriculumTrack(
            id: "beginner",
            title: "Beginner",
            description: "test",
            order: 0,
            lessons: [l1, l2]
        )
        // l1 partial, l2 complete
        store.toggleStep(lesson: l1, stepId: "step-1")
        store.toggleStep(lesson: l2, stepId: "step-1")
        store.toggleStep(lesson: l2, stepId: "step-2")

        #expect(store.completedCount(in: track) == 1)
    }
}
