import SwiftUI

@main
struct AINewsWeeklyApp: App {
    @State private var digestService = DigestService()
    @State private var bookmarksStore = BookmarksStore()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(digestService)
                .environment(bookmarksStore)
                .preferredColorScheme(.light)  // v1 ships light-mode only; dark in v1.5
                .tint(.inkAmber)
                .background(Color.inkCream)
        }
    }
}
