import SwiftUI

struct ProgressStatsView: View {
    @Environment(LessonProgressStore.self) private var progressStore
    @Environment(CurriculumService.self) private var curriculumService

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if case .loaded(let curriculum) = curriculumService.state {
                        summaryRow(curriculum: curriculum)
                        Divider().overlay(Color.inkAmberSoft)
                        trackBreakdown(curriculum: curriculum)
                    } else {
                        Text("Load the Learn tab first to see your stats.")
                            .font(.callout)
                            .foregroundStyle(Color.inkTextSecondary)
                            .padding(.top, 40)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(20)
            }
            .background(Color.inkCream.ignoresSafeArea())
            .navigationTitle("Your Progress")
            .navigationBarTitleDisplayMode(.inline)
        }
        .tint(.inkAmber)
    }

    private func summaryRow(curriculum: Curriculum) -> some View {
        let totalLessons = curriculum.tracks.flatMap(\.lessons).count
        let completedLessons = curriculum.tracks.flatMap(\.lessons).filter {
            progressStore.isLessonComplete($0.id)
        }.count
        let totalSteps = curriculum.tracks.flatMap(\.lessons).flatMap(\.steps).count
        // Count completed steps across all lessons
        let completedSteps = curriculum.tracks.flatMap(\.lessons).reduce(0) { sum, lesson in
            // LessonProgressStore doesn't expose step count directly so approximate from lessons
            sum + (progressStore.isLessonComplete(lesson.id) ? lesson.steps.count : 0)
        }

        return HStack(spacing: 0) {
            StatTile(value: "\(completedLessons)/\(totalLessons)", label: "Lessons")
            Divider().frame(height: 44).overlay(Color.inkAmberSoft)
            StatTile(value: "\(completedSteps)/\(totalSteps)", label: "Steps")
            Divider().frame(height: 44).overlay(Color.inkAmberSoft)
            let pct = totalLessons > 0 ? Int(Double(completedLessons) / Double(totalLessons) * 100) : 0
            StatTile(value: "\(pct)%", label: "Complete")
        }
        .padding(16)
        .background(Color.inkCard)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.inkAmberSoft, lineWidth: 1)
        )
    }

    private func trackBreakdown(curriculum: Curriculum) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("By Track")
                .font(.system(.headline, design: .serif))
                .foregroundStyle(Color.inkText)
            ForEach(curriculum.tracks.sorted { $0.order < $1.order }) { track in
                TrackProgressRow(track: track, progressStore: progressStore)
            }
        }
    }
}

private struct StatTile: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 28, weight: .semibold, design: .serif))
                .foregroundStyle(Color.inkAmber)
            Text(label)
                .font(.caption)
                .foregroundStyle(Color.inkTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct TrackProgressRow: View {
    let track: CurriculumTrack
    let progressStore: LessonProgressStore

    private var completed: Int { progressStore.completedCount(in: track) }
    private var total: Int { track.lessons.count }
    private var fraction: Double {
        total > 0 ? Double(completed) / Double(total) : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(track.title)
                    .font(.system(.subheadline, design: .serif).weight(.semibold))
                    .foregroundStyle(Color.inkText)
                Spacer()
                Text("\(completed) of \(total)")
                    .font(.caption)
                    .foregroundStyle(Color.inkTextSecondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.inkAmberSoft)
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.inkAmber)
                        .frame(width: geo.size.width * fraction, height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding(14)
        .background(Color.inkCard)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.inkAmberSoft, lineWidth: 1)
        )
    }
}
