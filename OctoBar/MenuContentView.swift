// File: MenuContentView.swift
import SwiftUI

/// Drop-down content shown when the user clicks the OctoBar menu bar item.
struct MenuContentView: View {
    @EnvironmentObject var monitor: TariffMonitor
    @State private var showingInfo = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading) {
                    Text("OctoBar")
                        .font(.headline)
                    Text("S.Jackson 2026")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                Spacer()
                Button {
                    showingInfo.toggle()
                } label: {
                    Image(systemName: "info.circle")
                }
                .buttonStyle(.plain)
            }

            if showingInfo {
                Text("OctoBar monitors your Octopus Energy Intelligent Go tariff and shows the current unit rate in the menu bar. The icon turns green when a cheap rate is active.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            // Price header
            if let rate = monitor.state.rate {
                Text(String(format: "%.2fp/kWh", rate))
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
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }

            Divider()

            HStack {
                Button("Refresh") {
                    Task { await monitor.refresh() }
                }

                SettingsLink {
                    Text("Settings…")
                }

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(width: 260)
    }
}
