//
//  NotificationManager.swift
//  NotificationApp
//

import Foundation
import UserNotifications
internal import Combine
import UIKit
import os

// Wraps UNUserNotificationCenter: requests permission, schedules/cancels
// notifications, and routes the user to Settings when permission is denied.
@MainActor
final class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let center = UNUserNotificationCenter.current()
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "NotificationApp",
        category: "NotificationManager"
    )

    private override init() {
        super.init()
        center.delegate = self
    }

    /* Requests permission only the first time (status .notDetermined).
       requestAuthorization(options:) below triggers iOS's native popup —
       we only control which options we ask for and when we call this. */
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

    /* Re-reads permission state from iOS — the OS's own record, not cached,
       since the user can change it in Settings anytime. */
    func refreshAuthorizationStatus() async {
        authorizationStatus = await center.notificationSettings().authorizationStatus
        logger.debug("authorizationStatus refreshed -> \(String(describing: self.authorizationStatus), privacy: .public)")
    }

    /* Schedules a one-time notification at reminder.date, keyed by the
       reminder's own id so it can be cancelled/rescheduled later. */
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

    /* General-purpose version of scheduleNotification(for:) for features
       (like the countdown timer) with no Reminder of their own. */
    func scheduleNotification(id: String, title: String, body: String, secondsFromNow: TimeInterval) {
        guard secondsFromNow > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: secondsFromNow, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request)
        logger.info("Scheduled notification id=\(id, privacy: .public) firing in \(secondsFromNow, privacy: .public)s")
    }

    func cancelNotification(id: String) {
        center.removePendingNotificationRequests(withIdentifiers: [id])
        logger.info("Cancelled notification id=\(id, privacy: .public)")
    }

    func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        logger.debug("Opening system Settings app for this app.")
        UIApplication.shared.open(url)
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    /* Lets the banner and sound show even while the app is in the foreground. */
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        Logger(subsystem: Bundle.main.bundleIdentifier ?? "NotificationApp", category: "NotificationManager")
            .info("willPresent notification id=\(notification.request.identifier, privacy: .public) while app is in foreground.")
        return [.banner, .sound, .badge]
    }
}
