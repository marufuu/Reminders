//
//  ContentView.swift
//  NotificationApp
//
//  Created by Maruf on 15/7/26.
//
//  This is now the app's Home screen. It owns the single NavigationStack for
//  the whole app and presents two features as tappable cards. The
//  destinations (RemindersView, CountdownTimerView) deliberately do NOT wrap
//  themselves in their own NavigationStack — they rely on this one, so their
//  own .navigationTitle/.toolbar still show up correctly once pushed.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    NavigationLink {
                        RemindersView()
                    } label: {
                        HomeFeatureCard(
                            title: "Reminders",
                            subtitle: "Create reminders that notify you at a set time",
                            systemImage: "bell.badge.fill",
                            tint: .orange
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        CountdownTimerView()
                    } label: {
                        HomeFeatureCard(
                            title: "Countdown Timer",
                            subtitle: "Set a duration and count down to zero",
                            systemImage: "timer",
                            tint: .blue
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Home")
        }
    }
}

/// A large tappable card shown on the home screen for one feature.
private struct HomeFeatureCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tint.gradient)
                    .frame(width: 56, height: 56)
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

#Preview {
    ContentView()
}
