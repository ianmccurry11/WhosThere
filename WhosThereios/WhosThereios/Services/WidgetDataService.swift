//
//  WidgetDataService.swift
//  WhosThereios
//
//  Created by Claude on 2/6/26.
//

import Foundation
import WidgetKit

/// Syncs group and presence data to shared App Groups UserDefaults for the widget.
@MainActor
class WidgetDataService {
    static let shared = WidgetDataService()

    static let appGroupId = "group.com.IanMcCurry.WhosThereios"
    static let widgetDataKey = "widgetGroupData"

    private let defaults: UserDefaults?

    private init() {
        defaults = UserDefaults(suiteName: WidgetDataService.appGroupId)
    }

    /// Sync favorite/joined groups with presence counts to shared storage.
    func syncToWidget() {
        guard let defaults else {
            AppLogger.debug("WidgetDataService: App Group UserDefaults not available")
            return
        }

        let firestoreService = FirestoreService.shared
        let presenceService = PresenceService.shared

        // Get favorite groups first, then remaining joined groups
        let favoriteIds = Set(firestoreService.currentUser?.favoriteGroupIds ?? [])
        let allJoined = firestoreService.joinedGroups

        let favorites = allJoined.filter { favoriteIds.contains($0.id ?? "") }
        let nonFavorites = allJoined.filter { !favoriteIds.contains($0.id ?? "") }
        let orderedGroups = favorites + nonFavorites

        // Take top 6 groups for widget display
        let widgetGroups: [[String: Any]] = orderedGroups.prefix(6).map { group in
            let groupId = group.id ?? ""
            let presentCount = presenceService.presenceByGroup[groupId]?.presentCount ?? 0
            let presenceText = presenceService.formatPresenceDisplay(for: group)
            let isFavorite = favoriteIds.contains(groupId)

            return [
                "groupId": groupId,
                "name": group.name,
                "emoji": group.displayEmoji,
                "presentCount": presentCount,
                "presenceText": presenceText,
                "isFavorite": isFavorite
            ]
        }

        do {
            let data = try JSONSerialization.data(withJSONObject: widgetGroups)
            defaults.set(data, forKey: WidgetDataService.widgetDataKey)
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            AppLogger.debug("WidgetDataService: Failed to serialize widget data: \(error)")
        }
    }
}
