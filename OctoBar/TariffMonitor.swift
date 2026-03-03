// File: TariffMonitor.swift
import Combine
import SwiftUI
import UserNotifications

/// Central observable model. Owns settings, the poll loop, and published state.
@MainActor
final class TariffMonitor: ObservableObject {

    // MARK: - Published State

    @Published private(set) var state:       TariffState = .unknown
    @Published private(set) var lastUpdated: Date?

    // MARK: - Settings (persisted via UserDefaults / Keychain)

    @Published var accountNumber: String
    @Published var cheapThreshold: Double
    @Published var notificationsEnabled: Bool

    var apiKey: String {
        get { UserDefaults.standard.string(forKey: Keys.apiKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: Keys.apiKey) }
    }

    // MARK: - Private

    private let service   = OctopusService()
    private var pollTask: Task<Void, Never>?
    private var wasCheap  = false

    private enum Keys {
        static let apiKey        = "apiKey"
        static let account       = "accountNumber"
        static let threshold     = "cheapThreshold"
        static let notifications = "notificationsEnabled"
    }

    // MARK: - Init

    init() {
        let ud = UserDefaults.standard
        accountNumber        = ud.string(forKey: Keys.account) ?? ""
        notificationsEnabled = ud.bool(forKey:   Keys.notifications)
        let t                = ud.double(forKey:  Keys.threshold)
        cheapThreshold       = t > 0 ? t : 9.5
        startPolling()
    }

    // MARK: - Computed

    var isCheap: Bool { state.isCheap }

    var priceLabel: String {
        guard let r = state.rate else { return "—p" }
        return String(format: "%.1fp", r)
    }

    var statusText: String {
        switch state {
        case .cheap:          return "✅ Cheap Intelligent Go Active"
        case .standard:       return "Standard Rate"
        case .unknown:        return "Loading…"
        case .error(let msg): return "⚠ \(msg)"
        }
    }

    var timingLabel: String? {
        switch state {
        case .cheap(_, let until):     return until.map    { "Cheap until \(hhmm($0))" }
        case .standard(_, let next):   return next.map     { "Next cheap at \(hhmm($0))" }
        default:                       return nil
        }
    }

    // MARK: - Persistence

    func saveSettings() {
        let ud = UserDefaults.standard
        ud.set(accountNumber, forKey: Keys.account)
        ud.set(cheapThreshold, forKey: Keys.threshold)
        ud.set(notificationsEnabled, forKey: Keys.notifications)
    }

    // MARK: - Polling

    func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: .seconds(300))   // poll every 5 min
            }
        }
    }

    // MARK: - Refresh

    func refresh() async {
        guard !apiKey.isEmpty, !accountNumber.isEmpty else {
            state = .error("Configure API key & account in Settings")
            return
        }
        do {
            let rates = try await service.fetchRates(apiKey: apiKey, accountNumber: accountNumber)
            let now   = Date()
            guard let current = rates.first(where: {
                $0.validFrom <= now && ($0.validTo ?? .distantFuture) > now
            }) else {
                state = .error("No rate found for current time")
                return
            }

            // Check standard off-peak rate
            let isCheapByRate = current.valueIncVat <= cheapThreshold

            // Check Intelligent Go dispatch slots
            var dispatches: [DispatchSlot] = []
            do {
                dispatches = try await service.fetchDispatchSlots(apiKey: apiKey, accountNumber: accountNumber)
            } catch {
                // Dispatch API may not be available; continue with rate-only check
            }
            let activeDispatch = dispatches.first(where: { $0.startDt <= now && $0.endDt > now })
            let isCheapByDispatch = activeDispatch != nil

            let isCheapNow = isCheapByRate || isCheapByDispatch
            if isCheapNow {
                let until = activeDispatch?.endDt ?? current.validTo
                // During a dispatch, show the off-peak rate (lowest available), not the standard band
                let displayRate = isCheapByDispatch && !isCheapByRate
                    ? rates.map(\.valueIncVat).min() ?? current.valueIncVat
                    : current.valueIncVat
                if !wasCheap && notificationsEnabled { sendNotification() }
                wasCheap = true
                state = .cheap(rate: displayRate, until: until)
            } else {
                wasCheap = false
                // Next cheap: earliest of next off-peak rate or next dispatch slot
                let nextOffPeak = rates
                    .filter { $0.valueIncVat <= cheapThreshold && $0.validFrom > now }
                    .map(\.validFrom)
                    .min()
                let nextDispatch = dispatches
                    .filter { $0.startDt > now }
                    .map(\.startDt)
                    .min()
                let next = [nextOffPeak, nextDispatch].compactMap { $0 }.min()
                state = .standard(rate: current.valueIncVat, nextCheap: next)
            }
            lastUpdated = now
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    // MARK: - Notification

    private func sendNotification() {
        let content   = UNMutableNotificationContent()
        content.title = "OctoBar — Cheap Rate Active"
        content.body  = "Intelligent Go cheap window has started. Time to charge!"
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        )
    }

    // MARK: - Helpers

    private func hhmm(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}
