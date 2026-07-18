//
//  ReminderRow.swift
//  NotificationApp
//

import SwiftUI

// A single row displaying a reminder's title and formatted date/time.
struct ReminderRow: View {
    let reminder: Reminder

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(reminder.title)
                .font(.body)
            Text(reminder.date.formatted(date: .abbreviated, time: .shortened))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ReminderRow(reminder: Reminder(title: "Take medicine", date: .now))
}
