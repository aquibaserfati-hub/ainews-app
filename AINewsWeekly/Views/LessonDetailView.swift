import SwiftUI
import MarkdownUI

// LessonDetailView — pushed from a LessonRow. Hero, optional video linkout,
// optional prerequisites banner, then a vertical list of steps each with a
// [Done] checkbox. On the final step toggling complete, a celebration toast
// surfaces with a "Next lesson" suggestion.
//
// Weekend 3 layer: progress tracking + soft prereq display.
// Still missing: Ask-the-tutor button (Weekend 5), code-block copy button (Weekend 5).
struct LessonDetailView: View {
    @Environment(LessonProgressStore.self) private var progressStore
    @Environment(CurriculumService.self) private var curriculumService

    let lesson: Lesson

    @State private var showCelebration = false
    @State private var showTutorSheet = false

    // The step the tutor opens against. Defaults to the first not-yet-done
    // step, falling back to step 1 of the lesson.
    private var tutorAnchorStep: (number: Int, step: LessonStep) {
        let progress = progressStore.progress(for: lesson.id)
        let doneIds = Set(progress?.completedStepIds ?? [])
        for (idx, step) in lesson.steps.enumerated() {
            if !doneIds.contains(step.id) {
                return (idx + 1, step)
            }
        }
        let last = lesson.steps.indices.last ?? 0
        return (last + 1, lesson.steps[last])
    }

    private var canShowTutorButton: Bool {
        // Hide the tutor entry point once the lesson is fully complete.
        !progressStore.isLessonComplete(lesson.id) && !lesson.steps.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                hero
                if let url = lesson.youtubeURL {
                    youtubeLink(url: url)
                }
                if let banner = unmetPrerequisitesBanner {
                    banner
                }
                stepsList
                if progressStore.isLessonComplete(lesson.id) {
                    completionFooter
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
            .padding(.bottom, 70) // leave room for the floating button
        }
        .background(Color.inkCream.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .top) {
            if showCelebration {
                CelebrationToast(lesson: lesson)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if canShowTutorButton {
                askTheTutorButton
                    .padding(.trailing, 16)
                    .padding(.bottom, 16)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: showCelebration)
        .sheet(isPresented: $showTutorSheet) {
            TutorChatView(
                lesson: lesson,
                currentStep: tutorAnchorStep.step,
                stepNumber: tutorAnchorStep.number
            )
            .environment(progressStore)
        }
    }

    // MARK: - Floating tutor button

    private var askTheTutorButton: some View {
        Button {
            showTutorSheet = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                Text("Ask the tutor")
                    .font(.system(.subheadline, design: .serif).weight(.semibold))
            }
            .foregroundStyle(Color.inkCream)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Color.inkAmber)
            .clipShape(Capsule())
            .shadow(color: Color.inkAmber.opacity(0.2), radius: 8, y: 2)
        }
        .accessibilityLabel("Ask the tutor")
    }

    // MARK: - Sections

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

            progressBar
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var progressBar: some View {
        let p = progressStore.stepProgress(for: lesson)
        let fraction = p.total > 0 ? Double(p.done) / Double(p.total) : 0
        return VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color.inkAmberSoft)
                    .frame(height: 6)
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.inkAmber)
                        .frame(width: geo.size.width * fraction, height: 6)
                }
                .frame(height: 6)
            }
            Text("\(p.done) of \(p.total) steps")
                .font(.caption2)
                .foregroundStyle(Color.inkTextTertiary)
        }
    }

    @ViewBuilder
    private var unmetPrerequisitesBanner: AnyView? {
        let unmet = unmetPrerequisites()
        guard !unmet.isEmpty else { return nil }
        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(Color.inkAmber)
                    Text("Recommended first")
                        .font(.system(.subheadline, design: .serif).weight(.semibold))
                        .foregroundStyle(Color.inkText)
                }
                ForEach(unmet, id: \.id) { prereq in
                    Text("• \(prereq.title)")
                        .font(.footnote)
                        .foregroundStyle(Color.inkTextSecondary)
                }
                Text("You can still tap through, but these lessons set up the tools this one assumes you have.")
                    .font(.caption)
                    .foregroundStyle(Color.inkTextTertiary)
                    .padding(.top, 2)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.inkAmberSoft)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        )
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
                StepCard(
                    stepNumber: index + 1,
                    step: step,
                    isDone: progressStore.isStepDone(lessonId: lesson.id, stepId: step.id),
                    onToggle: { handleStepToggle(step: step) }
                )
            }
        }
    }

    private var completionFooter: some View {
        VStack(spacing: 6) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title)
                .foregroundStyle(Color.inkAmber)
            Text("Lesson complete")
                .font(.system(.title3, design: .serif).weight(.semibold))
                .foregroundStyle(Color.inkText)
            if let next = nextLessonInTrack() {
                Text("Up next: \(next.title)")
                    .font(.footnote)
                    .foregroundStyle(Color.inkTextSecondary)
            } else {
                Text("You finished the track. New lessons land regularly.")
                    .font(.footnote)
                    .foregroundStyle(Color.inkTextSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }

    // MARK: - Actions

    private func handleStepToggle(step: LessonStep) {
        let wasComplete = progressStore.isLessonComplete(lesson.id)
        progressStore.toggleStep(lesson: lesson, stepId: step.id)
        let isNowComplete = progressStore.isLessonComplete(lesson.id)
        if !wasComplete && isNowComplete {
            // Just transitioned to complete — celebrate.
            showCelebration = true
            // Auto-dismiss after a moment.
            Task {
                try? await Task.sleep(for: .seconds(2.5))
                await MainActor.run { showCelebration = false }
            }
        }
    }

    // MARK: - Curriculum lookups

    private func unmetPrerequisites() -> [Lesson] {
        guard !lesson.prerequisites.isEmpty else { return [] }
        let needed = Set(lesson.prerequisites)
        let allLessons = currentTracks().flatMap(\.lessons)
        return allLessons
            .filter { needed.contains($0.id) && !progressStore.isLessonComplete($0.id) }
    }

    private func nextLessonInTrack() -> Lesson? {
        guard let track = currentTracks().first(where: { $0.id == lesson.trackId }) else { return nil }
        guard let myIndex = track.lessons.firstIndex(where: { $0.id == lesson.id }) else { return nil }
        let nextIndex = myIndex + 1
        return track.lessons.indices.contains(nextIndex) ? track.lessons[nextIndex] : nil
    }

    private func currentTracks() -> [CurriculumTrack] {
        if case .loaded(let curriculum) = curriculumService.state {
            return curriculum.tracks
        }
        return []
    }
}

// MARK: - StepCard

private struct StepCard: View {
    let stepNumber: Int
    let step: LessonStep
    let isDone: Bool
    let onToggle: () -> Void

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
                    .strikethrough(isDone, color: Color.inkTextTertiary)
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

            doneButton
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isDone ? Color.inkAmberSoft : Color.inkCard)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isDone ? Color.inkAmber : Color.inkAmberSoft, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var doneButton: some View {
        Button(action: onToggle) {
            HStack(spacing: 8) {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isDone ? Color.inkAmber : Color.inkTextTertiary)
                Text(isDone ? "Step done" : "Mark step done")
                    .font(.system(.subheadline, design: .serif).weight(.semibold))
                    .foregroundStyle(isDone ? Color.inkAmber : Color.inkText)
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isDone ? "Mark step \(stepNumber) not done" : "Mark step \(stepNumber) done")
    }
}

// MARK: - Celebration toast

private struct CelebrationToast: View {
    let lesson: Lesson

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "party.popper.fill")
                .foregroundStyle(Color.inkAmber)
            Text("Lesson complete: \(lesson.title)")
                .font(.system(.subheadline, design: .serif).weight(.semibold))
                .foregroundStyle(Color.inkText)
                .lineLimit(2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.inkCard)
                .shadow(color: Color.inkAmber.opacity(0.15), radius: 8, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.inkAmber, lineWidth: 1.5)
        )
        .padding(.horizontal, 16)
    }
}

// MARK: - StepType ↔ icon

private extension StepType {
    var sfSymbol: String {
        switch self {
        case .read:        return "book"
        case .runCommand:  return "terminal"
        case .verify:      return "checkmark.shield"
        }
    }
}
