import SwiftUI

// CodeBlockView — renders a code block with a tap-to-copy button.
// Used by MarkdownTheme.inkEditorial's codeBlock customization to ensure
// every fenced code block in lesson markdown has a Copy affordance.
//
// Eng review fix #3: lessons heavily use `runCommand` step types; without
// tap-to-copy, users have to long-press-and-select shell commands on a
// phone, which is too much friction.
struct CodeBlockView: View {
    let code: String
    let language: String?

    @State private var copied = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(Color.inkText)
                    .padding(14)
                    .padding(.trailing, 50) // leave room for copy button
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.inkCodeBg)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.inkAmberSoft, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            copyButton
                .padding(8)
        }
    }

    private var copyButton: some View {
        Button {
            UIPasteboard.general.string = code
            copied = true
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            Task {
                try? await Task.sleep(for: .milliseconds(1200))
                await MainActor.run { copied = false }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.caption)
                Text(copied ? "Copied" : "Copy")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(Color.inkAmber)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.inkCard)
                    .overlay(Capsule().stroke(Color.inkAmber.opacity(0.4), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(copied ? "Copied" : "Copy code")
    }
}
