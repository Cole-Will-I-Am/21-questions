import SwiftUI

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xff) / 255,
                  green: Double((hex >> 8) & 0xff) / 255,
                  blue: Double(hex & 0xff) / 255,
                  opacity: alpha)
    }
}

// Dark, calm, near-monochrome so text and the player's answers are the focus. One accent
// (electric indigo), used only for Echo's voice and the reveal. Serif for Echo, sans for UI.
enum Palette {
    static let bg       = Color(hex: 0x0B0B10)   // near-black canvas
    static let bgRaised = Color(hex: 0x16161F)   // cards / chips
    static let bgRaised2 = Color(hex: 0x1F1F2B)
    static let ink      = Color(hex: 0xF2F1F6)   // primary text
    static let inkSoft  = Color(hex: 0x9C9AAB)   // secondary text
    static let inkFaint = Color(hex: 0x55545F)
    static let indigo   = Color(hex: 0x7C6BFF)   // electric indigo — Echo's voice + reveal
    static let indigoDeep = Color(hex: 0x4B3FB5)
    static let line     = Color(hex: 0x282833)
    static let bgGradient = LinearGradient(
        colors: [Color(hex: 0x111119), Color(hex: 0x0B0B10)], startPoint: .top, endPoint: .bottom)
}

enum EType {
    static func serif(_ size: CGFloat, _ w: Font.Weight = .regular) -> Font { .system(size: size, weight: w, design: .serif) }
    static let echo     = serif(20)                       // Echo's spoken lines
    static let question = serif(27, .semibold)            // the question
    static let title    = serif(34, .bold)
    static let reveal   = serif(22, .semibold)
    static let body     = Font.system(size: 17)           // sans UI
    static let label    = Font.system(size: 12, weight: .semibold, design: .rounded)
    static let small    = Font.system(size: 14)
    static let mono     = Font.system(size: 12, weight: .medium, design: .monospaced)
}

enum Metrics {
    static let s1: CGFloat = 4, s2: CGFloat = 8, s3: CGFloat = 12, s4: CGFloat = 16
    static let s6: CGFloat = 24, s8: CGFloat = 32, s10: CGFloat = 44
    static let radius: CGFloat = 16
}

import UIKit
enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func soft() { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    static func heavy() { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
    static func seal() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
}
