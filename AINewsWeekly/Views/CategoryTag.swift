import SwiftUI

// CategoryTag — small pill used in the hero card and Learn detail header.
// Cream-friendly: amber-soft background with the category color text + dot.
struct CategoryTag: View {
    let category: Category

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(category.tagColor)
                .frame(width: 7, height: 7)
            Text(category.displayName.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(category.tagColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(category.tagColor.opacity(0.10))
        .clipShape(Capsule())
    }
}

// CategoryDot — minimal version for the dense TL;DR list.
struct CategoryDot: View {
    let category: Category

    var body: some View {
        Circle()
            .fill(category.tagColor)
            .frame(width: 8, height: 8)
            .accessibilityLabel(category.displayName)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        CategoryTag(category: .anthropic)
        CategoryTag(category: .openai)
        CategoryTag(category: .tooling)
        CategoryDot(category: .founderLens)
    }
    .padding()
    .background(Color.inkCream)
}
