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

// RootTabView — v2 tab bar. Two tabs: Digest (the v1 HomeView, unchanged)
// and Learn (the new curriculum surface). Selection defaults to Digest on
// cold launch — that's the entry-point experience users land on.
private struct RootTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Digest", systemImage: "newspaper")
                }

            LearnHomeView()
                .tabItem {
                    Label("Learn", systemImage: "book.closed")
                }
        }
        .tint(.inkAmber)
    }
}
