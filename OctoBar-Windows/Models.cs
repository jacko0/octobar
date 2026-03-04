// File: Models.cs
// Data models matching the Octopus Energy API responses and app state.

using System;
using System.Collections.Generic;
using System.Text.Json.Serialization;

namespace OctoBar
{
    // MARK: - Account API

    public class AccountResponse
    {
        [JsonPropertyName("properties")]
        public List<OctoProperty> Properties { get; set; } = new();
    }

    public class OctoProperty
    {
        [JsonPropertyName("electricity_meter_points")]
        public List<MeterPoint> ElectricityMeterPoints { get; set; } = new();
    }

    public class MeterPoint
    {
        [JsonPropertyName("agreements")]
        public List<Agreement> Agreements { get; set; } = new();
    }

    public class Agreement
    {
        [JsonPropertyName("tariff_code")]
        public string TariffCode { get; set; } = "";

        // null means the agreement is currently active
        [JsonPropertyName("valid_to")]
        public string? ValidTo { get; set; }
    }

    // MARK: - Rates API

    public class RatesResponse
    {
        [JsonPropertyName("results")]
        public List<UnitRate> Results { get; set; } = new();
    }

    public class UnitRate
    {
        [JsonPropertyName("value_inc_vat")]
        public double ValueIncVat { get; set; }

        [JsonPropertyName("valid_from")]
        public DateTime ValidFrom { get; set; }

        [JsonPropertyName("valid_to")]
        public DateTime? ValidTo { get; set; }
    }

    // MARK: - GraphQL Token

    public class GraphQLTokenResponse
    {
        [JsonPropertyName("data")]
        public TokenData Data { get; set; } = new();

        public class TokenData
        {
            [JsonPropertyName("obtainKrakenToken")]
            public TokenResult ObtainKrakenToken { get; set; } = new();
        }

        public class TokenResult
        {
            [JsonPropertyName("token")]
            public string Token { get; set; } = "";
        }
    }

    // MARK: - GraphQL Dispatch

    public class GraphQLDispatchResponse
    {
        [JsonPropertyName("data")]
        public DispatchData Data { get; set; } = new();

        public class DispatchData
        {
            [JsonPropertyName("plannedDispatches")]
            public List<DispatchSlot> PlannedDispatches { get; set; } = new();
        }
    }

    public class DispatchSlot
    {
        [JsonPropertyName("startDt")]
        public DateTime StartDt { get; set; }

        [JsonPropertyName("endDt")]
        public DateTime EndDt { get; set; }
    }

    // MARK: - App State

    public enum TariffStateKind { Unknown, Cheap, Standard, Error }

    public class TariffState
    {
        public TariffStateKind Kind { get; init; } = TariffStateKind.Unknown;
        public double? Rate { get; init; }
        public DateTime? Until { get; init; }       // for Cheap: cheap until when
        public DateTime? NextCheap { get; init; }   // for Standard: next cheap window
        public string? ErrorMessage { get; init; }

        public bool IsCheap => Kind == TariffStateKind.Cheap;

        public static TariffState Unknown() => new() { Kind = TariffStateKind.Unknown };
        public static TariffState Cheap(double rate, DateTime? until) =>
            new() { Kind = TariffStateKind.Cheap, Rate = rate, Until = until };
        public static TariffState Standard(double rate, DateTime? nextCheap) =>
            new() { Kind = TariffStateKind.Standard, Rate = rate, NextCheap = nextCheap };
        public static TariffState Error(string msg) =>
            new() { Kind = TariffStateKind.Error, ErrorMessage = msg };
    }

    // MARK: - Display

    public class ScheduleSlot
    {
        public DateTime Id { get; set; }
        public string TimeRange { get; set; } = "";
        public bool IsActive { get; set; }
    }

    public class DisplayState
    {
        public bool IsCheap { get; set; }
        public string PriceLabel { get; set; } = "\u2014p/kWh";
        public string RateDetail { get; set; } = "";
        public string StatusText { get; set; } = "Loading\u2026";
        public string TimingLabel { get; set; } = "";
        public string LastUpdatedLabel { get; set; } = "";
        public List<ScheduleSlot> Schedule { get; set; } = new();
    }

    // MARK: - Persisted Settings

    public class AppSettings
    {
        public string ApiKey { get; set; } = "";
        public string AccountNumber { get; set; } = "";
        public double CheapThreshold { get; set; } = 9.5;
        public bool NotificationsEnabled { get; set; }
    }
}
