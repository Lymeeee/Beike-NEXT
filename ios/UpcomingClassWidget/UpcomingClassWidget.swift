import WidgetKit
import SwiftUI

@main
struct UpcomingClassWidget: Widget {
    private let kind: String = "com.lyme.beikenext.widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: Provider()
        ) { entry in
            UpcomingClassWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("即将上课")
        .description("显示即将开始的课程信息")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
