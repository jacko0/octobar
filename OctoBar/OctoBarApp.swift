// File: OctoBarApp.swift
import SwiftUI
import UserNotifications

@main
struct OctoBarApp: App {
    @StateObject private var monitor = TariffMonitor()

    init() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContentView()
                .environmentObject(monitor)
        } label: {
            // Green bolt.fill when cheap, orange bolt otherwise
            HStack(spacing: 4) {
                Image(systemName: monitor.isCheap ? "bolt.fill" : "bolt")
                    .foregroundStyle(monitor.isCheap ? Color.green : Color.orange)
                Text(monitor.priceLabel)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
            }
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .environmentObject(monitor)
        }
    }
}
