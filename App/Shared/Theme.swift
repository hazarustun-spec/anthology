import AppKit
import SwiftUI

/// "Blocks" palette (spec §7.1). Light = airy sage, dark = deep green-gray. Every color adapts.
enum Palette {
    static let canvas = dynamic(dark: 0x1B1D1A, light: 0xF4F5F2)
    static let sidebar = dynamic(dark: 0x171916, light: 0xEDEFEA)
    static let list = dynamic(dark: 0x1B1D1A, light: 0xF4F5F2)
    static let card = dynamic(dark: 0x232622, light: 0xFFFFFF)
    static let block = dynamic(dark: 0x2A2E29, light: 0xF4F5F2)
    static let selection = dynamic(dark: 0x2F342E, light: 0xFFFFFF)
    static let hairline = dynamic(dark: 0x343933, light: 0xDFE2DA)
    static let text = dynamic(dark: 0xE9ECE5, light: 0x23261F)
    static let body = dynamic(dark: 0xD3D8CF, light: 0x30342C)
    static let secondary = dynamic(dark: 0x9BA395, light: 0x626A5C)
    static let tertiary = dynamic(dark: 0x6C7467, light: 0x9AA094)
    static let accent = dynamic(dark: 0x8FB08A, light: 0x5E7D5A)
    static let accentBorder = dynamic(dark: 0x5E7D5A, light: 0x9DB89A)
    static let accentWash = dynamic(dark: 0x2B3A29, light: 0xE8EFE6)
    static let accentText = dynamic(dark: 0xB9D3B4, light: 0x3F5A3C)
    static let chip = dynamic(dark: 0x2B3A29, light: 0xE8EFE6)
    static let codeBG = dynamic(dark: 0x2A2E29, light: 0xEEF0EB)

    static func dynamic(dark: UInt32, light: UInt32) -> NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(hex: dark) : NSColor(hex: light)
        }
    }

    static func sans(_ size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        NSFont.systemFont(ofSize: size, weight: weight)
    }
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension Color {
    init(palette: NSColor) { self.init(nsColor: palette) }
}

enum AppearanceChoice: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var colorScheme: ColorScheme? {
        switch self {
        case .dark: .dark
        case .light: .light
        case .system: nil
        }
    }
    var label: LocalizedStringKey {
        switch self {
        case .system: "Match system"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}
