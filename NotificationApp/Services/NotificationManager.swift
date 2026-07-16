//
//  NotificationManager.swift
//  NotificationApp
//

import Foundation
import UserNotifications
internal import Combine
import UIKit
import os

/// Wraps `UNUserNotificationCenter`: requests permission, schedules/cancels
/// per-reminder notifications, and routes the user to Settings when
/// permission has been denied.
@MainActor
final class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let center = UNUserNotificationCenter.current()

    /// Structured logger for this class. View logs live in Xcode's console
    /// while debugging, or in Console.app (filter by subsystem = your bundle
    /// id, category = "NotificationManager") to see them on-device too.
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "NotificationApp",
        category: "NotificationManager"
    )

    private override init() {
        super.init()
        center.delegate = self
    }

    /// Requests permission only the first time (status `.notDetermined`).
    /// Call `refreshAuthorizationStatus()` separately to pick up changes the
    /// user makes in Settings after that.
    ///
    /// *** This is where the native system popup comes from. ***
    /// The line `center.requestAuthorization(options:)` below is the single
    /// call that makes iOS display its built-in alert:
    ///   "NotificationApp Would Like to Send You Notifications"
    ///   Allow / Allow in Scheduled Summary / Don't Allow
    /// That dialog is rendered entirely by iOS (SpringBoard), outside our
    /// app's UI — we don't draw it and can't restyle it. The only things we
    /// control are *which* capabilities we ask for (the `options:` array,
    /// which is why "Allow in Scheduled Summary" appears) and *when* we call
    /// this function. iOS only shows the popup while status is
    /// `.notDetermined`, i.e. the very first time we ask — that's what the
    /// guard below enforces on our side too, so we don't even attempt it
    /// again on subsequent launches.
    func requestAuthorizationIfNeeded() async {
        await refreshAuthorizationStatus()

        guard authorizationStatus == .notDetermined else {
            logger.debug("Authorization already determined (\(String(describing: self.authorizationStatus), privacy: .public)) — skipping system prompt.")
            return
        }

        logger.info("Status is .notDetermined — calling requestAuthorization(), system popup should appear now.")
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        logger.info("User responded to the system popup. granted=\(granted, privacy: .public)")

        await refreshAuthorizationStatus()
    }

    /// Re-reads the current permission state from iOS. This value is not
    /// something we store ourselves — `UNUserNotificationCenter` asks a
    /// system-level daemon that is the single source of truth for this app's
    /// permission state (the same record Settings > Notifications reads and
    /// writes). That's why we re-check it here rather than caching a value
    /// we set once: the user can flip it in Settings at any time, outside
    /// our app's control.
    func refreshAuthorizationStatus() async {
        authorizationStatus = await center.notificationSettings().authorizationStatus
        logger.debug("authorizationStatus refreshed -> \(String(describing: self.authorizationStatus), privacy: .public)")
    }

    /// Schedules a one-time local notification that fires at `reminder.date`.
    /// Uses the reminder's own id as the request identifier so it can be
    /// looked up later for cancellation or rescheduling.
    func scheduleNotification(for reminder: Reminder) {
        let content = UNMutableNotificationContent()
        content.title = "Reminder"
        content.body = reminder.title
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: reminder.date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: reminder.id.uuidString,
            content: content,
            trigger: trigger
        )
        center.add(request)
        logger.info("Scheduled notification id=\(reminder.id.uuidString, privacy: .public) title=\"\(reminder.title, privacy: .public)\" date=\(reminder.date.description, privacy: .public)")
    }

    func cancelNotification(for reminder: Reminder) {
        center.removePendingNotificationRequests(withIdentifiers: [reminder.id.uuidString])
        logger.info("Cancelled notification id=\(reminder.id.uuidString, privacy: .public)")
    }

    func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        logger.debug("Opening system Settings app for this app (user tapped the permission-denied banner).")
        UIApplication.shared.open(url)
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    /// Lets the banner and sound show even while the app is in the foreground.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // Local Logger instance here (not `self.logger`) because this method
        // is `nonisolated` and can't touch main-actor-isolated properties.
        Logger(subsystem: Bundle.main.bundleIdentifier ?? "NotificationApp", category: "NotificationManager")
            .info("willPresent notification id=\(notification.request.identifier, privacy: .public) while app is in foreground.")
        return [.banner, .sound, .badge]
    }
}
