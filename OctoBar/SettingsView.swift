// File: SettingsView.swift
import SwiftUI

/// Preferences window — opened via the Settings… menu item.
struct SettingsView: View {
    @EnvironmentObject var monitor: TariffMonitor
    @Environment(\.dismiss) private var dismiss

    @State private var apiKeyDraft  = ""
    @State private var revealAPIKey = false
    @State private var saved        = false

    var body: some View {
        Form {
            Section("Octopus API Credentials") {
                Group {
                    if revealAPIKey {
                        TextField("API Key", text: $apiKeyDraft)
                    } else {
                        SecureField("API Key", text: $apiKeyDraft)
                    }
                }
                .textFieldStyle(.roundedBorder)

                Toggle("Reveal key", isOn: $revealAPIKey)

                TextField("Account Number (e.g. A-AAAA1111)", text: $monitor.accountNumber)
                    .textFieldStyle(.roundedBorder)
            }

            Section("Cheap-Rate Threshold") {
                HStack {
                    Text("Cheap rate ≤")
                    TextField(
                        "",
                        value: $monitor.cheapThreshold,
                        format: .number.precision(.fractionLength(1))
                    )
                    .frame(width: 60)
                    .textFieldStyle(.roundedBorder)
                    Text("p / kWh")
                }
                Text("Default: 9.5 p/kWh (Intelligent Go off-peak rate)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Notifications") {
                Toggle("Alert when cheap rate starts", isOn: $monitor.notificationsEnabled)
            }

            HStack {
                if saved {
                    Text("Saved")
                        .foregroundStyle(.green)
                        .font(.caption)
                        .transition(.opacity)
                }
                Spacer()
                Button("Save & Refresh") {
                    monitor.apiKey = apiKeyDraft
                    monitor.saveSettings()
                    withAnimation { saved = true }
                    Task {
                        await monitor.refresh()
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 400, idealWidth: 440)
        .onAppear { apiKeyDraft = monitor.apiKey }
    }
}
