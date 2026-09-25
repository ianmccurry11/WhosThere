//
//  WhosThereTimelineProvider.swift
//  WhosThereWidget
//
//  Created by Claude on 2/6/26.
//

import WidgetKit
import SwiftUI

struct WidgetGroupData: Identifiable {
    let id: String
    let name: String
    let emoji: String
    let presentCount: Int
    let presenceText: String
    let isFavorite: Bool
}

struct WhosThereEntry: TimelineEntry {
    let date: Date
    let groups: [WidgetGroupData]
}

struct WhosThereTimelineProvider: TimelineProvider {
    private static let appGroupId = "group.com.IanMcCurry.WhosThereios"
    private static let widgetDataKey = "widgetGroupData"

    func placeholder(in context: Context) -> WhosThereEntry {
        WhosThereEntry(date: Date(), groups: [
            WidgetGroupData(id: "1", name: "Central Park", emoji: "🏀", presentCount: 3, presenceText: "3 people here", isFavorite: true),
            WidgetGroupData(id: "2", name: "Coffee Shop", emoji: "☕️", presentCount: 1, presenceText: "1 person here", isFavorite: true),
            WidgetGroupData(id: "3", name: "Office", emoji: "🏢", presentCount: 5, presenceText: "5 people here", isFavorite: false),
            WidgetGroupData(id: "4", name: "Gym", emoji: "💪", presentCount: 0, presenceText: "No one here", isFavorite: false)
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (WhosThereEntry) -> Void) {
        let entry = WhosThereEntry(date: Date(), groups: loadGroups())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WhosThereEntry>) -> Void) {
        let entry = WhosThereEntry(date: Date(), groups: loadGroups())
        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadGroups() -> [WidgetGroupData] {
        guard let defaults = UserDefaults(suiteName: Self.appGroupId),
              let data = defaults.data(forKey: Self.widgetDataKey),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        return array.compactMap { dict in
            guard let groupId = dict["groupId"] as? String,
                  let name = dict["name"] as? String,
                  let emoji = dict["emoji"] as? String else {
                return nil
            }

            return WidgetGroupData(
                id: groupId,
                name: name,
                emoji: emoji,
                presentCount: dict["presentCount"] as? Int ?? 0,
                presenceText: dict["presenceText"] as? String ?? "No one here",
                isFavorite: dict["isFavorite"] as? Bool ?? false
            )
        }
    }
}
