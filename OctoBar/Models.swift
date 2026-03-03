// File: Models.swift
import Foundation

// MARK: - Account API

struct AccountResponse: Decodable {
    let properties: [OctoProperty]
}

struct OctoProperty: Decodable {
    let electricityMeterPoints: [MeterPoint]
    enum CodingKeys: String, CodingKey {
        case electricityMeterPoints = "electricity_meter_points"
    }
}

struct MeterPoint: Decodable {
    let agreements: [Agreement]
}

struct Agreement: Decodable {
    let tariffCode: String
    let validTo: String?        // nil means the agreement is currently active
    enum CodingKeys: String, CodingKey {
        case tariffCode = "tariff_code"
        case validTo    = "valid_to"
    }
}

// MARK: - Rates API

struct RatesResponse: Decodable {
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
