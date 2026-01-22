//
//  ColorPalette.swift
//  WhosThereios
//
//  Created by Claude on 1/20/26.
//

import SwiftUI

extension Color {
    // Custom color palette
    // ["#606c38","#283618","#fefae0","#dda15e","#bc6c25"]

    static let appOliveGreen = Color(hex: "606c38")       // Primary green
    static let appDarkGreen = Color(hex: "283618")        // Dark green/black
    static let appCream = Color(hex: "fefae0")            // Light cream background
    static let appTan = Color(hex: "dda15e")              // Tan/orange accent
    static let appBrown = Color(hex: "bc6c25")            // Dark brown/orange

    // Semantic color names for easier use
    static let appPrimary = appOliveGreen
    static let appSecondary = appTan
    static let appAccent = appBrown
    static let appBackground = appCream
    static let appDark = appDarkGreen

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
