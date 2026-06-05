import SwiftUI

struct OnboardingView: View {
    @Binding var hasSeenOnboarding: Bool
    @State private var page = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "book.closed.fill",
            title: "Learn AI Tools\nStep by Step",
            body: "6 hands-on lessons across Beginner, Intermediate, and Advanced tracks — from Claude Code to Cloudflare Workers."
        ),
        OnboardingPage(
            icon: "checkmark.circle.fill",
            title: "Track Every Step",
            body: "Mark steps done as you go. Your progress is saved on-device and survives app restarts — pick up exactly where you left off."
        ),
        OnboardingPage(
            icon: "brain.head.profile",
            title: "Ask the Tutor",
            body: "Stuck on a step? The built-in AI tutor knows which lesson and step you're on. Context-aware help without copy-pasting."
        ),
        OnboardingPage(
            icon: "bell.badge.fill",
            title: "Stay in the Loop",
            body: "Get notified when new lessons drop. One notification per week, no spam."
        ),
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.inkCream.ignoresSafeArea()

            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, p in
                    pageView(p)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack(spacing: 20) {
                pageIndicator
                actionButton
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 52)
        }
    }

    private func pageView(_ p: OnboardingPage) -> some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: p.icon)
                .font(.system(size: 72))
                .foregroundStyle(Color.inkAmber)
            Text(p.title)
                .font(.system(size: 30, weight: .semibold, design: .serif))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.inkText)
            Text(p.body)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.inkTextSecondary)
                .padding(.horizontal, 24)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<pages.count, id: \.self) { i in
                Capsule()
                    .fill(i == page ? Color.inkAmber : Color.inkAmberSoft)
                    .frame(width: i == page ? 24 : 8, height: 8)
                    .animation(.spring(response: 0.3), value: page)
            }
        }
    }

    private var actionButton: some View {
        Button {
            if page < pages.count - 1 {
                withAnimation { page += 1 }
            } else {
                Task { await NotificationService.requestPermission() }
                hasSeenOnboarding = true
            }
        } label: {
            Text(page < pages.count - 1 ? "Next" : "Get Started")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.inkAmber)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

private struct OnboardingPage {
    let icon: String
    let title: String
    let body: String
}
