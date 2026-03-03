// File: MenuContentView.swift
import SwiftUI

/// Drop-down content shown when the user clicks the OctoBar menu bar item.
struct MenuContentView: View {
    @EnvironmentObject var monitor: TariffMonitor
    @State private var showingInfo = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            MenuHeader(showingInfo: $showingInfo)

            Divider()

            TariffStatusSection(display: monitor.display)

            if !monitor.display.schedule.isEmpty {
                Divider()
                DispatchScheduleSection(schedule: monitor.display.schedule)
            }

            Divider()

            Text(monitor.display.lastUpdatedLabel)
                .foregroundStyle(.secondary)
                .font(.caption)
                .opacity(monitor.display.lastUpdatedLabel.isEmpty ? 0 : 1)

            Divider()

            MenuButtonBar()
        }
        .padding()
        .frame(width: 260)
    }
}

// MARK: - Static header (never recomputed by monitor changes)

private struct MenuHeader: View {
    @Binding var showingInfo: Bool

    var body: some View {
        HStack {
            Text("OctoBar")
                .font(.headline)
            Spacer()
            Button {
                showingInfo.toggle()
            } label: {
                Image(systemName: "info.circle")
            }
            .buttonStyle(.plain)
        }

        if showingInfo {
            Text("OctoBar monitors your Octopus Energy Intelligent Go tariff and shows the current unit rate in the menu bar. The icon turns green when cheap rate is active and orange when on standard rate.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Tariff display (Equatable to skip re-render when display unchanged)

private struct TariffStatusSection: Equatable, View {
    let display: DisplayState

    var body: some View {
        // Always-present views — no structural identity changes
        Text(display.rateDetail)
            .font(.system(.body, design: .monospaced).bold())
            .opacity(display.rateDetail.isEmpty ? 0 : 1)

        Text(display.statusText)

        Text(display.timingLabel)
            .foregroundStyle(.secondary)
            .opacity(display.timingLabel.isEmpty ? 0 : 1)
    }
}

// MARK: - Dispatch schedule

private struct DispatchScheduleSection: Equatable, View {
    let schedule: [ScheduleSlot]

    var body: some View {
        Text("Tarrif Schedule")
            .font(.caption.bold())
            .foregroundStyle(.secondary)

        ForEach(schedule) { slot in
            HStack(spacing: 6) {
                Circle()
                    .fill(slot.isActive ? Color.green : Color.secondary.opacity(0.4))
                    .frame(width: 6, height: 6)
                Text(slot.timeRange)
                    .font(.system(.caption, design: .monospaced))
                if slot.isActive {
                    Text("now")
                        .font(.caption2.bold())
                        .foregroundStyle(.green)
                }
            }
        }
    }
}

// MARK: - Button bar (static, never recomputed)

private struct MenuButtonBar: View {
    @EnvironmentObject var monitor: TariffMonitor

    var body: some View {
        HStack {
            Button("Refresh") {
                Task { await monitor.refresh() }
            }

            Button("Settings…") {
                SettingsWindowController.shared.showSettings(monitor: monitor)
            }

            Spacer()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .buttonStyle(.bordered)
    }
}
