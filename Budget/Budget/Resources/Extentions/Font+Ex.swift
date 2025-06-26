
import Foundation

import SwiftUI

extension Font {
    static func playfairDisplay(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let fontName: String

        switch weight {
        case .bold:
            fontName = "PlayfairDisplay-Bold"
        case .semibold:
            fontName = "PlayfairDisplay-SemiBold"
        default:
            fontName = "PlayfairDisplay-Regular"
        }

        return .custom(fontName, size: size)
    }
}
