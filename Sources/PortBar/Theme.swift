import SwiftUI

/// Visual language for PortBar: a dark "terminal-glass" panel.
enum Theme {
    // Backdrop
    static let bgTop      = Color(red: 0.075, green: 0.086, blue: 0.106) // #131618
    static let bgBottom   = Color(red: 0.043, green: 0.051, blue: 0.066) // #0B0D11
    static let glow       = Color(red: 0.96, green: 0.66, blue: 0.24)    // warm top glow

    // Surfaces
    static let card       = Color.white.opacity(0.040)
    static let cardHover  = Color.white.opacity(0.075)
    static let stroke     = Color.white.opacity(0.085)

    // Text
    static let textPrimary   = Color.white.opacity(0.94)
    static let textSecondary = Color.white.opacity(0.52)
    static let textTertiary  = Color.white.opacity(0.45)

    // Accents
    static let inUse   = Color(red: 0.96, green: 0.66, blue: 0.24)  // amber  #F5A93D
    static let free    = Color(red: 0.36, green: 0.89, blue: 0.65)  // mint   #5BE3A6
    static let danger  = Color(red: 1.00, green: 0.40, blue: 0.40)  // red    #FF6666
    static let link    = Color(red: 0.45, green: 0.72, blue: 1.00)  // blue   #73B8FF

    // Fonts — rounded display wordmark + monospaced data.
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
    static func rounded(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

/// A static status dot with a soft glow (no animation — cheap to render).
struct GlowDot: View {
    var color: Color
    var body: some View {
        ZStack {
            Circle().fill(color.opacity(0.18)).frame(width: 16, height: 16)
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .shadow(color: color.opacity(0.85), radius: 5)
        }
        .frame(width: 18, height: 18)
    }
}
