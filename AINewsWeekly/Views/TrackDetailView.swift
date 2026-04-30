import SwiftUI

// TrackDetailView — pushed from a TrackCard. Lists the lessons in the
// track, each as a tappable row that pushes LessonDetailView.
//
//      ┌───────────────────────────────────────────┐
//      │ ‹ Back   Beginner                         │
//      ├───────────────────────────────────────────┤
//      │  Beginner                                 │
//      │  Set up the AI tools every builder uses.  │
//      │                                           │
//      │  ┌─────────────────────────────────────┐  │
//      │  │ [Anthropic]              ⏱ 15 min   │  │
//      │  │ Setting up Claude Code              │  │
//      │  │ Install Anthropic's terminal codin… │  │
//      │  └─────────────────────────────────────┘  │
//      └───────────────────────────────────────────┘
struct TrackDetailView: View {
    @Environment(LessonProgressStore.self) private var progressStore

    let track: CurriculumTrack

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                if track.lessons.isEmpty {
                    comingSoonView
                } else {
                    lessonsList
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(Color.inkCream.ignoresSafeArea())
        .navigationTitle(track.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Lesson.self) { lesson in
            LessonDetailView(lesson: lesson)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(track.title)
                .font(.system(size: 32, weight: .semibold, design: .serif))
                .foregroundStyle(Color.inkText)
            Text(track.description)
                .font(.callout)
                .foregroundStyle(Color.inkTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var lessonsList: some View {
        VStack(spacing: 12) {
            trackProgressBadge
            ForEach(track.lessons) { lesson in
                NavigationLink(value: lesson) {
                    LessonRow(
                        lesson: lesson,
                        state: lessonState(lesson)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var trackProgressBadge: some View {
        let done = progressStore.completedCount(in: track)
        let total = track.lessons.count
        if total > 0 {
            HStack(spacing: 6) {
                Image(systemName: done == total ? "checkmark.seal.fill" : "book.closed")
                    .foregroundStyle(Color.inkAmber)
                Text("\(done) of \(total) complete")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.inkText)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.inkAmberSoft)
            .clipShape(Capsule())
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func lessonState(_ lesson: Lesson) -> LessonRowState {
        if progressStore.isLessonComplete(lesson.id) { return .complete }
        if progressStore.isLessonInProgress(lesson) { return .inProgress }
        return .notStarted
    }

    private var comingSoonView: some View {
        VStack(spacing: 12) {
            Image(systemName: "hourglass")
                .font(.system(size: 36))
                .foregroundStyle(Color.inkAmber)
            Text("Coming soon")
                .font(.system(.title3, design: .serif).weight(.semibold))
                .foregroundStyle(Color.inkText)
            Text("Lessons for this track are in the works. Beginner lessons are live now.")
                .font(.callout)
                .foregroundStyle(Color.inkTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

enum LessonRowState {
    case notStarted, inProgress, complete
}

private struct LessonRow: View {
    let lesson: Lesson
    let state: LessonRowState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ProgressDot(state: state)
                CategoryTag(category: lesson.category)
                Spacer()
                Label("\(lesson.estimatedMinutes) min", systemImage: "clock")
                    .labelStyle(.titleAndIcon)
                    .font(.caption)
                    .foregroundStyle(Color.inkTextTertiary)
            }
            Text(lesson.title)
                .font(.system(.title3, design: .serif).weight(.semibold))
                .foregroundStyle(Color.inkText)
            Text(lesson.oneLineDescription)
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
                .stroke(state == .complete ? Color.inkAmber : Color.inkAmberSoft, lineWidth: state == .complete ? 1.5 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// ProgressDot — small visual marker on each lesson row.
//   ○  notStarted     ◐  inProgress     ●  complete
private struct ProgressDot: View {
    let state: LessonRowState

    var body: some View {
        Group {
            switch state {
            case .notStarted:
                Circle()
                    .stroke(Color.inkTextTertiary, lineWidth: 1.5)
            case .inProgress:
                ZStack {
                    Circle().stroke(Color.inkAmber, lineWidth: 1.5)
                    Circle().trim(from: 0, to: 0.5).fill(Color.inkAmber).rotationEffect(.degrees(-90))
                }
            case .complete:
                Circle().fill(Color.inkAmber)
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color.inkCream)
            }
        }
        .frame(width: 14, height: 14)
        .accessibilityLabel({
            switch state {
            case .notStarted: return "Not started"
            case .inProgress: return "In progress"
            case .complete:   return "Complete"
            }
        }())
    }
}
