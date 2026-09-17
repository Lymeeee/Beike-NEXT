import SwiftUI

struct UpcomingClassWidgetEntryView: View {
    var entry: ClassEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if entry.hasClass {
                Text(entry.className)
                    .font(.system(size: 15, weight: .bold))
                    .lineLimit(2)

                if !entry.location.isEmpty || !entry.teacher.isEmpty {
                    HStack(spacing: 10) {
                        if !entry.location.isEmpty {
                            Text(entry.location)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        if !entry.teacher.isEmpty {
                            Text(entry.teacher)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.top, 3)
                }

                if !entry.timeRange.isEmpty {
                    Text(entry.timeRange)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding(.top, 3)
                }
            } else {
                Text(entry.className)
                    .font(.system(size: 15, weight: .bold))
                    .lineLimit(2)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .modifier(WidgetBackground())
    }
}

struct WidgetBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOSApplicationExtension 14.0, iOSApplicationExtension 17.0, *) {
            content.containerBackground(.background, for: .widget)
        } else {
            content
        }
    }
}
