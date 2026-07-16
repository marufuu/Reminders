//
//  AddEditReminderView.swift
//  NotificationApp
//

import SwiftUI
import os

/// A form for creating a new reminder or editing an existing one.
/// Passing `reminder` puts the view in edit mode; omitting it creates a new reminder.
struct AddEditReminderView: View {
    @ObservedObject var viewModel: ReminderListViewModel
    @Environment(\.dismiss) private var dismiss

    private let existingReminder: Reminder?
    private let minimumDate: Date

    @State private var title: String
    @State private var date: Date

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "NotificationApp",
        category: "AddEditReminderView"
    )

    init(viewModel: ReminderListViewModel, reminder: Reminder? = nil) {
        self.viewModel = viewModel
        self.existingReminder = reminder
        // Don't let the picker's floor exclude an existing reminder's own date,
        // but still block picking a new date in the past.
        self.minimumDate = reminder.map { min($0.date, Date()) } ?? Date()
        _title = State(initialValue: reminder?.title ?? "")
        _date = State(initialValue: reminder?.date ?? Date().addingTimeInterval(3600))
    }

    private var isTitleValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Reminder title", text: $title)
                }
                Section("Date & Time") {
                    DatePicker(
                        "Date & Time",
                        selection: $date,
                        in: minimumDate...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .labelsHidden()
                    .datePickerStyle(.graphical)
                }
            }
            .navigationTitle(existingReminder == nil ? "New Reminder" : "Edit Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!isTitleValid)
                }
            }
        }
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existingReminder {
            var updated = existingReminder
            updated.title = trimmedTitle
            updated.date = date
            logger.info("Saving edits for reminder id=\(existingReminder.id.uuidString, privacy: .public)")
            viewModel.updateReminder(updated)
        } else {
            logger.info("Saving new reminder \"\(trimmedTitle, privacy: .public)\"")
            viewModel.addReminder(title: trimmedTitle, date: date)
        }
        dismiss()
    }
}

#Preview {
    AddEditReminderView(viewModel: ReminderListViewModel())
}
