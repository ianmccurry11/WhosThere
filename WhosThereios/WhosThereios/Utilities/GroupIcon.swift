//
//  GroupIcon.swift
//  WhosThereios
//
//  Created by Ian McCurry on 3/17/26.
//

import Foundation

struct GroupIcon {
    struct CustomIcon: Identifiable {
        var id: String { assetName }
        let assetName: String
        let displayName: String
    }

    // MARK: - Add new icons here (and drop the PNG into SharedAssets.xcassets)
    static let customIcons: [CustomIcon] = [
        CustomIcon(assetName: "icon_cat", displayName: "Cat"),
        CustomIcon(assetName: "icon_pickleball", displayName: "Pickleball"),
        CustomIcon(assetName: "icon_pickleball_court", displayName: "Pickleball Court"),
    ]

    private static let customIconNames: Set<String> = Set(customIcons.map(\.assetName))

    static func isCustomIcon(_ value: String) -> Bool {
        customIconNames.contains(value)
    }

    /// Returns a fallback emoji for use in plain-text contexts (e.g. notifications)
    static func fallbackEmoji(for value: String) -> String {
        isCustomIcon(value) ? "📍" : value
    }
}
