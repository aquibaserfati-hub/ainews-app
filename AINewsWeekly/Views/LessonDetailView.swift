import SwiftUI
import MarkdownUI

// LessonDetailView — pushed from a LessonRow. Lists the steps vertically,
// each rendered as: icon (per stepType) + step number + title + markdown
// body + optional validation hint.
//
// Weekend 2 ships READ-ONLY:
//   - No [Done] checkboxes (those land in Weekend 3 with LessonProgressStore)
//   - No "Ask the tutor" floating button (Weekend 5 with TutorService)
//   - No tap-to-copy on code blocks (Weekend 5 with CodeBlockView wrapper)
//
//      ┌───────────────────────────────────────────┐
//      │ ‹ Back                                    │
//      ├───────────────────────────────────────────┤
//      │  Setting up Claude Code                   │   hero
//      │  Install Anthropic's terminal coding…     │
//      │  ⏱ 15 min                                  │
//      │                                           │
//      │  ◉  Step 1 — Check that you have Node 18+ │
//      │     ───── markdown body ─────             │
//      │     ✔ node --version prints v18 or higher │
//      │                                           │
//      │  ▶  Step 2 — ...                          │
//      └───────────────────────────────────────────┘
struct LessonDetailView: View {
    let lesson: Lesson

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                hero
                if let url = lesson.youtubeURL {
                    youtubeLink(url: url)
                }
                stepsList
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(Color.inkCream.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(lesson.title)
                .font(.system(size: 32, weight: .semibold, design: .serif))
                .foregroundStyle(Color.inkText)
            Text(lesson.oneLineDescription)
                .font(.callout)
                .foregroundStyle(Color.inkTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 12) {
                Label("\(lesson.estimatedMinutes) min", systemImage: "clock")
                    .labelStyle(.titleAndIcon)
                    .font(.caption)
                    .foregroundStyle(Color.inkTextTertiary)
                CategoryTag(category: lesson.category)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func youtubeLink(url: URL) -> some View {
        Link(destination: url) {
            HStack(spacing: 10) {
                Image(systemName: "play.rectangle")
                    .font(.title3)
                Text("Watch the video")
                    .font(.system(.headline, design: .serif))
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .font(.caption)
            }
            .foregroundStyle(Color.inkAmber)
            .padding(14)
            .background(Color.inkAmberSoft)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private var stepsList: some View {
        VStack(alignment: .leading, spacing: 22) {
            ForEach(Array(lesson.steps.enumerated()), id: \.element.id) { index, step in
                StepCard(stepNumber: index + 1, step: step)
            }
        }
    }
}

private struct StepCard: View {
    let stepNumber: Int
    let step: LessonStep

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: step.stepType.sfSymbol)
                    .foregroundStyle(Color.inkAmber)
                    .frame(width: 18)
                Text("Step \(stepNumber)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.inkTextTertiary)
                    .textCase(.uppercase)
                Text("·")
                    .foregroundStyle(Color.inkTextTertiary)
                Text(step.title)
                    .font(.system(.headline, design: .serif))
                    .foregroundStyle(Color.inkText)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }

            Markdown(step.body)
                .markdownTheme(.inkEditorial)

            if let hint = step.validationHint {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(Color.inkAmber)
                    Text(hint)
                        .font(.footnote)
                        .foregroundStyle(Color.inkTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.inkAmberSoft)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
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

private extension StepType {
    var sfSymbol: String {
        switch self {
        case .read:        return "book"
        case .runCommand:  return "terminal"
        case .verify:      return "checkmark.shield"
        }
    }
}
