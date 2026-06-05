import SwiftUI
import UIKit

extension Color {
    // Primary surfaces
    static let inkCream = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.098, green: 0.075, blue: 0.055, alpha: 1)
            : UIColor(red: 0.973, green: 0.957, blue: 0.925, alpha: 1)
    })
    static let inkCard = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.129, green: 0.102, blue: 0.082, alpha: 1)
            : UIColor(red: 0.984, green: 0.969, blue: 0.937, alpha: 1)
    })

    // Text
    static let inkText = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.941, green: 0.925, blue: 0.898, alpha: 1)
            : UIColor(red: 0.122, green: 0.094, blue: 0.075, alpha: 1)
    })
    static let inkTextSecondary = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.690, green: 0.639, blue: 0.596, alpha: 1)
            : UIColor(red: 0.353, green: 0.290, blue: 0.247, alpha: 1)
    })
    static let inkTextTertiary = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.490, green: 0.439, blue: 0.400, alpha: 1)
            : UIColor(red: 0.557, green: 0.490, blue: 0.435, alpha: 1)
    })

    // Accent (amber — same in both modes)
    static let inkAmber = Color(red: 0.612, green: 0.373, blue: 0.102)
    static let inkAmberSoft = Color(red: 0.612, green: 0.373, blue: 0.102).opacity(0.12)

    // Code block surface
    static let inkCodeBg = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.165, green: 0.133, blue: 0.102, alpha: 1)
            : UIColor(red: 0.941, green: 0.914, blue: 0.847, alpha: 1)
    })
}
