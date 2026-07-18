//
//  CountdownTimerViewModel.swift
//  NotificationApp
//

internal import Combine
import Foundation
import os

// Drives the countdown timer: the user picks a duration, then this ticks
// remainingSeconds down once per second and schedules a local notification
// for the moment it finishes.
@MainActor
final class CountdownTimerViewModel: ObservableObject {
    enum TimerState: Equatable {
        case configuring
        case running
        case paused
        case finished
    }

    private static let notificationID = "countdown-timer-complete"

    @Published var selectedMinutes: Int = 5
    @Published var selectedSeconds: Int = 0
    @Published private(set) var remainingSeconds: Int = 0
    @Published private(set) var state: TimerState = .configuring

    private var ticker: AnyCancellable?
    /* Duration the countdown started at — captured once at Start so
       `progress` stays correct even after the pickers change. */
    private var totalDurationSeconds: Int = 0

    private let notificationManager = NotificationManager.shared
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "NotificationApp",
        category: "CountdownTimerViewModel"
    )

    var totalSecondsSelected: Int { selectedMinutes * 60 + selectedSeconds }

    var formattedRemaining: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /* 0 at the start, 1 when finished — drives the circular progress ring. */
    var progress: Double {
        guard totalDurationSeconds > 0 else { return 0 }
        return 1 - (Double(remainingSeconds) / Double(totalDurationSeconds))
    }

    /* Starts a fresh countdown, or resumes a paused one. */
    func start() {
        if state == .configuring {
            guard totalSecondsSelected > 0 else { return }
            totalDurationSeconds = totalSecondsSelected
            remainingSeconds = totalSecondsSelected
        }
        guard remainingSeconds > 0 else { return }

        state = .running
        logger.info("Timer started/resumed: \(self.remainingSeconds, privacy: .public)s remaining")

        /* Scheduled for exactly when time runs out, so it still fires if
           the app is backgrounded mid-countdown. */
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
        notificationManager.cancelNotification(id: Self.notificationID)
        logger.info("Timer paused with \(self.remainingSeconds, privacy: .public)s remaining")
    }

    /* Cancels the countdown entirely and returns to duration-picking. */
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
