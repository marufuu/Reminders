//
//  ReminderListViewModel.swift
//  NotificationApp
//

internal import Combine
import Foundation
import os

// Owns the list of reminders and exposes CRUD operations to the views.
// Backed by ReminderDatabase (SQLite) — each method runs one SQL operation
// for the row that changed, then updates `reminders` to match.
@MainActor
final class ReminderListViewModel: ObservableObject {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "NotificationApp",
        category: "ReminderListViewModel"
    )

    @Published private(set) var reminders: [Reminder] = []

    private let notificationManager = NotificationManager.shared
    private let database: ReminderDatabase

    init(database: ReminderDatabase = ReminderDatabase()) {
        self.database = database
        reminders = database.fetchAll()
        logger.info("Loaded \(self.reminders.count, privacy: .public) reminder(s) from SQLite on init.")
    }

    /* Reminders sorted soonest-first, the order the list UI displays them in. */
    var sortedReminders: [Reminder] {
        reminders.sorted { $0.date < $1.date }
    }

    func addReminder(title: String, date: Date) {
        let reminder = Reminder(title: title, date: date)
        database.insert(reminder)
        reminders.append(reminder)
        notificationManager.scheduleNotification(for: reminder)
        logger.info("Added reminder \"\(reminder.title, privacy: .public)\" id=\(reminder.id.uuidString, privacy: .public)")
    }

    func updateReminder(_ reminder: Reminder) {
        guard let index = reminders.firstIndex(where: { $0.id == reminder.id }) else {
            logger.error("updateReminder called with unknown id=\(reminder.id.uuidString, privacy: .public) — ignoring.")
            return
        }
        database.update(reminder)
        reminders[index] = reminder
        /* Re-schedule since the date/title may have changed. */
        notificationManager.cancelNotification(for: reminder)
        notificationManager.scheduleNotification(for: reminder)
        logger.info("Updated reminder id=\(reminder.id.uuidString, privacy: .public), rescheduled its notification.")
    }

    func deleteReminder(_ reminder: Reminder) {
        database.delete(id: reminder.id)
        reminders.removeAll { $0.id == reminder.id }
        notificationManager.cancelNotification(for: reminder)
        logger.info("Deleted reminder id=\(reminder.id.uuidString, privacy: .public)")
    }
}
