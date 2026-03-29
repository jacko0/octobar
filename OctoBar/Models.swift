// File: Models.swift
import Foundation

// MARK: - Account API

nonisolated struct AccountResponse: Decodable, Sendable {
    let properties: [OctoProperty]
}

nonisolated struct OctoProperty: Decodable, Sendable {
    let electricityMeterPoints: [MeterPoint]
    enum CodingKeys: String, CodingKey {
        case electricityMeterPoints = "electricity_meter_points"
    }
}

nonisolated struct MeterPoint: Decodable, Sendable {
    let agreements: [Agreement]
}

nonisolated struct Agreement: Decodable, Sendable {
    let tariffCode: String
    let validTo: String?        // nil means the agreement is currently active
    enum CodingKeys: String, CodingKey {
        case tariffCode = "tariff_code"
        case validTo    = "valid_to"
    }
}

// MARK: - Rates API

nonisolated struct RatesResponse: Decodable, Sendable {
    let results: [UnitRate]
}

struct UnitRate: Decodable, Sendable {
    let valueIncVat: Double
    let validFrom:   Date
    let validTo:     Date?
    enum CodingKeys: String, CodingKey {
        case valueIncVat = "value_inc_vat"
        case validFrom   = "valid_from"
        case validTo     = "valid_to"
    }
}

// MARK: - Intelligent Dispatch GraphQL API

nonisolated struct GraphQLTokenResponse: Decodable, Sendable {
    let data: TokenData
    struct TokenData: Decodable, Sendable {
        let obtainKrakenToken: TokenResult
    }
    struct TokenResult: Decodable, Sendable {
        let token: String
    }
}

nonisolated struct GraphQLDispatchResponse: Decodable, Sendable {
    let data: DispatchData
    struct DispatchData: Decodable, Sendable {
        let plannedDispatches: [DispatchSlot]
    }
}

struct DispatchSlot: Decodable, Sendable {
    let startDt: Date
    let endDt: Date
}

// MARK: - App State

enum TariffState: Equatable, Sendable {
    case unknown
    case cheap(rate: Double, until: Date?)
    case standard(rate: Double, nextCheap: Date?)
    case error(String)

    var isCheap: Bool {
        guard case .cheap = self else { return false }
        return true
    }

    var rate: Double? {
        switch self {
        case .cheap(let r, _):    return r
        case .standard(let r, _): return r
        default:                  return nil
        }
    }
}

// MARK: - Schedule Slot (pre-formatted for display)

struct ScheduleSlot: Equatable, Identifiable {
    let id: Date
    let timeRange: String   // e.g. "23:30 – 00:30"
    let isActive: Bool
}

// MARK: - Pre-computed Display State (single @Published to minimize objectWillChange)

struct DisplayState: Equatable {
    var isCheap: Bool = false
    var priceLabel: String = "—p/kWh"
    var rateDetail: String = ""
    var statusText: String = "Loading…"
    var timingLabel: String = ""
    var lastUpdatedLabel: String = ""
    var schedule: [ScheduleSlot] = []
    var compactMode: Bool = false
    var isFlashing: Bool = false
    var flashShowCheap: Bool = false
}
