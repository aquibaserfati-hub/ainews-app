import Testing
import Foundation
@testable import AINewsWeekly

// BookmarksStoreTests — verifies the snapshot-not-id design (locked via
// /plan-eng-review Issue 7). The critical scenario: a user bookmarks an
// item from this week's digest. Next week's digest replaces learn[].
// The bookmark MUST still resolve to the saved content — no broken rows,
// no silent drops.

@MainActor
private func makeStore() -> BookmarksStore {
    let suite = "ainews.bookmarks.test.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return BookmarksStore(defaults: defaults)
}

private func makeItem(id: String, name: String, category: AINewsWeekly.Category = .tooling) -> LearnItem {
    LearnItem(
        id: id,
        name: name,
        category: category,
        oneLineDescription: "One-line description for \(name).",
        estimatedSetupMinutes: 5,
        detail: LearnDetail(
            whatItDoes: "Does \(name) things.",
            whoItsFor: "Builders.",
            pros: ["Pro 1", "Pro 2"],
            cons: ["Con 1"],
            setupGuideMarkdown: "## Install\n\n```bash\nnpm install \(id)\n```",
            sourceURL: URL(string: "https://example.com/\(id)")!
        )
    )
}

@MainActor
@Suite("BookmarksStore")
struct BookmarksStoreTests {
    @Test("Empty by default")
    func emptyByDefault() {
        let store = makeStore()
        #expect(store.isEmpty)
        #expect(store.sortedBookmarks.isEmpty)
    }

    @Test("Toggle adds and removes bookmarks")
    func toggleAddsAndRemoves() {
        let store = makeStore()
        let item = makeItem(id: "tool-x", name: "Tool X")
        store.toggle(item)
        #expect(store.isBookmarked("tool-x"))
        #expect(store.sortedBookmarks.count == 1)

        store.toggle(item)
        #expect(!store.isBookmarked("tool-x"))
        #expect(store.isEmpty)
    }

    @Test("Bookmarks persist across instances (UserDefaults round-trip)")
    func persistsAcrossInstances() {
        let suite = "ainews.bookmarks.test.persist.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let firstStore = BookmarksStore(defaults: defaults)
        firstStore.toggle(makeItem(id: "alpha", name: "Alpha"))
        firstStore.toggle(makeItem(id: "beta", name: "Beta"))

        // Simulate app relaunch: new instance, same UserDefaults suite.
        let secondStore = BookmarksStore(defaults: defaults)
        #expect(secondStore.isBookmarked("alpha"))
        #expect(secondStore.isBookmarked("beta"))
        #expect(secondStore.sortedBookmarks.map(\.name) == ["Alpha", "Beta"])
    }

    // CRITICAL: the snapshot-survives-rotation test. This is the bug Issue 7
    // was fixing — bookmarks pointing at IDs that disappear next week.
    @Test("Bookmark survives a Learn-section rotation (snapshot stored, not just ID)")
    func snapshotSurvivesRotation() {
        let store = makeStore()
        let item = makeItem(id: "llama-cpp-2", name: "llama.cpp 2.0")
        store.toggle(item)

        // The original LearnItem reference is gone (next week's digest doesn't
        // include it). Store should still have the FULL snapshot.
        #expect(store.isBookmarked("llama-cpp-2"))
        let snapshot = store.bookmarks["llama-cpp-2"]
        #expect(snapshot != nil)
        #expect(snapshot?.name == "llama.cpp 2.0")
        #expect(snapshot?.detail.whatItDoes == "Does llama.cpp 2.0 things.")
        #expect(snapshot?.detail.setupGuideMarkdown.contains("npm install") == true)
    }

    @Test("Sorted alphabetically by name (case-insensitive)")
    func sortedAlphabetically() {
        let store = makeStore()
        store.toggle(makeItem(id: "b", name: "beta"))
        store.toggle(makeItem(id: "a", name: "Alpha"))
        store.toggle(makeItem(id: "g", name: "gamma"))
        #expect(store.sortedBookmarks.map(\.name) == ["Alpha", "beta", "gamma"])
    }

    @Test("Remove by id")
    func removeById() {
        let store = makeStore()
        store.toggle(makeItem(id: "x", name: "X"))
        store.toggle(makeItem(id: "y", name: "Y"))
        store.remove(id: "x")
        #expect(!store.isBookmarked("x"))
        #expect(store.isBookmarked("y"))
    }

    @Test("Corrupt UserDefaults data does not crash")
    func corruptDataResetsToEmpty() {
        let suite = "ainews.bookmarks.test.corrupt.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.set("not valid json".data(using: .utf8), forKey: "ainews.bookmarks.v1")

        let store = BookmarksStore(defaults: defaults)
        #expect(store.isEmpty)
    }
}
