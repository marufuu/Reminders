//
//  ContentView.swift
//  NotificationApp
//
//  Created by Maruf on 15/7/26.
//

import SwiftUI
import os

struct ContentView: View {
    @StateObject private var viewModel = ReminderListViewModel()
    @StateObject private var notificationManager = NotificationManager.shared

    @State private var isPresentingAddReminder = false
    @State private var reminderToEdit: Reminder?

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "NotificationApp",
        category: "ContentView"
    )

    var body: some View {
        NavigationStack {
            List {
                if notificationManager.authorizationStatus == .denied {
                    permissionDeniedBanner
                }

                if viewModel.sortedReminders.isEmpty {
                    ContentUnavailableView(
                        "No Reminders",
                        systemImage: "bell.badge",
                        description: Text("Tap + to add your first reminder.")
                    )
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(viewModel.sortedReminders) { reminder in
                        ReminderRow(reminder: reminder)
                            .contentShape(Rectangle())
                            .onTapGesture { reminderToEdit = reminder }
                    }
                    .onDelete(perform: deleteReminders)
                }
            }
            .navigationTitle("Reminders")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isPresentingAddReminder = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $isPresentingAddReminder) {
                AddEditReminderView(viewModel: viewModel)
            }
            .sheet(item: $reminderToEdit) { reminder in
                AddEditReminderView(viewModel: viewModel, reminder: reminder)
            }
            .task {
                // Entry point for the notification permission flow. This runs
                // once as soon as this screen appears (e.g. right after
                // launch). It calls into NotificationManager, whose
                // `requestAuthorizationIfNeeded()` is the function that
                // actually triggers iOS's native permission popup
                // ("NotificationApp Would Like to Send You Notifications") —
                // see the detailed comment on that function for how/why.
                logger.debug("ContentView appeared — requesting notification authorization if needed.")
                await notificationManager.requestAuthorizationIfNeeded()
            }
        }
    }

    private var permissionDeniedBanner: some View {
        Button {
            notificationManager.openAppSettings()
        } label: {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Notifications Disabled")
                        .font(.subheadline.bold())
                    Text("Tap to enable reminders in Settings.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "bell.slash.fill")
                    .foregroundStyle(.red)
            }
        }
        .foregroundStyle(.primary)
    }

    /// Maps swipe-to-delete offsets (indices into the sorted list) back to the
    /// underlying reminders before removing them, so the sort order can't
    /// desync from the deletion.
    private func deleteReminders(at offsets: IndexSet) {
        let sorted = viewModel.sortedReminders
        let toDelete = offsets.map { sorted[$0] }
        logger.info("Swipe-deleting \(toDelete.count, privacy: .public) reminder(s).")
        toDelete.forEach(viewModel.deleteReminder)
    }
}

#Preview {
    ContentView()
}
