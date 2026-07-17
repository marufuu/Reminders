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
                    // A plain-language summary, the same way Reminders/Calendar
                    // show what you've currently selected.
                    Text(date.formatted(date: .complete, time: .shortened))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    // Two compact pickers bound to the SAME `date` value — the
                    // date picker only ever touches the day/month/year part,
                    // the time picker only touches hour/minute, so they don't
                    // clobber each other. This is the same pattern iOS's own
                    // Reminders app uses, and it's far less space-hungry than
                    // an always-open full calendar grid.
                    HStack {
                        Label("Date", systemImage: "calendar")
                        Spacer()
                        DatePicker(
                            "Date",
                            selection: $date,
                            in: minimumDate...,
                            displayedComponents: .date
                        )
                        .labelsHidden()
                    }

                    HStack {
                        Label("Time", systemImage: "clock")
                        Spacer()
                        DatePicker(
                            "Time",
                            selection: $date,
                            in: minimumDate...,
                            displayedComponents: .hourAndMinute
                        )
                        .labelsHidden()
                    }
                }

                Section("Quick Select") {
                    HStack(spacing: 8) {
                        quickButton("In 1 Hour") {
                            date = max(Date().addingTimeInterval(3600), minimumDate)
                        }
                        quickButton("Tomorrow") {
                            date = quickDate(daysFromNow: 1, hour: 9)
                        }
                        quickButton("Next Week") {
                            date = quickDate(daysFromNow: 7, hour: 9)
                        }
                    }
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

    /// One pill-style quick-select button; tapping it sets `date` directly.
    private func quickButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.footnote.weight(.medium))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(.blue)
    }

    /// Today + `daysFromNow` days, with the time set to `hour`:00 — used by
    /// the "Tomorrow" / "Next Week" quick-select buttons.
    private func quickDate(daysFromNow: Int, hour: Int) -> Date {
        let calendar = Calendar.current
        let base = calendar.date(byAdding: .day, value: daysFromNow, to: Date()) ?? Date()
        let withHour = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: base) ?? base
        return max(withHour, minimumDate)
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
