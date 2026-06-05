import SwiftUI

struct SkillsHomeView: View {
    private let skills = Skill.curated

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    hero
                    skillsList
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(Color.inkCream.ignoresSafeArea())
            .navigationTitle("Skills")
            .navigationBarTitleDisplayMode(.inline)
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
            ForEach(skills) { skill in
                NavigationLink(value: skill) {
                    SkillCard(skill: skill)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct SkillCard: View {
    let skill: Skill

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                CategoryBadge(category: skill.category)
                Spacer()
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
                .stroke(Color.inkAmberSoft, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
