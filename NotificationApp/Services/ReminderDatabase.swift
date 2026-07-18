//
//  ReminderDatabase.swift
//  NotificationApp
//
//  Persists reminders in a local SQLite database. Uses Apple's built-in
//  SQLite3 C library directly, which requires linking "libsqlite3.tbd" in
//  the app target's Build Phases in Xcode.
//

import Foundation
import SQLite3
import os

// Tells SQLite to copy the bound string immediately rather than holding a
// pointer to it — Swift only guarantees the string's buffer for the call.
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

// A class, not a struct, because it owns a native SQLite connection that
// must be closed in deinit. Marked nonisolated to opt out of this project's
// default main-actor isolation, since it's plain synchronous I/O.
nonisolated final class ReminderDatabase {
    private var db: OpaquePointer?
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "NotificationApp",
        category: "ReminderDatabase"
    )

    init(fileName: String = "reminders.sqlite") {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsDirectory.appendingPathComponent(fileName)

        if sqlite3_open(fileURL.path, &db) != SQLITE_OK {
            logger.error("Failed to open database at \(fileURL.path, privacy: .public): \(String(cString: sqlite3_errmsg(self.db)), privacy: .public)")
            db = nil
            return
        }
        logger.info("Opened SQLite database at \(fileURL.path, privacy: .public)")
        createTableIfNeeded()
    }

    deinit {
        sqlite3_close(db)
    }

    private func createTableIfNeeded() {
        let sql = """
        CREATE TABLE IF NOT EXISTS reminders (
            id    TEXT PRIMARY KEY NOT NULL,
            title TEXT NOT NULL,
            date  REAL NOT NULL
        );
        """
        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            logger.error("Failed to create reminders table: \(String(cString: sqlite3_errmsg(self.db)), privacy: .public)")
        }
    }

    /* Reads every row, sorted soonest-first by SQL itself. */
    func fetchAll() -> [Reminder] {
        let sql = "SELECT id, title, date FROM reminders ORDER BY date ASC;"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            logger.error("fetchAll: prepare failed: \(String(cString: sqlite3_errmsg(self.db)), privacy: .public)")
            return []
        }

        var results: [Reminder] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let idText = sqlite3_column_text(statement, 0),
                  let id = UUID(uuidString: String(cString: idText)),
                  let titleText = sqlite3_column_text(statement, 1)
            else { continue }

            let title = String(cString: titleText)
            let date = Date(timeIntervalSince1970: sqlite3_column_double(statement, 2))
            results.append(Reminder(id: id, title: title, date: date))
        }
        logger.debug("fetchAll returned \(results.count, privacy: .public) reminder(s).")
        return results
    }

    func insert(_ reminder: Reminder) {
        let sql = "INSERT INTO reminders (id, title, date) VALUES (?, ?, ?);"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            logger.error("insert: prepare failed: \(String(cString: sqlite3_errmsg(self.db)), privacy: .public)")
            return
        }
        sqlite3_bind_text(statement, 1, reminder.id.uuidString, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, reminder.title, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(statement, 3, reminder.date.timeIntervalSince1970)

        if sqlite3_step(statement) != SQLITE_DONE {
            logger.error("insert: step failed for id=\(reminder.id.uuidString, privacy: .public): \(String(cString: sqlite3_errmsg(self.db)), privacy: .public)")
        } else {
            logger.debug("Inserted reminder id=\(reminder.id.uuidString, privacy: .public)")
        }
    }

    func update(_ reminder: Reminder) {
        let sql = "UPDATE reminders SET title = ?, date = ? WHERE id = ?;"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            logger.error("update: prepare failed: \(String(cString: sqlite3_errmsg(self.db)), privacy: .public)")
            return
        }
        sqlite3_bind_text(statement, 1, reminder.title, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(statement, 2, reminder.date.timeIntervalSince1970)
        sqlite3_bind_text(statement, 3, reminder.id.uuidString, -1, SQLITE_TRANSIENT)

        if sqlite3_step(statement) != SQLITE_DONE {
            logger.error("update: step failed for id=\(reminder.id.uuidString, privacy: .public): \(String(cString: sqlite3_errmsg(self.db)), privacy: .public)")
        } else {
            logger.debug("Updated reminder id=\(reminder.id.uuidString, privacy: .public)")
        }
    }

    func delete(id: UUID) {
        let sql = "DELETE FROM reminders WHERE id = ?;"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            logger.error("delete: prepare failed: \(String(cString: sqlite3_errmsg(self.db)), privacy: .public)")
            return
        }
        sqlite3_bind_text(statement, 1, id.uuidString, -1, SQLITE_TRANSIENT)

        if sqlite3_step(statement) != SQLITE_DONE {
            logger.error("delete: step failed for id=\(id.uuidString, privacy: .public): \(String(cString: sqlite3_errmsg(self.db)), privacy: .public)")
        } else {
            logger.debug("Deleted reminder id=\(id.uuidString, privacy: .public)")
        }
    }
}
