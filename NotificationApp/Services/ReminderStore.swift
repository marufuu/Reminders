//
//  ReminderStore.swift
//  NotificationApp
//

import Foundation
import os

/// Persists reminders to a JSON file in the app's Documents directory so
/// they survive an app relaunch. Plain synchronous file I/O with no shared
/// mutable state, so it opts out of this project's default main-actor
/// isolation rather than inheriting it.
nonisolated struct ReminderStore {
    private let fileURL: URL
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "NotificationApp",
        category: "ReminderStore"
    )

    init(fileName: String = "reminders.json") {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = documentsDirectory.appendingPathComponent(fileName)
    }

    func load() -> [Reminder] {
        guard let data = try? Data(contentsOf: fileURL) else {
            logger.debug("No reminders.json found at \(self.fileURL.path, privacy: .public) — starting with an empty list.")
            return []
        }
        guard let reminders = try? JSONDecoder().decode([Reminder].self, from: data) else {
            logger.error("Found reminders.json but failed to decode it — returning an empty list.")
            return []
        }
        logger.debug("Loaded \(reminders.count, privacy: .public) reminder(s) from \(self.fileURL.path, privacy: .public)")
        return reminders
    }

    func save(_ reminders: [Reminder]) {
        guard let data = try? JSONEncoder().encode(reminders) else {
            logger.error("Failed to encode \(reminders.count, privacy: .public) reminder(s) for saving.")
            return
        }
        do {
            try data.write(to: fileURL, options: .atomic)
            logger.debug("Wrote \(reminders.count, privacy: .public) reminder(s) to \(self.fileURL.path, privacy: .public)")
        } catch {
            logger.error("Failed to write reminders.json: \(error.localizedDescription, privacy: .public)")
        }
    }
}
