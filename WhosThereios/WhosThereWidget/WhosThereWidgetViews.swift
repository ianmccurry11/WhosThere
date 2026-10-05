//
//  WhosThereWidgetViews.swift
//  WhosThereWidget
//
//  Created by Claude on 2/6/26.
//

import SwiftUI
import WidgetKit

struct WhosThereWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: WhosThereEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(groups: entry.groups)
        case .systemMedium:
            MediumWidgetView(groups: entry.groups)
        default:
            SmallWidgetView(groups: entry.groups)
        }
    }
}

// MARK: - Small Widget

struct SmallWidgetView: View {
    let groups: [WidgetGroupData]

    var body: some View {
        if groups.isEmpty {
            EmptyWidgetView()
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Who's There")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                ForEach(groups.prefix(2)) { group in
                    SmallGroupRow(group: group)
                }

                Spacer(minLength: 0)
            }
        }
    }
}

struct SmallGroupRow: View {
    let group: WidgetGroupData

    var body: some View {
        HStack(spacing: 8) {
            GroupIconView(icon: group.emoji, size: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(group.name)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                Text(group.presenceText)
                    .font(.caption2)
                    .foregroundStyle(group.presentCount > 0 ? .green : .secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Medium Widget

struct MediumWidgetView: View {
    let groups: [WidgetGroupData]

    var body: some View {
        if groups.isEmpty {
            EmptyWidgetView()
        } else {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Who's There")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                let displayGroups = Array(groups.prefix(4))
                let rows = stride(from: 0, to: displayGroups.count, by: 2).map {
                    Array(displayGroups[$0..<min($0 + 2, displayGroups.count)])
                }

                ForEach(rows.indices, id: \.self) { rowIndex in
                    HStack(spacing: 12) {
                        ForEach(rows[rowIndex]) { group in
                            MediumGroupCell(group: group)
                        }
                        // Fill empty space if odd number in row
                        if rows[rowIndex].count == 1 {
                            Spacer()
                        }
                    }
                }

                Spacer(minLength: 0)
            }
        }
    }
}

struct MediumGroupCell: View {
    let group: WidgetGroupData

    var body: some View {
        HStack(spacing: 8) {
            GroupIconView(icon: group.emoji, size: 22)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 3) {
                    Text(group.name)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .lineLimit(1)

                    if group.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.yellow)
                    }
                }

                HStack(spacing: 4) {
                    if group.presentCount > 0 {
                        Circle()
                            .fill(.green)
                            .frame(width: 6, height: 6)
                    }
                    Text(group.presenceText)
                        .font(.caption2)
                        .foregroundStyle(group.presentCount > 0 ? .primary : .secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Empty State

struct EmptyWidgetView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "mappin.circle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("No Groups Yet")
                .font(.caption)
                .fontWeight(.medium)

            Text("Join a group to see who's there")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    WhosThereWidget()
} timeline: {
    WhosThereEntry(date: Date(), groups: [
        WidgetGroupData(id: "1", name: "Central Park Courts", emoji: "🏀", presentCount: 3, presenceText: "3 people here", isFavorite: true),
        WidgetGroupData(id: "2", name: "Coffee Shop", emoji: "☕️", presentCount: 1, presenceText: "Jake", isFavorite: true)
    ])
}

#Preview("Medium", as: .systemMedium) {
    WhosThereWidget()
} timeline: {
    WhosThereEntry(date: Date(), groups: [
        WidgetGroupData(id: "1", name: "Central Park", emoji: "🏀", presentCount: 3, presenceText: "3 people here", isFavorite: true),
        WidgetGroupData(id: "2", name: "Coffee Shop", emoji: "☕️", presentCount: 1, presenceText: "Jake", isFavorite: true),
        WidgetGroupData(id: "3", name: "Office", emoji: "🏢", presentCount: 5, presenceText: "5 people here", isFavorite: false),
        WidgetGroupData(id: "4", name: "Gym", emoji: "💪", presentCount: 0, presenceText: "No one here", isFavorite: false)
    ])
}

#Preview("Empty", as: .systemSmall) {
    WhosThereWidget()
} timeline: {
    WhosThereEntry(date: Date(), groups: [])
}
