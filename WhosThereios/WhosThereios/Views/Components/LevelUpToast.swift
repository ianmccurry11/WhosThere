//
//  LevelUpToast.swift
//  WhosThereios
//

import SwiftUI

/// Toast notification shown when a user levels up.
/// Follows the same pattern as AchievementUnlockedToast.
struct LevelUpToast: View {
    let level: Int

    private var userLevel: UserLevel {
        UserLevel.calculate(from: UserLevel.cumulativeXP(forLevel: level))
    }

    var body: some View {
        HStack(spacing: 12) {
            // Level badge circle
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                Text("\(level)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Level Up!")
                    .font(.caption)
                    .foregroundColor(.blue)

                Text("Level \(level) - \(userLevel.tierName)")
                    .font(.headline)

                // Show special message on new tier thresholds
                if level % 10 == 1 && level > 1 {
                    Text("New tier: \(userLevel.tierName)!")
                        .font(.caption)
                        .foregroundColor(.purple)
                } else {
                    Text("+\(UserLevel.xpToAdvance(from: level - 1)) XP earned")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .appShadow, radius: 20, y: 10)
        )
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Level up! You are now level \(level), \(userLevel.tierName)")
    }
}

#Preview {
    VStack(spacing: 20) {
        LevelUpToast(level: 2)
        LevelUpToast(level: 11)
        LevelUpToast(level: 50)
    }
    .padding()
}
