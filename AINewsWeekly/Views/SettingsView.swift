import SwiftUI

// SettingsView — last updated, bookmarks list, force refresh, About.
// Bookmarks store full LearnItem snapshots so they survive Learn rotation.
struct SettingsView: View {
    @Environment(DigestService.self) private var digestService
    @Environment(BookmarksStore.self) private var bookmarksStore

    @State private var showAboutSheet = false

    var body: some View {
        Form {
            lastUpdatedSection
            bookmarksSection
            actionsSection
            aboutSection
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(Color.inkCream.ignoresSafeArea())
        .sheet(isPresented: $showAboutSheet) {
            AboutSheet()
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var lastUpdatedSection: some View {
        Section("Last updated") {
            switch digestService.state {
            case .loaded(let digest, let isStale):
                HStack {
                    Image(systemName: "calendar")
                        .foregroundStyle(Color.inkAmber)
                    VStack(alignment: .leading) {
                        Text(formatted(digest.reportGeneratedAt))
                            .foregroundStyle(Color.inkText)
                        if isStale {
                            Text("Stale — pull to refresh")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }
            default:
                Text("No digest loaded yet")
                    .foregroundStyle(Color.inkTextSecondary)
            }
        }
    }

    private var bookmarksSection: some View {
        Section("Bookmarks") {
            if bookmarksStore.isEmpty {
                Text("No bookmarks yet. Tap the bookmark icon on any tool to save it here.")
                    .font(.callout)
                    .foregroundStyle(Color.inkTextSecondary)
            } else {
                ForEach(bookmarksStore.sortedBookmarks) { item in
                    NavigationLink(value: item) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name)
                                .font(.system(.body, design: .serif).weight(.semibold))
                                .foregroundStyle(Color.inkText)
                            Text(item.oneLineDescription)
                                .font(.caption)
                                .foregroundStyle(Color.inkTextSecondary)
                                .lineLimit(2)
                        }
                    }
                }
                .onDelete { offsets in
                    let items = bookmarksStore.sortedBookmarks
                    for offset in offsets {
                        bookmarksStore.remove(id: items[offset].id)
                    }
                }
            }
        }
        .navigationDestination(for: LearnItem.self) { item in
            LearnDetailView(item: item)
        }
    }

    private var actionsSection: some View {
        Section {
            Button {
                Task { await digestService.forceRefresh() }
            } label: {
                Label("Force refresh", systemImage: "arrow.clockwise")
                    .foregroundStyle(Color.inkAmber)
            }
        }
    }

    private var aboutSection: some View {
        Section {
            Button {
                showAboutSheet = true
            } label: {
                Label("About AINews Weekly", systemImage: "info.circle")
                    .foregroundStyle(Color.inkText)
            }
        }
    }

    // MARK: -

    private func formatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .short
        f.locale = Locale.current
        return f.string(from: date)
    }
}

private struct AboutSheet: View {
    @Environment(\.dismiss) private var dismiss

    private var version: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "v\(v) (\(b))"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                Text("AINews Weekly")
                    .font(.system(size: 32, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.inkText)
                Text("AI digest for builders")
                    .font(.system(.body, design: .serif).italic())
                    .foregroundStyle(Color.inkTextSecondary)
                Text(version)
                    .font(.caption)
                    .foregroundStyle(Color.inkTextTertiary)
                    .padding(.top, 6)
                Spacer()
                VStack(spacing: 8) {
                    Link("Source on GitHub", destination: URL(string: "https://github.com/aquibaserfati-hub/ainews-app")!)
                    Link("Privacy policy", destination: URL(string: "https://aquibaserfati-hub.github.io/ainews-content/privacy/")!)
                }
                .font(.callout)
                .foregroundStyle(Color.inkAmber)
                .padding(.bottom, 32)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 24)
            .padding(.top, 32)
            .background(Color.inkCream.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.inkAmber)
                }
            }
        }
    }
}
