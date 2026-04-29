import SwiftUI

// LearnHomeView — Tab 2 hero. Three track cards (Beginner, Intermediate,
// Advanced), each showing lesson count and (in Weekend 3) progress.
// Read-only render in v2 Weekend 2; LessonProgressStore wires up next.
//
//      ┌───────────────────────────────────────────┐
//      │ Learn                                     │   nav title
//      ├───────────────────────────────────────────┤
//      │  Learn AI Tools                           │   hero
//      │  Hands-on lessons. Beginner to advanced.  │
//      │                                           │
//      │  ┌─────────────────────────────────────┐  │
//      │  │ Beginner                            │  │
//      │  │ Set up the AI tools every builder…  │  │
//      │  │ 1 lesson                            │  │
//      │  └─────────────────────────────────────┘  │
//      │  ┌─────────────────────────────────────┐  │
//      │  │ Intermediate                        │  │
//      │  │ ...                                 │  │
//      │  │ Coming soon                         │  │
//      │  └─────────────────────────────────────┘  │
//      └───────────────────────────────────────────┘
struct LearnHomeView: View {
    @Environment(CurriculumService.self) private var curriculumService

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Learn")
                .navigationBarTitleDisplayMode(.inline)
                .task { await curriculumService.loadCurriculum() }
                .refreshable { await curriculumService.forceRefresh() }
                .background(Color.inkCream.ignoresSafeArea())
        }
        .tint(.inkAmber)
    }

    @ViewBuilder
    private var content: some View {
        switch curriculumService.state {
        case .idle, .loading:
            LearnSkeleton()
        case .loaded(let curriculum):
            LearnScroll(curriculum: curriculum)
        case .empty:
            LearnEmptyView { Task { await curriculumService.loadCurriculum() } }
        case .schemaMismatch(let received, let known):
            LearnSchemaMismatchView(received: received, known: known)
        case .failed(let message):
            LearnFailedView(message: message) { Task { await curriculumService.loadCurriculum() } }
        }
    }
}

private struct LearnScroll: View {
    let curriculum: Curriculum

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                LearnHero()
                tracksSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .navigationDestination(for: CurriculumTrack.self) { track in
            TrackDetailView(track: track)
        }
    }

    private var tracksSection: some View {
        VStack(spacing: 14) {
            ForEach(curriculum.tracks.sorted { $0.order < $1.order }) { track in
                NavigationLink(value: track) {
                    TrackCard(track: track)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct LearnHero: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Learn AI Tools")
                .font(.system(size: 36, weight: .semibold, design: .serif))
                .foregroundStyle(Color.inkText)
            Text("Hands-on lessons. Beginner to advanced.")
                .font(.callout)
                .foregroundStyle(Color.inkTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TrackCard: View {
    let track: CurriculumTrack

    private var lessonCount: Int { track.lessons.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(track.title)
                .font(.system(.title3, design: .serif).weight(.semibold))
                .foregroundStyle(Color.inkText)
            Text(track.description)
                .font(.subheadline)
                .foregroundStyle(Color.inkTextSecondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                Image(systemName: "book.closed")
                    .foregroundStyle(Color.inkAmber)
                Text(lessonCountLabel)
                    .font(.caption)
                    .foregroundStyle(Color.inkTextTertiary)
            }
            .padding(.top, 2)
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

    private var lessonCountLabel: String {
        switch lessonCount {
        case 0: return "Coming soon"
        case 1: return "1 lesson"
        default: return "\(lessonCount) lessons"
        }
    }
}

// MARK: - Empty / loading / error states

private struct LearnSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            RoundedRectangle(cornerRadius: 6).fill(Color.inkAmberSoft).frame(width: 220, height: 36)
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 12).fill(Color.inkAmberSoft).frame(height: 110)
            }
        }
        .padding(20)
    }
}

private struct LearnEmptyView: View {
    let onRetry: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "books.vertical")
                .font(.system(size: 48))
                .foregroundStyle(Color.inkAmber)
            Text("No lessons yet")
                .font(.system(.title2, design: .serif).weight(.semibold))
                .foregroundStyle(Color.inkText)
            Text("Pull down to retry, or tap below.")
                .font(.callout)
                .foregroundStyle(Color.inkTextSecondary)
            Button("Retry", action: onRetry)
                .buttonStyle(.borderedProminent)
                .tint(.inkAmber)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 80)
    }
}

private struct LearnSchemaMismatchView: View {
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
            Text("New lessons use a newer format. Update AINews to see them.")
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

private struct LearnFailedView: View {
    let message: String
    let onRetry: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(Color.inkAmber)
            Text("Couldn't load lessons")
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
