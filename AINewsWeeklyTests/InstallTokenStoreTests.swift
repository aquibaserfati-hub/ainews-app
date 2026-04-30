import Testing
import Foundation
@testable import AINewsWeekly

// InstallTokenStoreTests — security-critical Keychain wrapper.
// Idempotency is the load-bearing property: if subsequent calls returned
// fresh tokens, a single install could rotate tokens and bypass the
// Worker's per-install rate limit.
//
// Note: Keychain access works in iOS unit tests (test host runs the
// real Security framework against the simulator's keychain). We
// `clearForTests()` before each scenario so persisted state from a
// prior run doesn't leak.

@Suite("InstallTokenStore (Keychain)", .serialized)
struct InstallTokenStoreTests {
    @Test("First call generates a non-empty UUID-shaped token")
    func firstCallGenerates() {
        InstallTokenStore.clearForTests()
        let token = InstallTokenStore.token()
        #expect(!token.isEmpty)
        // UUID().uuidString is exactly 36 chars: 8-4-4-4-12 with hyphens.
        #expect(token.count == 36)
        // Validate UUID-ish shape: hex-and-hyphens.
        let uuidRegex = #/^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$/#
            .ignoresCase()
        let matched = (try? uuidRegex.wholeMatch(in: token)) != nil
        #expect(matched, "token should be UUID-shaped, got '\(token)'")
    }

    @Test("Subsequent calls return the SAME token (idempotent)")
    func idempotent() {
        InstallTokenStore.clearForTests()
        let first = InstallTokenStore.token()
        let second = InstallTokenStore.token()
        let third = InstallTokenStore.token()
        #expect(first == second)
        #expect(second == third)
    }

    @Test("clearForTests resets so the next call generates a fresh token")
    func clearGeneratesFresh() {
        InstallTokenStore.clearForTests()
        let first = InstallTokenStore.token()
        InstallTokenStore.clearForTests()
        let second = InstallTokenStore.token()
        #expect(first != second, "after clear, a new token must be issued")
    }

    @Test("Token survives a fresh read after write (round-trip)")
    func keychainRoundTrip() {
        InstallTokenStore.clearForTests()
        let written = InstallTokenStore.token()
        // Force a fresh read path by calling token() again — the second call
        // hits readFromKeychain() and short-circuits.
        let read = InstallTokenStore.token()
        #expect(written == read)
    }
}
