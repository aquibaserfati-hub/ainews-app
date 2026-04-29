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
            ForEach(track.lessons) { lesson in
                NavigationLink(value: lesson) {
                    LessonRow(lesson: lesson)
                }
                .buttonStyle(.plain)
            }
        }
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

private struct LessonRow: View {
    let lesson: Lesson

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
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
                .stroke(Color.inkAmberSoft, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
