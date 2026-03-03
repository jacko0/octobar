// File: OctoBarApp.swift
import AppKit
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
            let tint: NSColor = monitor.isCheap ? .systemGreen : .systemOrange
            Image(nsImage: menuBarImage(systemName: symbolName, tint: tint))
            Text(monitor.priceLabel)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(monitor)
        }
    }

    /// Rasterizes an SF Symbol with the given color baked into the pixels,
    /// so macOS cannot re-template it in the menu bar.
    private func menuBarImage(systemName: String, tint: NSColor) -> NSImage {
        guard let symbol = NSImage(systemSymbolName: systemName, accessibilityDescription: nil) else {
            return NSImage()
        }
        let sizeConfig = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let sized = symbol.withSymbolConfiguration(sizeConfig) ?? symbol
        let pixelSize = NSSize(width: sized.size.width * 2, height: sized.size.height * 2)

        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(pixelSize.width),
            pixelsHigh: Int(pixelSize.height),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0
        )!

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        // Draw the symbol as a mask, then composite with the tint color
        let drawRect = NSRect(origin: .zero, size: pixelSize)
        sized.draw(in: drawRect)
        tint.set()
        drawRect.fill(using: .sourceIn)
        NSGraphicsContext.restoreGraphicsState()

        let result = NSImage(size: sized.size)
        result.addRepresentation(rep)
        result.isTemplate = false
        return result
    }
}
