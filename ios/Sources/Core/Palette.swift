import SwiftUI

// MARK: - 颜色

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }

    /// "#660000" 或 "660000"
    init?(hexString: String) {
        var s = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(hex: v)
    }
}

/// 唯一配色来源：黑白灰极简，不引入任何系统默认强调色。
struct Palette {
    let dark: Bool

    var background: Color { Color(hex: dark ? 0x08080A : 0xFFFFFF) }
    var surface: Color { Color(hex: dark ? 0x0E0E11 : 0xFFFFFF) }
    var surfaceAlt: Color { Color(hex: dark ? 0x17171C : 0xF3F3F6) }
    var textPrimary: Color { Color(hex: dark ? 0xF6F6F8 : 0x0A0A0E) }
    var textSecondary: Color { Color(hex: dark ? 0x9B9BA5 : 0x6B6B77) }
    var textTertiary: Color { Color(hex: dark ? 0x6A6A75 : 0x9C9CA8) }
    var line: Color { Color(hex: dark ? 0x23232A : 0xEBEBF0) }
    var ink: Color { Color(hex: dark ? 0xF6F6F8 : 0x0A0A0E) }
    var onInk: Color { Color(hex: dark ? 0x08080A : 0xFFFFFF) }
    var like: Color { Color(hex: dark ? 0xFF4D6A : 0xFF3B5C) }
    var downloaded: Color { Color(hex: 0x6FC24A) }
    var scrim: Color { Color.black.opacity(dark ? 0.6 : 0.4) }
    /// 卡片角标永远白底黑字，不跟随主题。
    var badgeBackground: Color { Color.white.opacity(0.94) }
    var badgeText: Color { Color(hex: 0x17171A) }
}

// MARK: - 尺寸

enum M {
    static let gridSpacing: CGFloat = 5
    static let gridInset: CGFloat = 2
    static let cardRadius: CGFloat = 3
    static let screenInset: CGFloat = 20
    static let sectionSpacing: CGFloat = 22
    static let chipSpacing: CGFloat = 8
    static let navBarWidth: CGFloat = 158
}

// MARK: - 字号（Android sp 直接当 pt 用，不放大小）

enum F {
    static func display() -> Font { .system(size: 32, weight: .bold) }
    static func pageTitle() -> Font { .system(size: 22, weight: .bold) }
    static func sheetTitle() -> Font { .system(size: 20, weight: .semibold) }
    static func titleMedium() -> Font { .system(size: 15, weight: .semibold) }
    static func titleSmall() -> Font { .system(size: 13, weight: .medium) }
    static func body() -> Font { .system(size: 14) }
    static func bodySmall() -> Font { .system(size: 12) }
    static func pill() -> Font { .system(size: 14, weight: .semibold) }
    static func pillCompact() -> Font { .system(size: 13, weight: .semibold) }
    static func label() -> Font { .system(size: 12, weight: .medium) }
    static func labelSmall() -> Font { .system(size: 11, weight: .medium) }
    static func tab() -> Font { .system(size: 10, weight: .medium) }
    static func badge() -> Font { .system(size: 9, weight: .semibold) }
}
