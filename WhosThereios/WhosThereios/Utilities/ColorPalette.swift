//
//  ColorPalette.swift
//  WhosThereios
//
//  Created by Claude on 1/20/26.
//

import SwiftUI

extension Color {
    // Blue-based color palette
    // Primary blue, deep navy, soft off-white, warm amber, bold coral CTA

    static let appBlue = Color(hex: "3A7BD5")             // Primary blue
    static let appNavy = Color(hex: "1B2A4A")             // Deep navy
    static let appLightBlue = Color(hex: "E8F1FB")        // Soft blue-white background
    static let appAmber = Color(hex: "F5A623")             // Warm amber accent
    static let appCoral = Color(hex: "FF6B4A")             // Bold coral for CTAs

    // Legacy aliases — keeps existing references compiling
    static let appOliveGreen = appBlue
    static let appDarkGreen = appNavy
    static let appCream = appLightBlue
    static let appTan = appAmber
    static let appBrown = appCoral

    // Semantic color names for easier use
    static let appPrimary = appBlue
    static let appSecondary = appAmber
    static let appAccent = appCoral
    static let appBackground = appLightBlue
    static let appDark = appNavy

    // MARK: - Adaptive Colors (Dark Mode Support)

    /// Card/surface background — white in light, dark gray in dark
    static let appSurface = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1)  // #1C1C1E
            : UIColor.white
    })

    /// Page background — soft blue in light, dark blue-gray in dark
    static let appBackgroundAdaptive = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.11, green: 0.13, blue: 0.19, alpha: 1)  // #1C2130
            : UIColor(red: 0.91, green: 0.945, blue: 0.984, alpha: 1) // #E8F1FB
    })

    /// Shadow color — visible in light, subtle/clear in dark
    static let appShadow = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.04)
            : UIColor.black.withAlphaComponent(0.1)
    })

    /// Ghost mode overlay — adapts for readability
    static let appGhostOverlay = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.15)
            : UIColor.black.withAlphaComponent(0.5)
    })

    /// Ghost mode stroke
    static let appGhostStroke = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.4)
            : UIColor.white.withAlphaComponent(0.6)
    })

    /// Convert a Color to a hex string for Firestore storage
    func toHexString() -> String {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }

    // Initialize Color from hex string
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
