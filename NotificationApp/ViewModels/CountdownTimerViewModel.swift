//
//  CountdownTimerViewModel.swift
//  NotificationApp
//

internal import Combine
import Foundation
import os

/// Drives the countdown timer feature: the user picks a duration, taps
/// Start, and this ticks `remainingSeconds` down to zero once per second.
/// It also schedules a local notification for the moment the timer finishes,
/// so the user is told even if the app isn't in the foreground at the time.
@MainActor
final class CountdownTimerViewModel: ObservableObject {
    enum TimerState: Equatable {
        case configuring   // picking a duration, not started yet
        case running
        case paused
        case finished
    }

    /// Fixed id for the "time's up" notification, so it can be looked up
    /// again later for cancellation (e.g. if the user pauses or resets).
    private static let notificationID = "countdown-timer-complete"

    /// Bound to the minutes/seconds wheel pickers while `state == .configuring`.
    @Published var selectedMinutes: Int = 5
    @Published var selectedSeconds: Int = 0

    @Published private(set) var remainingSeconds: Int = 0
    @Published private(set) var state: TimerState = .configuring

    /// Holds the repeating 1-second timer subscription while running; nil
    /// whenever the timer isn't actively counting down.
    private var ticker: AnyCancellable?

    /// The duration the countdown started at, captured once at Start —
    /// needed so `progress` can be computed even after `selectedMinutes`/
    /// `selectedSeconds` no longer matter.
    private var totalDurationSeconds: Int = 0

    private let notificationManager = NotificationManager.shared
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "NotificationApp",
        category: "CountdownTimerViewModel"
    )

    var totalSecondsSelected: Int { selectedMinutes * 60 + selectedSeconds }

    /// "05:00" style display of `remainingSeconds`.
    var formattedRemaining: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// 0 at the start of the countdown, 1 once finished — drives the
    /// circular progress ring in the UI.
    var progress: Double {
        guard totalDurationSeconds > 0 else { return 0 }
        return 1 - (Double(remainingSeconds) / Double(totalDurationSeconds))
    }

    /// Starts a fresh countdown (from `.configuring`) or resumes a paused one.
    func start() {
        if state == .configuring {
            guard totalSecondsSelected > 0 else { return }
            totalDurationSeconds = totalSecondsSelected
            remainingSeconds = totalSecondsSelected
        }
        guard remainingSeconds > 0 else { return }

        state = .running
        logger.info("Timer started/resumed: \(self.remainingSeconds, privacy: .public)s remaining")

        // Schedule the "time's up" notification for exactly when the
        // remaining time will hit zero, so it still fires if the app gets
        // backgrounded mid-countdown.
        notificationManager.scheduleNotification(
            id: Self.notificationID,
            title: "Time's Up",
            body: "Your countdown timer has finished.",
            secondsFromNow: TimeInterval(remainingSeconds)
        )

        ticker = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }

    func pause() {
        guard state == .running else { return }
        state = .paused
        ticker?.cancel()
        ticker = nil
        // Cancel the pending notification — it was scheduled for the
        // original finish time, which no longer applies once paused.
        notificationManager.cancelNotification(id: Self.notificationID)
        logger.info("Timer paused with \(self.remainingSeconds, privacy: .public)s remaining")
    }

    /// Cancels the countdown entirely and returns to duration-picking.
    func reset() {
        ticker?.cancel()
        ticker = nil
        state = .configuring
        remainingSeconds = 0
        totalDurationSeconds = 0
        notificationManager.cancelNotification(id: Self.notificationID)
        logger.info("Timer reset")
    }

    private func tick() {
        guard remainingSeconds > 0 else {
            finish()
            return
        }
        remainingSeconds -= 1
        if remainingSeconds == 0 {
            finish()
        }
    }

    private func finish() {
        ticker?.cancel()
        ticker = nil
        state = .finished
        logger.info("Timer finished")
    }
}
