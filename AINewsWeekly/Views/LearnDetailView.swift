import SwiftUI
import MarkdownUI

// LearnDetailView — the per-Learn-item screen. Hero (tag + serif name +
// italic-serif subtitle) → What it does → Who it's for → Pros (✓) →
// Cons (×) → Set it up (markdown via MarkdownUI). Bookmark toggle in
// the nav bar (filled amber when active).
struct LearnDetailView: View {
    @Environment(BookmarksStore.self) private var bookmarksStore
    let item: LearnItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                hero
                section(title: "What it does", body: item.detail.whatItDoes)
                section(title: "Who it's for", body: item.detail.whoItsFor)
                prosSection
                consSection
                setupSection
                viewSourceLink
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
        .background(Color.inkCream.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    bookmarksStore.toggle(item)
                } label: {
                    Image(systemName: bookmarksStore.isBookmarked(item.id) ? "bookmark.fill" : "bookmark")
                        .foregroundStyle(Color.inkAmber)
                }
                .accessibilityLabel(bookmarksStore.isBookmarked(item.id) ? "Remove bookmark" : "Add bookmark")
            }
        }
    }

    // MARK: - Sections

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            CategoryTag(category: item.category)
            Text(item.name)
                .font(.system(size: 34, weight: .semibold, design: .serif))
                .foregroundStyle(Color.inkText)
                .fixedSize(horizontal: false, vertical: true)
            Text(item.oneLineDescription)
                .font(.system(.title3, design: .serif).italic())
                .foregroundStyle(Color.inkTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if let mins = item.estimatedSetupMinutes {
                Label("\(mins) min setup", systemImage: "clock")
                    .font(.subheadline)
                    .foregroundStyle(Color.inkTextTertiary)
                    .padding(.top, 2)
            }
        }
    }

    private func section(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(.title3, design: .serif).weight(.semibold))
                .foregroundStyle(Color.inkText)
            Text(body)
                .font(.body)
                .foregroundStyle(Color.inkText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var prosSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pros")
                .font(.system(.title3, design: .serif).weight(.semibold))
                .foregroundStyle(Color.inkText)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(item.detail.pros, id: \.self) { pro in
                    bulletRow(symbol: "checkmark.circle.fill", color: Color(red: 0.373, green: 0.612, blue: 0.478), text: pro)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var consSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cons")
                .font(.system(.title3, design: .serif).weight(.semibold))
                .foregroundStyle(Color.inkText)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(item.detail.cons, id: \.self) { con in
                    bulletRow(symbol: "xmark.circle.fill", color: Color(red: 0.722, green: 0.373, blue: 0.373), text: con)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func bulletRow(symbol: String, color: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .padding(.top, 3)
            Text(text)
                .font(.callout)
                .foregroundStyle(Color.inkText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var setupSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Set it up")
                .font(.system(.title3, design: .serif).weight(.semibold))
                .foregroundStyle(Color.inkText)
            Markdown(item.detail.setupGuideMarkdown)
                .markdownTheme(.inkEditorial)
                .markdownCodeSyntaxHighlighter(.plainText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var viewSourceLink: some View {
        Link(destination: item.detail.sourceURL) {
            HStack(spacing: 6) {
                Text("View source")
                Image(systemName: "arrow.up.right.square")
            }
            .font(.callout.weight(.medium))
            .foregroundStyle(Color.inkAmber)
            .underline()
        }
        .padding(.top, 8)
    }
}
