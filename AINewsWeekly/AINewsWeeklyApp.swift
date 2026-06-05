import SwiftUI

@main
struct AINewsWeeklyApp: App {
    private func resetIfNeeded() {
        guard CommandLine.arguments.contains("--reset-for-screenshots") else { return }
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: "hasSeenOnboarding")
        defaults.removeObject(forKey: "ainews.lesson-progress.v1")
        defaults.removeObject(forKey: "savedSkillIds")
    }
    @State private var digestService = DigestService()
    @State private var curriculumService = CurriculumService()
    @State private var bookmarksStore = BookmarksStore()
    @State private var lessonProgressStore = LessonProgressStore()
    @State private var savedSkillsStore = SavedSkillsStore()
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some Scene {
        WindowGroup {
            let _ = resetIfNeeded()
            RootTabView()
                .environment(digestService)
                .environment(curriculumService)
                .environment(bookmarksStore)
                .environment(lessonProgressStore)
                .environment(savedSkillsStore)
                .tint(.inkAmber)
                .background(Color.inkCream)
                .fullScreenCover(isPresented: Binding(
                    get: { !hasSeenOnboarding },
                    set: { hasSeenOnboarding = !$0 }
                )) {
                    OnboardingView(hasSeenOnboarding: $hasSeenOnboarding)
                }
        }
    }
}

private struct RootTabView: View {
    @State private var selectedTab = 1

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Digest", systemImage: "newspaper")
                }
                .tag(0)

            LearnHomeView()
                .tabItem {
                    Label("Learn", systemImage: "book.closed")
                }
                .tag(1)

            SkillsHomeView()
                .tabItem {
                    Label("Skills", systemImage: "terminal")
                }
                .tag(2)
        }
        .tint(.inkAmber)
    }
}
