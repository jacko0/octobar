// File: OctoBarApp.swift
import AppKit
import SwiftUI
import UserNotifications

// MARK: - App Delegate (hides menu bar + enables foreground notifications)

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Prevent the app from showing a menu bar when the panel activates it
        NSApp.setActivationPolicy(.accessory)

        // Allow notifications to display even when app is in foreground
        UNUserNotificationCenter.current().delegate = self
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

// MARK: - Settings Window Controller

final class SettingsWindowController {
    static let shared = SettingsWindowController()
    private var window: NSWindow?

    func showSettings(monitor: TariffMonitor) {
        if let window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(onDismiss: { [weak self] in
            self?.window?.close()
        })
        .environmentObject(monitor)

        let hostingView = NSHostingView(rootView: settingsView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "OctoBar Settings"
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = window
    }
}

@main
struct OctoBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
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
            let tint: NSColor = monitor.isCheap ? .systemGreen : .systemOrange
            Image(nsImage: menuBarImage(systemName: symbolName, tint: tint))
            Text(monitor.priceLabel)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
        }
        .menuBarExtraStyle(.window)
    }

    private static var cachedImage: NSImage?
    private static var cachedIsCheap: Bool?

    private func menuBarImage(systemName: String, tint: NSColor) -> NSImage {
        let isCheap = systemName == "bolt.fill"
        if let cached = Self.cachedImage, Self.cachedIsCheap == isCheap {
            return cached
        }
        guard let symbol = NSImage(systemSymbolName: systemName, accessibilityDescription: nil) else {
            return NSImage()
        }
        let sizeConfig = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let sized = symbol.withSymbolConfiguration(sizeConfig) ?? symbol
        let pixelSize = NSSize(width: sized.size.width * 2, height: sized.size.height * 2)

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(pixelSize.width),
            pixelsHigh: Int(pixelSize.height),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0
        ) else { return sized }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let drawRect = NSRect(origin: .zero, size: pixelSize)
        sized.draw(in: drawRect)
        tint.set()
        drawRect.fill(using: .sourceIn)
        NSGraphicsContext.restoreGraphicsState()

        let result = NSImage(size: sized.size)
        result.addRepresentation(rep)
        result.isTemplate = false
        Self.cachedImage = result
        Self.cachedIsCheap = isCheap
        return result
    }
}
