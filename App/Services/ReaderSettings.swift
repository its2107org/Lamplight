import SwiftUI

/// Colour schemes for the page. All warm and dark: nothing bright or blue before sleep.
enum PageTheme: String, CaseIterable, Identifiable {
    case ember, candle, moonless

    var id: String { rawValue }

    var name: String {
        switch self {
        case .ember: return "Ember"
        case .candle: return "Candle"
        case .moonless: return "Moonless"
        }
    }

    /// Background, text, secondary text, accent (CSS colours).
    var css: (bg: String, ink: String, muted: String, accent: String) {
        switch self {
        case .ember: return ("#0E0A07", "#E2C49C", "#9C8467", "#E0904A")
        case .candle: return ("#1C150F", "#EBDDC6", "#A8957C", "#D9A066")
        case .moonless: return ("#000000", "#A39686", "#6E6457", "#B07A45")
        }
    }

    var background: Color { Color(hex: css.bg) }
    var ink: Color { Color(hex: css.ink) }
    var muted: Color { Color(hex: css.muted) }
    var accent: Color { Color(hex: css.accent) }
}

enum PageFont: String, CaseIterable, Identifiable {
    case newYork, charter, iowan, sans

    var id: String { rawValue }

    var name: String {
        switch self {
        case .newYork: return "New York"
        case .charter: return "Charter"
        case .iowan: return "Iowan"
        case .sans: return "San Francisco"
        }
    }

    var css: String {
        switch self {
        case .newYork: return "ui-serif, 'New York', Georgia, serif"
        case .charter: return "Charter, 'Iowan Old Style', Georgia, serif"
        case .iowan: return "'Iowan Old Style', Charter, Georgia, serif"
        case .sans: return "-apple-system, system-ui, sans-serif"
        }
    }

    var preview: Font {
        switch self {
        case .newYork: return .system(size: 17, design: .serif)
        case .charter: return .custom("Charter", size: 17)
        case .iowan: return .custom("Iowan Old Style", size: 17)
        case .sans: return .system(size: 17)
        }
    }
}

/// The reader's look, remembered between nights.
final class ReaderSettings: ObservableObject {
    static let shared = ReaderSettings()

    @AppStorage("pageTheme") var theme: PageTheme = .ember { willSet { objectWillChange.send() } }
    @AppStorage("pageFont") var font: PageFont = .newYork { willSet { objectWillChange.send() } }
    @AppStorage("textSize") var textSize: Double = 21 { willSet { objectWillChange.send() } }
    /// Extra dimming on top of the screen's own brightness (0 = none).
    @AppStorage("dimmer") var dimmer: Double = 0.15 { willSet { objectWillChange.send() } }
    @AppStorage("keepAwake") var keepAwake = false { willSet { objectWillChange.send() } }
    @AppStorage("reminderOn") var reminderOn = false { willSet { objectWillChange.send() } }
    /// Minutes after midnight for the wind-down reminder (default 9.30pm).
    @AppStorage("reminderMinutes") var reminderMinutes = 21 * 60 + 30 { willSet { objectWillChange.send() } }

    static let sizes: ClosedRange<Double> = 16...32

    var reminderTime: Date {
        get { Calendar.current.date(bySettingHour: reminderMinutes / 60, minute: reminderMinutes % 60, second: 0, of: Date()) ?? Date() }
        set {
            let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            reminderMinutes = (parts.hour ?? 21) * 60 + (parts.minute ?? 30)
        }
    }
}

extension Color {
    init(hex: String) {
        let value = UInt64(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0
        self.init(red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255, blue: Double(value & 0xFF) / 255)
    }
}
