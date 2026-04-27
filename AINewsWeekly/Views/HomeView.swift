import SwiftUI

// HomeView — the marquee screen. Hero card with the AI Report TL;DR,
// then the Learn directory of new tools/repos. Editorial layout on cream.
//
//      ┌───────────────────────────────────────────┐
//      │ AINews                              [⚙]   │   nav
//      ├───────────────────────────────────────────┤
//      │  ┌─────────────────────────────────────┐  │
//      │  │ AI Report                           │  │   hero card
//      │  │ Week of April 20, 2026              │  │
//      │  │ • [tag] Anthropic ships memory API  │  │
//      │  │ • [tag] Opus 4.7 lands              │  │
//      │  │   ...                               │  │
//      │  └─────────────────────────────────────┘  │
//      │                                           │
//      │  Learn                                    │   section
//      │                                           │
//      │  ┌─────────────────────────────────────┐  │
//      │  │ [tag] Claude Memory API             │  │   learn card
//      │  │ One-line description here...        │  │
//      │  │ ⏱ 8 min setup                       │  │
//      │  └─────────────────────────────────────┘  │
//      │  ...                                      │
//      └───────────────────────────────────────────┘
struct HomeView: View {
    @Environment(DigestService.self) private var digestService
    @Environment(BookmarksStore.self) private var bookmarksStore

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("AINews")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink {
                            SettingsView()
                        } label: {
                            Image(systemName: "gearshape")
                                .foregroundStyle(Color.inkText)
                        }
                        .accessibilityLabel("Settings")
                    }
                }
                .task { await digestService.loadDigest() }
                .refreshable { await digestService.forceRefresh() }
                .background(Color.inkCream.ignoresSafeArea())
        }
        .tint(.inkAmber)
    }

    @ViewBuilder
    private var content: some View {
        switch digestService.state {
        case .idle, .loading:
            SkeletonView()
        case .loaded(let digest, let isStale):
            DigestScroll(digest: digest, isStale: isStale)
        case .empty:
            EmptyDigestView { Task { await digestService.loadDigest() } }
        case .schemaMismatch(let received, let known):
            SchemaMismatchView(received: received, known: known)
        case .failed(let message):
            FailedView(message: message) { Task { await digestService.loadDigest() } }
        }
    }
}

// MARK: - Loaded state

private struct DigestScroll: View {
    let digest: Digest
    let isStale: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if isStale {
                    StaleBanner(reportGeneratedAt: digest.reportGeneratedAt)
                }
                HeroCard(weekOf: digest.weekOf, report: digest.report)
                LearnSection(items: digest.learn)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
    }
}

private struct HeroCard: View {
    let weekOf: Date
    let report: [ReportBullet]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("AI Report")
                    .font(.system(size: 36, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.inkText)
                Text("Week of \(formatted(weekOf))")
                    .font(.callout)
                    .foregroundStyle(Color.inkTextSecondary)
            }

            Divider().background(Color.inkAmberSoft)

            VStack(alignment: .leading, spacing: 14) {
                ForEach(report) { item in
                    ReportRow(item: item)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.inkCard)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.inkAmberSoft, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func formatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .none
        f.locale = Locale.current
        return f.string(from: date)
    }
}

private struct ReportRow: View {
    let item: ReportBullet

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            CategoryDot(category: item.category)
                .padding(.top, 6)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(.headline, design: .serif))
                    .foregroundStyle(Color.inkText)
                Text(item.summary)
                    .font(.subheadline)
                    .foregroundStyle(Color.inkTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct LearnSection: View {
    let items: [LearnItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Learn")
                .font(.system(size: 28, weight: .semibold, design: .serif))
                .foregroundStyle(Color.inkText)

            VStack(spacing: 12) {
                ForEach(items) { item in
                    NavigationLink(value: item) {
                        LearnCard(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationDestination(for: LearnItem.self) { item in
            LearnDetailView(item: item)
        }
    }
}

private struct LearnCard: View {
    let item: LearnItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                CategoryTag(category: item.category)
                Spacer()
                if let mins = item.estimatedSetupMinutes {
                    Label("\(mins) min setup", systemImage: "clock")
                        .labelStyle(.titleAndIcon)
                        .font(.caption)
                        .foregroundStyle(Color.inkTextTertiary)
                }
            }
            Text(item.name)
                .font(.system(.title3, design: .serif).weight(.semibold))
                .foregroundStyle(Color.inkText)
            Text(item.oneLineDescription)
                .font(.subheadline)
                .foregroundStyle(Color.inkTextSecondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.inkCard)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.inkAmberSoft, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Empty / loading / error states

private struct SkeletonView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Hero skeleton.
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.inkAmberSoft)
                .frame(height: 240)
            // Section header skeleton.
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.inkAmberSoft)
                .frame(width: 100, height: 28)
            // Learn cards skeleton.
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.inkAmberSoft)
                    .frame(height: 110)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct StaleBanner: View {
    let reportGeneratedAt: Date

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundStyle(Color.inkAmber)
            Text("Last updated \(relativeTime). Pull down to refresh.")
                .font(.footnote)
                .foregroundStyle(Color.inkText)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.inkAmberSoft)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var relativeTime: String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f.localizedString(for: reportGeneratedAt, relativeTo: Date())
    }
}

private struct EmptyDigestView: View {
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(Color.inkAmber)
            Text("No digest yet")
                .font(.system(.title2, design: .serif).weight(.semibold))
                .foregroundStyle(Color.inkText)
            Text("New issues publish daily. Pull down to retry, or tap below.")
                .font(.callout)
                .foregroundStyle(Color.inkTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Retry", action: onRetry)
                .buttonStyle(.borderedProminent)
                .tint(.inkAmber)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 80)
    }
}

private struct SchemaMismatchView: View {
    let received: Int
    let known: Int

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.up.circle")
                .font(.system(size: 48))
                .foregroundStyle(Color.inkAmber)
            Text("Update AINews")
                .font(.system(.title2, design: .serif).weight(.semibold))
                .foregroundStyle(Color.inkText)
            Text("This week's digest uses a newer format. Update AINews to see it.")
                .font(.callout)
                .foregroundStyle(Color.inkTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Text("(received v\(received), this build understands v\(known))")
                .font(.caption2)
                .foregroundStyle(Color.inkTextTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 80)
    }
}

private struct FailedView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(Color.inkAmber)
            Text("Couldn't load the digest")
                .font(.system(.title3, design: .serif).weight(.semibold))
                .foregroundStyle(Color.inkText)
            Text(message)
                .font(.footnote)
                .foregroundStyle(Color.inkTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Try again", action: onRetry)
                .buttonStyle(.borderedProminent)
                .tint(.inkAmber)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 80)
    }
}
