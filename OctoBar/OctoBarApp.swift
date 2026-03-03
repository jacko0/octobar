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
            let symbolName = monitor.isCheap ? "bolt.fill" : "bolt"
            let color: NSColor = monitor.isCheap ? .systemGreen : .systemOrange
            if let image = menuBarImage(systemName: symbolName, color: color) {
                Image(nsImage: image)
                Text(monitor.priceLabel)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
            }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(monitor)
        }
    }

    /// Renders an SF Symbol as a non-template NSImage with the given color,
    /// so macOS displays it in color in the menu bar.
    private func menuBarImage(systemName: String, color: NSColor) -> NSImage? {
        guard let symbol = NSImage(systemSymbolName: systemName, accessibilityDescription: nil) else { return nil }
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        let configured = symbol.withSymbolConfiguration(config) ?? symbol
        let image = NSImage(size: configured.size, flipped: false) { rect in
            color.set()
            configured.draw(in: rect)
            return true
        }
        image.isTemplate = false
        return image
    }
}
