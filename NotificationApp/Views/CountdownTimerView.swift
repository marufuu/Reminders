//
//  CountdownTimerView.swift
//  NotificationApp
//
//  The countdown timer screen: pick a duration, watch a live circular
//  countdown, then see a "time's up" state. Pushed from the Home screen, so
//  (like RemindersView) it doesn't wrap itself in its own NavigationStack.
//

import SwiftUI

struct CountdownTimerView: View {
    @StateObject private var viewModel = CountdownTimerViewModel()

    var body: some View {
        VStack {
            Spacer()

            switch viewModel.state {
            case .configuring:
                configuringView
            case .running, .paused:
                runningView
            case .finished:
                finishedView
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Countdown Timer")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Configuring (picking a duration)

    private var configuringView: some View {
        VStack(spacing: 24) {
            Text("Set a Duration")
                .font(.title2.bold())

            HStack(spacing: 0) {
                Picker("Minutes", selection: $viewModel.selectedMinutes) {
                    ForEach(0..<60, id: \.self) { minute in
                        Text("\(minute) min").tag(minute)
                    }
                }
                .pickerStyle(.wheel)

                Picker("Seconds", selection: $viewModel.selectedSeconds) {
                    ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { second in
                        Text("\(second) sec").tag(second)
                    }
                }
                .pickerStyle(.wheel)
            }
            .frame(height: 160)

            Button {
                viewModel.start()
            } label: {
                Label("Start", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.totalSecondsSelected == 0)
        }
    }

    // MARK: - Running / Paused

    private var runningView: some View {
        VStack(spacing: 32) {
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 14)

                Circle()
                    .trim(from: 0, to: viewModel.progress)
                    .stroke(
                        viewModel.state == .paused ? Color.orange : Color.blue,
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: viewModel.progress)

                VStack(spacing: 4) {
                    Text(viewModel.formattedRemaining)
                        .font(.system(size: 54, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text(viewModel.state == .paused ? "Paused" : "Remaining")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 240, height: 240)

            HStack(spacing: 20) {
                Button {
                    viewModel.reset()
                } label: {
                    Label("Cancel", systemImage: "xmark")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.bordered)
                .tint(.red)

                Button {
                    if viewModel.state == .paused {
                        viewModel.start()
                    } else {
                        viewModel.pause()
                    }
                } label: {
                    Label(
                        viewModel.state == .paused ? "Resume" : "Pause",
                        systemImage: viewModel.state == .paused ? "play.fill" : "pause.fill"
                    )
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: - Finished

    private var finishedView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)

            Text("Time's Up!")
                .font(.largeTitle.bold())

            Button {
                viewModel.reset()
            } label: {
                Label("Set a New Timer", systemImage: "arrow.counterclockwise")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

#Preview {
    NavigationStack {
        CountdownTimerView()
    }
}
