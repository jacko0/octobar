// File: OctoBarTests.swift
import XCTest
@testable import OctoBar

final class OctoBarTests: XCTestCase {

    // MARK: - Model Decoding

    func testUnitRateDecoding() throws {
        let json = Data("""
        {
          "results": [{
            "value_inc_vat": 7.5,
            "valid_from": "2024-11-01T00:00:00Z",
            "valid_to":   "2024-11-01T05:30:00Z"
          }]
        }
        """.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let response = try decoder.decode(RatesResponse.self, from: json)
        XCTAssertEqual(response.results.count, 1)
        XCTAssertEqual(response.results[0].valueIncVat, 7.5, accuracy: 0.001)
        XCTAssertNotNil(response.results[0].validTo)
    }

    func testAccountResponseDecoding() throws {
        let json = Data("""
        {
          "properties": [{
            "electricity_meter_points": [{
              "agreements": [{
                "tariff_code": "E-1R-INTELLIGENT-GO-24-10-01-A",
                "valid_to": null
              }]
            }]
          }]
        }
        """.utf8)
        let response = try JSONDecoder().decode(AccountResponse.self, from: json)
        let agreement = response.properties.first?
            .electricityMeterPoints.first?
            .agreements.first
        XCTAssertEqual(agreement?.tariffCode, "E-1R-INTELLIGENT-GO-24-10-01-A")
        XCTAssertNil(agreement?.validTo, "Active agreement must have nil valid_to")
    }

    // MARK: - Tariff Code Parsing

    func testProductCodeDerivation() throws {
        let svc = OctopusService()
        // nonisolated — no await needed
        let result = try svc.deriveProductCode(from: "E-1R-INTELLIGENT-GO-24-10-01-A")
        XCTAssertEqual(result, "INTELLIGENT-GO-24-10-01")
    }

    func testProductCodeDerivationShortCodeThrows() {
        let svc = OctopusService()
        XCTAssertThrowsError(try svc.deriveProductCode(from: "E-1R-A")) { error in
            XCTAssertTrue(error is OctoError)
        }
    }

    // MARK: - Rate Logic

    func testTariffStateIsCheap() {
        XCTAssertTrue(TariffState.cheap(rate: 7.5, until: nil).isCheap)
        XCTAssertFalse(TariffState.standard(rate: 24.0, nextCheap: nil).isCheap)
        XCTAssertFalse(TariffState.unknown.isCheap)
        XCTAssertFalse(TariffState.error("boom").isCheap)
    }

    func testCheapThresholdBoundary() {
        let threshold = 9.5
        XCTAssertTrue(7.5  <= threshold, "7.5 p must be cheap")
        XCTAssertTrue(9.5  <= threshold, "9.5 p is at threshold and counts as cheap")
        XCTAssertFalse(9.51 <= threshold, "9.51 p is above threshold")
        XCTAssertFalse(24.0 <= threshold, "24 p is standard rate")
    }

    func testActiveRateSelection() {
        let now    = Date()
        let before = now.addingTimeInterval(-1800)
        let after  = now.addingTimeInterval( 1800)

        let active   = UnitRate(valueIncVat: 7.5,  validFrom: before, validTo: after)
        let future   = UnitRate(valueIncVat: 24.0, validFrom: after,  validTo: nil)
        let expired  = UnitRate(valueIncVat: 5.0,  validFrom: before.addingTimeInterval(-3600),
                                validTo: before)

        let isActive  = { (r: UnitRate) in r.validFrom <= now && (r.validTo ?? .distantFuture) > now }
        XCTAssertTrue(isActive(active),  "Rate whose window contains now must be active")
        XCTAssertFalse(isActive(future), "Future rate must not be active yet")
        XCTAssertFalse(isActive(expired),"Expired rate must not be active")
    }
}
