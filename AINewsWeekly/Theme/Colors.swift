import SwiftUI

// Design system colors — locked via /design-shotgun on 2026-04-27.
// Direction: modern dashboard structure on a warm editorial palette.
// Light mode primary, dark mode is a v1.5 follow-up.
extension Color {
    // Primary surfaces.
    static let inkCream = Color(red: 0.973, green: 0.957, blue: 0.925)            // #F8F4EC paper background
    static let inkCard = Color(red: 0.984, green: 0.969, blue: 0.937)             // #FBF7EF lifted card

    // Text.
    static let inkText = Color(red: 0.122, green: 0.094, blue: 0.075)             // #1F1813 primary
    static let inkTextSecondary = Color(red: 0.353, green: 0.290, blue: 0.247)    // warm medium gray
    static let inkTextTertiary = Color(red: 0.557, green: 0.490, blue: 0.435)     // warm caption

    // Accent (deep amber).
    static let inkAmber = Color(red: 0.612, green: 0.373, blue: 0.102)            // #9C5F1A
    static let inkAmberSoft = Color(red: 0.612, green: 0.373, blue: 0.102).opacity(0.10)  // tag fill, hairline

    // Code block surface.
    static let inkCodeBg = Color(red: 0.941, green: 0.914, blue: 0.847)           // #F0E9D8
}
