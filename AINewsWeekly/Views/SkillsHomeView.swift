import SwiftUI

struct SkillsHomeView: View {
    @Environment(SavedSkillsStore.self) private var savedStore
    @State private var showSavedOnly = false

    private var displayedSkills: [Skill] {
        showSavedOnly
            ? Skill.curated.filter { savedStore.isSaved($0) }
            : Skill.curated
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    hero
                    if showSavedOnly && displayedSkills.isEmpty {
                        emptyState
                    } else {
                        skillsList
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(Color.inkCream.ignoresSafeArea())
            .navigationTitle("Skills")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        withAnimation { showSavedOnly.toggle() }
                    } label: {
                        Image(systemName: showSavedOnly ? "bookmark.fill" : "bookmark")
                            .foregroundStyle(Color.inkAmber)
                    }
                }
            }
            .navigationDestination(for: Skill.self) { skill in
                SkillDetailView(skill: skill)
            }
        }
        .tint(.inkAmber)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Claude Code Skills")
                .font(.system(size: 36, weight: .semibold, design: .serif))
                .foregroundStyle(Color.inkText)
            Text("Curated skill packs that upgrade your AI workflow.")
                .font(.callout)
                .foregroundStyle(Color.inkTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var skillsList: some View {
        VStack(spacing: 14) {
            ForEach(displayedSkills) { skill in
                NavigationLink(value: skill) {
                    SkillCard(skill: skill, isSaved: savedStore.isSaved(skill)) {
                        savedStore.toggle(skill)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bookmark")
                .font(.system(size: 48))
                .foregroundStyle(Color.inkAmber)
            Text("No saved skills yet")
                .font(.system(.title3, design: .serif).weight(.semibold))
                .foregroundStyle(Color.inkText)
            Text("Tap the bookmark icon on any skill to save it here.")
                .font(.callout)
                .foregroundStyle(Color.inkTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

private struct SkillCard: View {
    let skill: Skill
    let isSaved: Bool
    let onBookmark: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                CategoryBadge(category: skill.category)
                Spacer()
                Button {
                    let gen = UIImpactFeedbackGenerator(style: .light)
                    gen.impactOccurred()
                    onBookmark()
                } label: {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                        .foregroundStyle(Color.inkAmber)
                        .font(.subheadline)
                }
                .buttonStyle(.plain)

                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundStyle(Color.inkTextTertiary)
            }

            Text(skill.name)
                .font(.system(.title3, design: .serif).weight(.semibold))
                .foregroundStyle(Color.inkText)

            Text(skill.tagline)
                .font(.subheadline)
                .foregroundStyle(Color.inkTextSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                Image(systemName: "terminal")
                    .font(.caption2)
                    .foregroundStyle(Color.inkAmber)
                Text("\(skill.features.count) skills included")
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
                .stroke(isSaved ? Color.inkAmber : Color.inkAmberSoft, lineWidth: isSaved ? 1.5 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
