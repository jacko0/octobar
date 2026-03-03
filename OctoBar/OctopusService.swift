// File: OctopusService.swift
import Foundation

/// All Octopus Energy API communication. Swift actor ensures thread safety.
actor OctopusService {
    private let session: URLSession

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.timeZone = TimeZone(identifier: "Europe/London")!
        return f
    }()

    private static let ratesDecoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private static let plainDecoder = JSONDecoder()

    private static let dispatchDecoder: JSONDecoder = {
        let d = JSONDecoder()
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ssxxx"
        f.locale = Locale(identifier: "en_US_POSIX")
        d.dateDecodingStrategy = .formatted(f)
        return d
    }()

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Public

    /// Fetches the array of unit rates covering now ± 38 h for the account's active tariff.
    func fetchRates(apiKey: String, accountNumber: String) async throws -> [UnitRate] {
        let tariffCode  = try await fetchTariffCode(apiKey: apiKey, accountNumber: accountNumber)
        let productCode = try deriveProductCode(from: tariffCode)
        return try await fetchUnitRates(apiKey: apiKey, productCode: productCode, tariffCode: tariffCode)
    }

    // MARK: - Step 1: Resolve active tariff code

    private func fetchTariffCode(apiKey: String, accountNumber: String) async throws -> String {
        let url  = URL(string: "https://api.octopus.energy/v1/accounts/\(accountNumber)/")!
        let data = try await fetch(url: url, apiKey: apiKey)
        let response = try Self.plainDecoder.decode(AccountResponse.self, from: data)
        guard let code = response.properties
            .flatMap({ $0.electricityMeterPoints })
            .flatMap({ $0.agreements })
            .first(where: { $0.validTo == nil })?
            .tariffCode
        else { throw OctoError.noActiveTariff }
        return code
    }

    // MARK: - Step 2: Derive product code

    /// "E-1R-INTELLIGENT-GO-24-10-01-A" → "INTELLIGENT-GO-24-10-01"
    /// Drops the fuel-type + register prefix and the regional suffix.
    nonisolated func deriveProductCode(from tariffCode: String) throws -> String {
        var parts = tariffCode.components(separatedBy: "-")
        guard parts.count > 3 else { throw OctoError.invalidTariffCode(tariffCode) }
        parts.removeFirst(2)    // remove "E", "1R"
        parts.removeLast()      // remove region "A"
        return parts.joined(separator: "-")
    }

    // MARK: - Step 3: Fetch unit rates

    private func fetchUnitRates(apiKey: String, productCode: String, tariffCode: String) async throws -> [UnitRate] {
        let now = Date()
        let fmt = Self.iso8601Formatter

        var comps = URLComponents(
            string: "https://api.octopus.energy/v1/products/\(productCode)" +
                    "/electricity-tariffs/\(tariffCode)/standard-unit-rates/"
        )!
        comps.queryItems = [
            URLQueryItem(name: "period_from", value: fmt.string(from: now.addingTimeInterval(-7_200))),
            URLQueryItem(name: "period_to",   value: fmt.string(from: now.addingTimeInterval(129_600)))
        ]

        let data = try await fetch(url: comps.url!, apiKey: apiKey)
        return try Self.ratesDecoder.decode(RatesResponse.self, from: data).results
    }

    // MARK: - Intelligent Go Dispatch Slots

    /// Fetches planned smart-charge dispatch slots via the Octopus GraphQL API.
    func fetchDispatchSlots(apiKey: String, accountNumber: String) async throws -> [DispatchSlot] {
        let token = try await obtainGraphQLToken(apiKey: apiKey)
        return try await fetchPlannedDispatches(token: token, accountNumber: accountNumber)
    }

    private func obtainGraphQLToken(apiKey: String) async throws -> String {
        let url = URL(string: "https://api.octopus.energy/v1/graphql/")!
        let query = """
        mutation { obtainKrakenToken(input: { APIKey: "\(apiKey)" }) { token } }
        """
        let body = try JSONSerialization.data(withJSONObject: ["query": query])

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode)
        else { throw OctoError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0) }

        let result = try Self.plainDecoder.decode(GraphQLTokenResponse.self, from: data)
        return result.data.obtainKrakenToken.token
    }

    private func fetchPlannedDispatches(token: String, accountNumber: String) async throws -> [DispatchSlot] {
        let url = URL(string: "https://api.octopus.energy/v1/graphql/")!
        let query = """
        query { plannedDispatches(accountNumber: "\(accountNumber)") { startDt endDt } }
        """
        let body = try JSONSerialization.data(withJSONObject: ["query": query])

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(token, forHTTPHeaderField: "Authorization")
        req.httpBody = body

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode)
        else { throw OctoError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0) }

        return try Self.dispatchDecoder.decode(GraphQLDispatchResponse.self, from: data).data.plannedDispatches
    }

    // MARK: - HTTP with exponential-backoff retry (3 attempts: wait 1 s, 2 s)

    private func fetch(url: URL, apiKey: String, attempt: Int = 1) async throws -> Data {
        var req = URLRequest(url: url)
        let creds = "\(apiKey):".data(using: .utf8)!.base64EncodedString()
        req.setValue("Basic \(creds)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await session.data(for: req)
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode)
            else {
                throw OctoError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
            }
            return data
        } catch {
            guard attempt < 3 else { throw error }
            // Exponential back-off: attempt 1→wait 1s, attempt 2→wait 2s
            let delay = UInt64(pow(2.0, Double(attempt - 1))) * 1_000_000_000
            try await Task.sleep(nanoseconds: delay)
            return try await fetch(url: url, apiKey: apiKey, attempt: attempt + 1)
        }
    }
}

// MARK: - Errors

enum OctoError: Error, LocalizedError {
    case noActiveTariff
    case invalidTariffCode(String)
    case httpError(Int)
    case missingCredentials

    var errorDescription: String? {
        switch self {
        case .noActiveTariff:           return "No active electricity tariff found."
        case .invalidTariffCode(let c): return "Cannot parse tariff code: \(c)"
        case .httpError(let code):      return "HTTP error \(code)."
        case .missingCredentials:       return "API key or account number not configured."
        }
    }
}
