import SwiftUI

struct SkillDetailView: View {
    let skill: Skill
    @State private var copied = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                installSection
                featuresSection
                if skill.githubURL != nil || skill.docsURL != nil {
                    linksSection
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(Color.inkCream.ignoresSafeArea())
        .navigationTitle(skill.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                ShareLink(
                    item: "\(skill.name) — \(skill.tagline)\n\nInstall:\n\(skill.installCommand)",
                    subject: Text(skill.name),
                    message: Text(skill.tagline)
                ) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(Color.inkAmber)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                CategoryBadge(category: skill.category)
                Spacer()
            }
            Text(skill.name)
                .font(.system(size: 32, weight: .semibold, design: .serif))
                .foregroundStyle(Color.inkText)
            Text(skill.description)
                .font(.callout)
                .foregroundStyle(Color.inkTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var installSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Install")
                .font(.system(.headline, design: .serif))
                .foregroundStyle(Color.inkText)

            ZStack(alignment: .topTrailing) {
                Text(skill.installCommand)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(Color.inkText)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.inkCodeBg)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Button {
                    UIPasteboard.general.string = skill.installCommand
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    copied = true
                    Task {
                        try? await Task.sleep(for: .seconds(1.5))
                        copied = false
                    }
                } label: {
                    Text(copied ? "Copied" : "Copy")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.inkAmber)
                        .clipShape(Capsule())
                }
                .padding(8)
            }
        }
    }

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What's included")
                .font(.system(.headline, design: .serif))
                .foregroundStyle(Color.inkText)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(skill.features, id: \.self) { feature in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.inkAmber)
                            .font(.subheadline)
                            .padding(.top, 1)
                        Text(feature)
                            .font(.subheadline)
                            .foregroundStyle(Color.inkTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(16)
            .background(Color.inkCard)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.inkAmberSoft, lineWidth: 1)
            )
        }
    }

    private var linksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Links")
                .font(.system(.headline, design: .serif))
                .foregroundStyle(Color.inkText)

            VStack(spacing: 8) {
                if let url = skill.githubURL {
                    Link(destination: url) {
                        HStack {
                            Image(systemName: "chevron.left.forwardslash.chevron.right")
                                .foregroundStyle(Color.inkAmber)
                            Text("View on GitHub")
                                .font(.subheadline)
                                .foregroundStyle(Color.inkText)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(Color.inkTextTertiary)
                        }
                        .padding(14)
                        .background(Color.inkCard)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.inkAmberSoft, lineWidth: 1))
                    }
                }
                if let url = skill.docsURL {
                    Link(destination: url) {
                        HStack {
                            Image(systemName: "book")
                                .foregroundStyle(Color.inkAmber)
                            Text("Documentation")
                                .font(.subheadline)
                                .foregroundStyle(Color.inkText)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(Color.inkTextTertiary)
                        }
                        .padding(14)
                        .background(Color.inkCard)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.inkAmberSoft, lineWidth: 1))
                    }
                }
            }
        }
    }
}

struct CategoryBadge: View {
    let category: SkillCategory

    var body: some View {
        Text(category.rawValue)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.inkAmber)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.inkAmberSoft)
            .clipShape(Capsule())
    }
}
