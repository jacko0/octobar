// File: SettingsView.swift
import SwiftUI

/// Preferences window — opened via the Settings… button.
/// All fields use local @State drafts so keystrokes don't fire objectWillChange
/// on TariffMonitor (which would cause the menu bar to re-render).
struct SettingsView: View {
    @EnvironmentObject var monitor: TariffMonitor
    var onDismiss: () -> Void = {}

    @State private var apiKeyDraft     = ""
    @State private var accountDraft    = ""
    @State private var thresholdDraft  = 9.5
    @State private var notifyDraft     = false
    @State private var revealAPIKey    = false
    @State private var saved           = false

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

                TextField("Account Number (e.g. A-AAAA1111)", text: $accountDraft)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    if saved {
                        Text("Saved")
                            .foregroundStyle(.green)
                            .font(.caption)
                            .transition(.opacity)
                    }
                    Spacer()
                    Button("Save") {
                        monitor.apiKey = apiKeyDraft
                        monitor.accountNumber = accountDraft
                        monitor.cheapThreshold = thresholdDraft
                        monitor.notificationsEnabled = notifyDraft
                        monitor.saveSettings()
                        withAnimation { saved = true }
                        Task {
                            await monitor.refresh()
                            onDismiss()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return)
                }
            }

            Section("Cheap-Rate Threshold") {
                HStack {
                    Text("Cheap rate ≤")
                    TextField(
                        "",
                        value: $thresholdDraft,
                        format: .number.precision(.fractionLength(1))
                    )
                    .frame(width: 60)
                    .textFieldStyle(.roundedBorder)
                    Text("p/KWh")
                }
                Text("Default: 9.5 p/kWh (Intelligent Go off-peak rate)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Notifications") {
                Toggle("Alert when cheap rate starts", isOn: $notifyDraft)
            }

            Section {
                Text("S.Jackson 2026")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

        }
        .formStyle(.grouped)
        .frame(width: 320)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            apiKeyDraft = monitor.apiKey
            accountDraft = monitor.accountNumber
            thresholdDraft = monitor.cheapThreshold
            notifyDraft = monitor.notificationsEnabled
        }
    }
}
