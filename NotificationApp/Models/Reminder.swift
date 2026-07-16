//
//  Reminder.swift
//  NotificationApp
//

import Foundation

/// A single reminder with a title and the date/time it should notify the user.
struct Reminder: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var date: Date

    init(id: UUID = UUID(), title: String, date: Date) {
        self.id = id
        self.title = title
        self.date = date
    }
}
