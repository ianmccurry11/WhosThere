//
//  LevelBadge.swift
//  WhosThereios
//

import SwiftUI

/// Small inline level badge shown next to usernames.
/// Displays a tier icon + level number in a colored capsule.
struct LevelBadge: View {
    let level: Int

    private var userLevel: UserLevel {
        UserLevel.calculate(from: UserLevel.cumulativeXP(forLevel: level))
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: userLevel.tierIcon)
                .font(.system(size: 9))
            Text("\(level)")
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        )
        .accessibilityLabel("Level \(level)")
    }

    private var gradientColors: [Color] {
        switch level {
        case 1...10: return [.gray, .gray.opacity(0.7)]
        case 11...20: return [.green, .green.opacity(0.7)]
        case 21...30: return [.blue, .cyan]
        case 31...40: return [.orange, .yellow]
        case 41...50: return [.purple, .blue]
        case 51...60: return [.red, .orange]
        case 61...70: return [.blue, .purple]
        case 71...80: return [.purple, .pink]
        case 81...90: return [Color(red: 1.0, green: 0.84, blue: 0.0), .orange]
        case 91...100: return [Color(red: 1.0, green: 0.84, blue: 0.0), Color.appCoral]
        default: return [.gray, .gray]
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        LevelBadge(level: 1)
        LevelBadge(level: 15)
        LevelBadge(level: 42)
        LevelBadge(level: 75)
        LevelBadge(level: 100)
    }
    .padding()
}
