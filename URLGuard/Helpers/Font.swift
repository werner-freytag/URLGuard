import SwiftUI

extension String {
    /// Berechnet die Breite des Strings für einen gegebenen SwiftUI Font
    func width(using font: Font) -> CGFloat {
        // Font → CTFont konvertieren
        #if os(iOS) || os(tvOS) || os(watchOS)
        let uiFont = UIFont.preferredFont(from: font)
        #elseif os(macOS)
        let uiFont = NSFont.preferredFont(from: font)
        #endif
        
        return (self as NSString).size(withAttributes: [.font: uiFont]).width
    }
}


#if os(iOS) || os(tvOS) || os(watchOS)
import UIKit

extension UIFont {
    static func preferredFont(from font: Font) -> UIFont {
        // Mapping der Standard-Fonts (vereinfachte Variante)
        switch font {
        case .largeTitle: return .preferredFont(forTextStyle: .largeTitle)
        case .title:      return .preferredFont(forTextStyle: .title1)
        case .title2:     return .preferredFont(forTextStyle: .title2)
        case .title3:     return .preferredFont(forTextStyle: .title3)
        case .headline:   return .preferredFont(forTextStyle: .headline)
        case .subheadline:return .preferredFont(forTextStyle: .subheadline)
        case .body:       return .preferredFont(forTextStyle: .body)
        case .callout:    return .preferredFont(forTextStyle: .callout)
        case .footnote:   return .preferredFont(forTextStyle: .footnote)
        case .caption:    return .preferredFont(forTextStyle: .caption1)
        case .caption2:   return .preferredFont(forTextStyle: .caption2)
        default:          return .systemFont(ofSize: UIFont.systemFontSize)
        }
    }
}
#endif

#if os(macOS)
import AppKit

extension NSFont {
    static func preferredFont(from font: Font) -> NSFont {
        switch font {
        case .largeTitle: return .preferredFont(forTextStyle: .largeTitle, options: [:])
        case .title:      return .preferredFont(forTextStyle: .title1, options: [:])
        case .title2:     return .preferredFont(forTextStyle: .title2, options: [:])
        case .title3:     return .preferredFont(forTextStyle: .title3, options: [:])
        case .headline:   return .preferredFont(forTextStyle: .headline, options: [:])
        case .subheadline:return .preferredFont(forTextStyle: .subheadline, options: [:])
        case .body:       return .preferredFont(forTextStyle: .body, options: [:])
        case .callout:    return .preferredFont(forTextStyle: .callout, options: [:])
        case .footnote:   return .preferredFont(forTextStyle: .footnote, options: [:])
        case .caption:    return .preferredFont(forTextStyle: .caption1, options: [:])
        case .caption2:   return .preferredFont(forTextStyle: .caption2, options: [:])
        default:          return .systemFont(ofSize: NSFont.systemFontSize)
        }
    }
}
#endif
