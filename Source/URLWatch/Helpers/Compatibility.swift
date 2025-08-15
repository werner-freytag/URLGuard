import SwiftUICore

#if os(macOS)
#else
    import UIKit
#endif

extension Color {
    static var controlBackgroundColor: Color {
        #if os(macOS)
            Color(.controlBackgroundColor)
        #else
            Color(UIColor.systemGroupedBackground)
        #endif
    }
}
