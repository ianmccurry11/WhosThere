//
//  WhosThereWidget.swift
//  WhosThereWidget
//
//  Created by Claude on 2/6/26.
//

import WidgetKit
import SwiftUI

@main
struct WhosThereWidgetBundle: WidgetBundle {
    var body: some Widget {
        WhosThereWidget()
    }
}

struct WhosThereWidget: Widget {
    let kind: String = "WhosThereWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WhosThereTimelineProvider()) { entry in
            WhosThereWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Who's There")
        .description("See who's at your favorite groups.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
