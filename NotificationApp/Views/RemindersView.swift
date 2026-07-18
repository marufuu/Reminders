//
//  RemindersView.swift
//  NotificationApp
//
//  The reminders list screen. Pushed from the Home screen, so it doesn't
//  wrap itself in its own NavigationStack.
//

import SwiftUI
import os

struct RemindersView: View {
    @StateObject private var viewModel = ReminderListViewModel()
    @StateObject private var notificationManager = NotificationManager.shared

    @State private var isPresentingAddReminder = false
    @State private var reminderToEdit: Reminder?

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "NotificationApp",
        category: "RemindersView"
    )

    var body: some View {
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
            logger.debug("RemindersView appeared — requesting notification authorization if needed.")
            await notificationManager.requestAuthorizationIfNeeded()
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

    /* Maps swipe-to-delete offsets back to the underlying reminders before
       removing them, so the sort order can't desync from the deletion. */
    private func deleteReminders(at offsets: IndexSet) {
        let sorted = viewModel.sortedReminders
        let toDelete = offsets.map { sorted[$0] }
        logger.info("Swipe-deleting \(toDelete.count, privacy: .public) reminder(s).")
        toDelete.forEach(viewModel.deleteReminder)
    }
}

#Preview {
    NavigationStack {
        RemindersView()
    }
}
