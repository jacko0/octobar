// File: TariffMonitor.swift
import Combine
import SwiftUI
import UserNotifications

/// Central observable model. Owns settings, the poll loop, and published state.
@MainActor
final class TariffMonitor: ObservableObject {

    // MARK: - Published State (single property to minimize objectWillChange firings)

    @Published private(set) var display = DisplayState()

    /// Internal state used by refresh logic — not published directly.
    private(set) var state: TariffState = .unknown
    private var dispatches: [DispatchSlot] = []

    // MARK: - Settings (not @Published — only used in SettingsView bindings, not display)

    var accountNumber: String
    var notificationsEnabled: Bool
    var compactMode: Bool
    private let cheapThreshold: Double = 9.5

    var apiKey: String {
        get { UserDefaults.standard.string(forKey: Keys.apiKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: Keys.apiKey) }
    }

    // MARK: - Private

    private let service   = OctopusService()
    private var pollTask: Task<Void, Never>?
    private var flashTask: Task<Void, Never>?
    private var wasCheap  = false
    private var previousIsCheap: Bool?

    private enum Keys {
        static let apiKey        = "apiKey"
        static let account       = "accountNumber"
        static let notifications = "notificationsEnabled"
        static let compactMode   = "compactMode"
    }

    // MARK: - Init

    init() {
        let ud = UserDefaults.standard
        accountNumber        = ud.string(forKey: Keys.account) ?? ""
        notificationsEnabled = ud.bool(forKey:   Keys.notifications)
        compactMode          = ud.object(forKey: Keys.compactMode) == nil ? true : ud.bool(forKey: Keys.compactMode)
        startPolling()
    }

    // MARK: - Convenience accessors for menu bar label

    var isCheap: Bool { display.isCheap }
    var priceLabel: String { display.priceLabel }

    // MARK: - Persistence

    func saveSettings() {
        let ud = UserDefaults.standard
        ud.set(accountNumber, forKey: Keys.account)
        ud.set(notificationsEnabled, forKey: Keys.notifications)
        ud.set(compactMode, forKey: Keys.compactMode)
        updateDerivedState()
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
            updateDerivedState()
            return
        }
        do {
            let key = apiKey
            let account = accountNumber
            let threshold = cheapThreshold

            async let ratesFetch = service.fetchRates(apiKey: key, accountNumber: account)
            async let dispatchFetch = service.fetchDispatchSlots(apiKey: key, accountNumber: account)

            let rates = try await ratesFetch
            let fetchedDispatches = (try? await dispatchFetch) ?? []

            // Process data off the main thread
            let result = await Task.detached {
                Self.processRates(rates, dispatches: fetchedDispatches, threshold: threshold)
            }.value

            dispatches = fetchedDispatches

            switch result {
            case .noRate:
                state = .error("No rate found for current time")
                updateDerivedState()
            case .cheap(let newState, let shouldNotify):
                if shouldNotify && !wasCheap && notificationsEnabled { sendNotification() }
                wasCheap = true
                state = newState
                updateDerivedState()
            case .standard(let newState):
                wasCheap = false
                state = newState
                updateDerivedState()
            }
        } catch {
            state = .error(error.localizedDescription)
            updateDerivedState()
        }
    }

    // MARK: - Off-main-thread processing

    private enum RefreshResult: Sendable {
        case noRate
        case cheap(TariffState, shouldNotify: Bool)
        case standard(TariffState)
    }

    nonisolated private static func processRates(
        _ rates: [UnitRate],
        dispatches: [DispatchSlot],
        threshold: Double
    ) -> RefreshResult {
        let now = Date()
        guard let current = rates.first(where: {
            $0.validFrom <= now && ($0.validTo ?? .distantFuture) > now
        }) else {
            return .noRate
        }

        let isCheapByRate = current.valueIncVat <= threshold
        let activeDispatch = dispatches.first(where: { $0.startDt <= now && $0.endDt > now })
        let isCheapByDispatch = activeDispatch != nil
        let isCheapNow = isCheapByRate || isCheapByDispatch

        if isCheapNow {
            let until = activeDispatch?.endDt ?? current.validTo
            let displayRate = isCheapByDispatch && !isCheapByRate
                ? rates.map(\.valueIncVat).min() ?? current.valueIncVat
                : current.valueIncVat
            return .cheap(.cheap(rate: displayRate, until: until), shouldNotify: true)
        } else {
            let nextOffPeak = rates
                .filter { $0.valueIncVat <= threshold && $0.validFrom > now }
                .map(\.validFrom)
                .min()
            let nextDispatch = dispatches
                .filter { $0.startDt > now }
                .map(\.startDt)
                .min()
            let next = [nextOffPeak, nextDispatch].compactMap { $0 }.min()
            return .standard(.standard(rate: current.valueIncVat, nextCheap: next))
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

    private func updateDerivedState() {
        var d = DisplayState()
        d.isCheap = state.isCheap
        d.compactMode = compactMode

        if let r = state.rate {
            let rounded = (r * 10).rounded() / 10
            d.priceLabel = rounded == rounded.rounded()
                ? String(format: "%.0fp/kWh", rounded)
                : String(format: "%.1fp/kWh", rounded)
            d.rateDetail = String(format: "%.2fp/kWh", r)
        }

        switch state {
        case .cheap:          d.statusText = "✅ Cheap Intelligent Go Active"
        case .standard:       d.statusText = "Standard Rate"
        case .unknown:        d.statusText = "Loading…"
        case .error(let msg): d.statusText = "⚠ \(msg)"
        }

        switch state {
        case .cheap(_, let until):   d.timingLabel = until.map { "Cheap until \(hhmm($0))" } ?? ""
        case .standard(_, let next): d.timingLabel = next.map { "Next cheap at \(hhmm($0))" } ?? ""
        default:                     d.timingLabel = ""
        }

        d.lastUpdatedLabel = "Updated \(Date().formatted(.relative(presentation: .named)))"

        // Build schedule from dispatch slots (today/tonight only, sorted by start)
        let now = Date()
        let fmt = Self.hhmmFormatter
        d.schedule = dispatches
            .filter { $0.endDt > now }
            .sorted { $0.startDt < $1.startDt }
            .map { slot in
                ScheduleSlot(
                    id: slot.startDt,
                    timeRange: "\(fmt.string(from: slot.startDt)) – \(fmt.string(from: slot.endDt))",
                    isActive: slot.startDt <= now && slot.endDt > now
                )
            }

        // Carry over flash state (managed separately by startFlashing)
        d.isFlashing = display.isFlashing
        d.flashShowCheap = display.flashShowCheap

        // Detect cheap/standard transition and trigger flash
        if let prev = previousIsCheap, prev != d.isCheap {
            startFlashing(newIsCheap: d.isCheap)
        }
        previousIsCheap = d.isCheap

        // Only fire objectWillChange if something actually changed
        if d != display { display = d }
    }

    func testFlash() {
        startFlashing(newIsCheap: !display.isCheap)
    }

    private func startFlashing(newIsCheap: Bool) {
        flashTask?.cancel()
        flashTask = Task { [weak self] in
            // 16 toggles × 250ms = 4 seconds
            for i in 0..<16 {
                guard !Task.isCancelled else { return }
                self?.display.isFlashing = true
                self?.display.flashShowCheap = (i % 2 == 0) ? !newIsCheap : newIsCheap
                try? await Task.sleep(for: .milliseconds(250))
            }
            self?.display.isFlashing = false
        }
    }

    private static let hhmmFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private func hhmm(_ date: Date) -> String {
        Self.hhmmFormatter.string(from: date)
    }
}
