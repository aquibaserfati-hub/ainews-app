import SwiftUI

@main
struct AINewsWeeklyApp: App {
    @State private var digestService = DigestService()
    @State private var curriculumService = CurriculumService()
    @State private var bookmarksStore = BookmarksStore()
    @State private var lessonProgressStore = LessonProgressStore()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(digestService)
                .environment(curriculumService)
                .environment(bookmarksStore)
                .environment(lessonProgressStore)
                .preferredColorScheme(.light)  // light-mode only; dark in v1.5
                .tint(.inkAmber)
                .background(Color.inkCream)
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
        }
        .tint(.inkAmber)
    }
}
