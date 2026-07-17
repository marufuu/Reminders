//
//  ReminderDatabase.swift
//  NotificationApp
//
//  Persists reminders in a local SQLite database instead of a JSON file.
//  Uses Apple's built-in SQLite3 C library directly (no third-party
//  dependency) — this requires linking the system "libsqlite3.tbd" library
//  in the app target's Build Phases in Xcode. See project notes for setup.
//

import Foundation
import SQLite3
import os

/// SQLite's C API expects a "destructor" function pointer telling it what to
/// do with the string/blob pointer you hand it once the call returns.
/// SQLITE_TRANSIENT tells SQLite "copy this data internally right now,
/// because I'm not guaranteeing it'll still be valid after this call" — the
/// safe choice when binding a Swift String, since Swift only guarantees the
/// underlying buffer for the duration of the C call.
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// A single reminder row, stored as (id TEXT, title TEXT, date REAL).
/// A `class`, not a `struct`, because it owns a native SQLite connection
/// handle (`db`) that must be explicitly closed in `deinit` — structs can't
/// have a deinitializer. Marked `nonisolated` (like `ReminderStore` was) to
/// opt out of this project's default main-actor isolation, since this type
/// does plain synchronous, self-contained file/database I/O.
nonisolated final class ReminderDatabase {
    /// Opaque handle to the open SQLite connection. `OpaquePointer` is
    /// Swift's stand-in for an untyped C pointer (`sqlite3 *` in C).
    private var db: OpaquePointer?

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "NotificationApp",
        category: "ReminderDatabase"
    )

    init(fileName: String = "reminders.sqlite") {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsDirectory.appendingPathComponent(fileName)

        // sqlite3_open creates the file if it doesn't exist yet, or opens
        // the existing one. Passing `&db` lets it write the connection
        // handle into our property.
        if sqlite3_open(fileURL.path, &db) != SQLITE_OK {
            logger.error("Failed to open database at \(fileURL.path, privacy: .public): \(String(cString: sqlite3_errmsg(self.db)), privacy: .public)")
            db = nil
            return
        }
        logger.info("Opened SQLite database at \(fileURL.path, privacy: .public)")
        createTableIfNeeded()
    }

    deinit {
        // Always close the connection when this object goes away, so the
        // OS-level file handle doesn't leak.
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
        // sqlite3_exec runs a plain SQL statement with no parameters and no
        // rows to read back — perfect for one-off setup statements like this.
        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            logger.error("Failed to create reminders table: \(String(cString: sqlite3_errmsg(self.db)), privacy: .public)")
        }
    }

    /// Reads every row, letting SQL itself do the sorting (soonest date first).
    func fetchAll() -> [Reminder] {
        let sql = "SELECT id, title, date FROM reminders ORDER BY date ASC;"
        var statement: OpaquePointer?
        // `defer` guarantees sqlite3_finalize runs no matter which `return`
        // below fires — every prepared statement must be finalized or it leaks.
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            logger.error("fetchAll: prepare failed: \(String(cString: sqlite3_errmsg(self.db)), privacy: .public)")
            return []
        }

        var results: [Reminder] = []
        // sqlite3_step advances one row at a time. SQLITE_ROW means "here's
        // a row of data"; the loop ends when it returns anything else
        // (SQLITE_DONE = no more rows).
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
        // The "?" placeholders above are filled in by position, 1-indexed.
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
