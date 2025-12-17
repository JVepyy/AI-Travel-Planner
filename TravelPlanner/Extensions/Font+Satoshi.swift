import SwiftUI

extension Font {
    static func satoshi(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let fontName: String
        switch weight {
        case .regular:
            fontName = "Satoshi-Regular"
        case .medium:
            fontName = "Satoshi-Medium"
        case .semibold:
            fontName = "Satoshi-Bold"
        case .bold:
            fontName = "Satoshi-Bold"
        default:
            fontName = "Satoshi-Regular"
        }
        return .custom(fontName, size: size)
    }
}


