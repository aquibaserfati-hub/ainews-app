import Foundation
import Observation

// BookmarksStore — persists bookmarked LearnItems to UserDefaults.
//
// CRITICAL DESIGN DECISION (locked via /plan-eng-review Issue 7):
// We store the FULL LearnItem snapshot at bookmark time, NOT just the ID.
//
// Why: the digest's learn[] array rotates Mon/Thu (and on breaking-news
// escalation). If we stored only IDs, a bookmark created this week would
// dereference next week when its item is no longer in the current digest.
// Settings → Bookmarks would show empty rows or silently drop the entry.
// That fails Apple Guideline 4.2 review and looks broken to users.
//
// Storage format: JSON-encoded [String: LearnItem] in a single
// UserDefaults key. Capacity comfortable up to ~500 bookmarks before
// UserDefaults starts to feel slow (each LearnItem ~5-10KB).
@MainActor
@Observable
final class BookmarksStore {
    private static let userDefaultsKey = "ainews.bookmarks.v1"

    private(set) var bookmarks: [String: LearnItem] = [:]

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    var sortedBookmarks: [LearnItem] {
        bookmarks.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var isEmpty: Bool {
        bookmarks.isEmpty
    }

    func isBookmarked(_ id: String) -> Bool {
        bookmarks[id] != nil
    }

    // Toggle a bookmark. Adding stores a SNAPSHOT of the LearnItem (full
    // detail), so the bookmark survives Learn-section rotation.
    func toggle(_ item: LearnItem) {
        if bookmarks[item.id] != nil {
            bookmarks.removeValue(forKey: item.id)
        } else {
            bookmarks[item.id] = item
        }
        persist()
    }

    func remove(id: String) {
        bookmarks.removeValue(forKey: id)
        persist()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = defaults.data(forKey: Self.userDefaultsKey) else {
            bookmarks = [:]
            return
        }
        do {
            bookmarks = try DigestDateFormatter.decoder().decode([String: LearnItem].self, from: data)
        } catch {
            // Corrupt store — start fresh. Don't crash the app for a
            // bookmark store; the user's preference for the loss-of-data
            // edge case is "show empty list, don't block reading content."
            bookmarks = [:]
        }
    }

    private func persist() {
        do {
            let data = try DigestDateFormatter.encoder().encode(bookmarks)
            defaults.set(data, forKey: Self.userDefaultsKey)
        } catch {
            // Best-effort persistence. If encoding fails, the in-memory
            // state is still valid for the current session; we'll retry
            // on the next toggle.
        }
    }
}
