import SwiftUI

/// Warm, low-light colours: no bright whites and no blue, so nothing jolts you awake.
enum Palette {
    static let background = Color(red: 0.055, green: 0.039, blue: 0.027)   // #0E0A07
    static let surface = Color(red: 0.098, green: 0.071, blue: 0.051)      // #19120D
    static let raised = Color(red: 0.137, green: 0.098, blue: 0.071)       // #231912
    static let line = Color(red: 0.204, green: 0.153, blue: 0.110)         // #34271C
    static let ink = Color(red: 0.910, green: 0.788, blue: 0.627)          // #E8C9A0
    static let muted = Color(red: 0.612, green: 0.518, blue: 0.404)        // #9C8467
    static let faint = Color(red: 0.400, green: 0.333, blue: 0.259)        // #665542
    static let ember = Color(red: 0.878, green: 0.565, blue: 0.290)        // #E0904A
    static let glow = Color(red: 0.965, green: 0.733, blue: 0.408)         // #F6BB68
    static let done = Color(red: 0.639, green: 0.659, blue: 0.443)         // #A3A871, a soft olive

    static let serif = Font.Design.serif
}

extension Font {
    static func lamp(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func label(_ size: CGFloat = 11) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }
}
