import SwiftUI

struct LearnHomeView: View {
    @Environment(CurriculumService.self) private var curriculumService
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @State private var showStats = false

    var body: some View {
        mainContent
            .task { await curriculumService.loadCurriculum() }
            .sheet(isPresented: $showStats) {
                ProgressStatsView()
            }
    }

    @ViewBuilder
    private var mainContent: some View {
        switch curriculumService.state {
        case .idle, .loading:
            iPhoneLayout { LearnSkeleton() }
        case .loaded(let curriculum):
            if hSizeClass == .regular {
                iPadSplitView(curriculum: curriculum)
            } else {
                iPhoneLayout {
                    LearnScroll(
                        curriculum: curriculum,
                        isFromCache: curriculumService.isFromCache,
                        showStats: $showStats
                    )
                }
            }
        case .empty:
            iPhoneLayout {
                LearnEmptyView { Task { await curriculumService.loadCurriculum() } }
            }
        case .schemaMismatch(let received, let known):
            iPhoneLayout { LearnSchemaMismatchView(received: received, known: known) }
        case .failed(let message):
            iPhoneLayout {
                LearnFailedView(message: message) { Task { await curriculumService.loadCurriculum() } }
            }
        }
    }

    private func iPhoneLayout<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        NavigationStack {
            content()
                .navigationTitle("Learn")
                .navigationBarTitleDisplayMode(.inline)
                .background(Color.inkCream.ignoresSafeArea())
                .refreshable { await curriculumService.forceRefresh() }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button { showStats = true } label: {
                            Image(systemName: "chart.bar.fill")
                                .foregroundStyle(Color.inkAmber)
                        }
                    }
                }
        }
        .tint(.inkAmber)
    }

    private func iPadSplitView(curriculum: Curriculum) -> some View {
        iPadLearnSplitView(
            curriculum: curriculum,
            isFromCache: curriculumService.isFromCache,
            showStats: $showStats,
            onRefresh: { await curriculumService.forceRefresh() }
        )
    }
}

// MARK: - iPad Split View

private struct iPadLearnSplitView: View {
    let curriculum: Curriculum
    let isFromCache: Bool
    @Binding var showStats: Bool
    let onRefresh: () async -> Void

    @State private var selectedTrack: CurriculumTrack?

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailContent
        }
        .tint(.inkAmber)
    }

    private var sidebar: some View {
        List(selection: $selectedTrack) {
            if isFromCache {
                offlineBadge
            }
            Section {
                ForEach(curriculum.tracks.sorted { $0.order < $1.order }) { track in
                    TrackSidebarRow(track: track)
                        .tag(track)
                }
            } header: {
                Text("Tracks")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.inkTextTertiary)
            }
        }
        .listStyle(.sidebar)
        .background(Color.inkCream)
        .navigationTitle("Learn")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showStats = true } label: {
                    Image(systemName: "chart.bar.fill")
                        .foregroundStyle(Color.inkAmber)
                }
            }
        }
        .refreshable { await onRefresh() }
    }

    @ViewBuilder
    private var detailContent: some View {
        if let track = selectedTrack {
            TrackDetailView(track: track)
        } else {
            VStack(spacing: 20) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.inkAmber)
                Text("Select a track to begin")
                    .font(.system(.title2, design: .serif).weight(.semibold))
                    .foregroundStyle(Color.inkText)
                Text("Choose Beginner, Intermediate, or Advanced\nfrom the sidebar.")
                    .font(.callout)
                    .foregroundStyle(Color.inkTextSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.inkCream.ignoresSafeArea())
        }
    }

    private var offlineBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "wifi.slash")
                .font(.caption2)
            Text("Offline — showing cached content")
                .font(.caption2)
        }
        .foregroundStyle(Color.inkTextSecondary)
        .listRowBackground(Color.inkAmberSoft)
    }
}

private struct TrackSidebarRow: View {
    @Environment(LessonProgressStore.self) private var progressStore
    let track: CurriculumTrack

    private var completed: Int { progressStore.completedCount(in: track) }
    private var total: Int { track.lessons.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(track.title)
                .font(.system(.body, design: .serif).weight(.semibold))
                .foregroundStyle(Color.inkText)
            Text("\(completed)/\(total) lessons")
                .font(.caption)
                .foregroundStyle(Color.inkTextSecondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - iPhone Scroll

private struct LearnScroll: View {
    let curriculum: Curriculum
    let isFromCache: Bool
    @Binding var showStats: Bool
    @State private var searchText = ""

    private var allLessons: [(lesson: Lesson, track: CurriculumTrack)] {
        curriculum.tracks.sorted { $0.order < $1.order }.flatMap { track in
            track.lessons.map { (lesson: $0, track: track) }
        }
    }

    private var filteredLessons: [(lesson: Lesson, track: CurriculumTrack)] {
        guard !searchText.isEmpty else { return [] }
        let q = searchText.lowercased()
        return allLessons.filter {
            $0.lesson.title.lowercased().contains(q) ||
            $0.lesson.oneLineDescription.lowercased().contains(q) ||
            $0.track.title.lowercased().contains(q)
        }
    }

    var body: some View {
        ScrollView {
            if isFromCache {
                offlineBanner
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
            }
            if searchText.isEmpty {
                VStack(alignment: .leading, spacing: 24) {
                    LearnHero()
                    tracksSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            } else {
                searchResults
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
            }
        }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search lessons")
        .navigationDestination(for: CurriculumTrack.self) { track in
            TrackDetailView(track: track)
        }
        .navigationDestination(for: Lesson.self) { lesson in
            LessonDetailView(lesson: lesson)
        }
    }

    private var offlineBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.caption)
            Text("Offline — showing cached lessons")
                .font(.caption)
            Spacer()
        }
        .foregroundStyle(Color.inkTextSecondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.inkAmberSoft)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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

    private var searchResults: some View {
        VStack(spacing: 12) {
            if filteredLessons.isEmpty {
                Text("No lessons match \"\(searchText)\"")
                    .font(.callout)
                    .foregroundStyle(Color.inkTextSecondary)
                    .padding(.top, 40)
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(filteredLessons, id: \.lesson.id) { pair in
                    NavigationLink(value: pair.lesson) {
                        SearchResultRow(lesson: pair.lesson, trackTitle: pair.track.title)
                    }
                    .buttonStyle(.plain)
                }
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
    @Environment(LessonProgressStore.self) private var progressStore

    let track: CurriculumTrack

    private var lessonCount: Int { track.lessons.count }
    private var completedCount: Int { progressStore.completedCount(in: track) }

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
                Text(progressLabel)
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

    private var progressLabel: String {
        switch lessonCount {
        case 0: return "Coming soon"
        case 1 where completedCount == 1: return "1 of 1 lesson complete"
        case 1: return "1 lesson"
        default:
            if completedCount > 0 {
                return "\(completedCount) of \(lessonCount) lessons complete"
            }
            return "\(lessonCount) lessons"
        }
    }
}

private struct SearchResultRow: View {
    let lesson: Lesson
    let trackTitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(lesson.title)
                .font(.system(.subheadline, design: .serif).weight(.semibold))
                .foregroundStyle(Color.inkText)
            Text(lesson.oneLineDescription)
                .font(.caption)
                .foregroundStyle(Color.inkTextSecondary)
                .lineLimit(2)
            HStack(spacing: 4) {
                Text(trackTitle)
                    .font(.caption2)
                    .foregroundStyle(Color.inkAmber)
                Text("·")
                    .font(.caption2)
                    .foregroundStyle(Color.inkTextTertiary)
                Text("\(lesson.estimatedMinutes) min")
                    .font(.caption2)
                    .foregroundStyle(Color.inkTextTertiary)
            }
        }
        .padding(14)
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
