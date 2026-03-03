// File: MenuContentView.swift
import SwiftUI

/// Drop-down content shown when the user clicks the OctoBar menu bar item.
struct MenuContentView: View {
    @EnvironmentObject var monitor: TariffMonitor

    var body: some View {
        // Price header
        if let rate = monitor.state.rate {
            Text(String(format: "%.2fp / kWh", rate))
                .font(.system(.body, design: .monospaced).bold())
        }

        // Status line
        Text(monitor.statusText)

        // Timing hint (cheap until / next cheap at)
        if let timing = monitor.timingLabel {
            Text(timing)
                .foregroundStyle(.secondary)
        }

        Divider()

        // Last updated
        if let updated = monitor.lastUpdated {
            Text("Updated \(updated.formatted(.relative(presentation: .named)))")
                .foregroundStyle(.tertiary)
                .font(.caption)
        }

        Divider()

        Button("Refresh") {
            Task { await monitor.refresh() }
        }
        .keyboardShortcut("r")

        SettingsLink {
            Text("Settings…")
        }

        Divider()

        Button("Quit OctoBar") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
