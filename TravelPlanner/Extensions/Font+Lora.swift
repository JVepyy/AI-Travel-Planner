import SwiftUI

extension Font {
    static func lora(size: CGFloat, weight: Font.Weight = .regular, italic: Bool = false) -> Font {
        let fontName: String
        
        if italic {
            fontName = "Lora-Italic"
        } else {
            fontName = "Lora-Regular"
        }
        return .custom(fontName, size: size)
    }
}

