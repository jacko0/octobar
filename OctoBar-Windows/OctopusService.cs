// File: OctopusService.cs
// All Octopus Energy API communication, ported from the Swift actor OctopusService.

using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Threading.Tasks;

namespace OctoBar
{
    public class OctoError : Exception
    {
        public OctoError(string message) : base(message) { }

        public static OctoError NoActiveTariff =>
            new("No active electricity tariff found.");
        public static OctoError InvalidTariffCode(string code) =>
            new($"Cannot parse tariff code: {code}");
        public static OctoError HttpError(int code) =>
            new($"HTTP error {code}.");
    }

    public class OctopusService
    {
        private readonly HttpClient _client = new();

        private static readonly JsonSerializerOptions DefaultOptions = new()
        {
            PropertyNameCaseInsensitive = true
        };

        // MARK: - Public

        /// Fetches unit rates covering now ±38 h for the account's active tariff.
        public async Task<List<UnitRate>> FetchRates(string apiKey, string accountNumber)
        {
            var tariffCode = await FetchTariffCode(apiKey, accountNumber);
            var productCode = DeriveProductCode(tariffCode);
            return await FetchUnitRates(apiKey, productCode, tariffCode);
        }

        // MARK: - Step 1: Resolve active tariff code

        private async Task<string> FetchTariffCode(string apiKey, string accountNumber)
        {
            var url = $"https://api.octopus.energy/v1/accounts/{accountNumber}/";
            var json = await Fetch(url, apiKey);
            var response = JsonSerializer.Deserialize<AccountResponse>(json, DefaultOptions)
                ?? throw new Exception("Failed to parse account response");

            var code = response.Properties
                .SelectMany(p => p.ElectricityMeterPoints)
                .SelectMany(mp => mp.Agreements)
                .FirstOrDefault(a => a.ValidTo == null)?
                .TariffCode;

            return code ?? throw OctoError.NoActiveTariff;
        }

        // MARK: - Step 2: Derive product code
        // "E-1R-INTELLIGENT-GO-24-10-01-A" → "INTELLIGENT-GO-24-10-01"

        public static string DeriveProductCode(string tariffCode)
        {
            var parts = tariffCode.Split('-').ToList();
            if (parts.Count <= 3) throw OctoError.InvalidTariffCode(tariffCode);
            parts.RemoveAt(0); // remove "E"
            parts.RemoveAt(0); // remove "1R"
            parts.RemoveAt(parts.Count - 1); // remove region suffix "A"
            return string.Join("-", parts);
        }

        // MARK: - Step 3: Fetch unit rates

        private async Task<List<UnitRate>> FetchUnitRates(
            string apiKey, string productCode, string tariffCode)
        {
            var now = DateTime.UtcNow;
            var periodFrom = Uri.EscapeDataString(now.AddHours(-2).ToString("yyyy-MM-ddTHH:mm:ssZ"));
            var periodTo   = Uri.EscapeDataString(now.AddHours(36).ToString("yyyy-MM-ddTHH:mm:ssZ"));

            var url = $"https://api.octopus.energy/v1/products/{productCode}" +
                      $"/electricity-tariffs/{tariffCode}/standard-unit-rates/" +
                      $"?period_from={periodFrom}&period_to={periodTo}";

            var json = await Fetch(url, apiKey);
            var response = JsonSerializer.Deserialize<RatesResponse>(json, DefaultOptions)
                ?? throw new Exception("Failed to parse rates response");
            return response.Results;
        }

        // MARK: - Intelligent Go Dispatch Slots

        public async Task<List<DispatchSlot>> FetchDispatchSlots(
            string apiKey, string accountNumber)
        {
            var token = await ObtainGraphQLToken(apiKey);
            return await FetchPlannedDispatches(token, accountNumber);
        }

        private async Task<string> ObtainGraphQLToken(string apiKey)
        {
            var url   = "https://api.octopus.energy/v1/graphql/";
            var query = $"mutation {{ obtainKrakenToken(input: {{ APIKey: \"{apiKey}\" }}) {{ token }} }}";
            var body  = JsonSerializer.Serialize(new { query });

            var request = new HttpRequestMessage(HttpMethod.Post, url);
            request.Content = new StringContent(body, Encoding.UTF8, "application/json");

            var response = await _client.SendAsync(request);
            if (!response.IsSuccessStatusCode)
                throw OctoError.HttpError((int)response.StatusCode);

            var json   = await response.Content.ReadAsStringAsync();
            var result = JsonSerializer.Deserialize<GraphQLTokenResponse>(json, DefaultOptions)
                ?? throw new Exception("Failed to parse token response");
            return result.Data.ObtainKrakenToken.Token;
        }

        private async Task<List<DispatchSlot>> FetchPlannedDispatches(
            string token, string accountNumber)
        {
            var url   = "https://api.octopus.energy/v1/graphql/";
            var query = $"query {{ plannedDispatches(accountNumber: \"{accountNumber}\") {{ startDt endDt }} }}";
            var body  = JsonSerializer.Serialize(new { query });

            var request = new HttpRequestMessage(HttpMethod.Post, url);
            request.Content = new StringContent(body, Encoding.UTF8, "application/json");
            request.Headers.Authorization = new AuthenticationHeaderValue(token);

            var response = await _client.SendAsync(request);
            if (!response.IsSuccessStatusCode)
                throw OctoError.HttpError((int)response.StatusCode);

            var json = await response.Content.ReadAsStringAsync();

            // Dispatch slots use a custom date format: "yyyy-MM-dd HH:mm:sszzz"
            var options = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
            options.Converters.Add(new DispatchDateTimeConverter());

            var result = JsonSerializer.Deserialize<GraphQLDispatchResponse>(json, options)
                ?? throw new Exception("Failed to parse dispatch response");
            return result.Data.PlannedDispatches;
        }

        // MARK: - HTTP with exponential-backoff retry (3 attempts: wait 1 s, 2 s)

        private async Task<string> Fetch(string url, string apiKey, int attempt = 1)
        {
            try
            {
                var request = new HttpRequestMessage(HttpMethod.Get, url);
                var creds   = Convert.ToBase64String(Encoding.UTF8.GetBytes($"{apiKey}:"));
                request.Headers.Authorization = new AuthenticationHeaderValue("Basic", creds);

                var response = await _client.SendAsync(request);
                if (!response.IsSuccessStatusCode)
                    throw OctoError.HttpError((int)response.StatusCode);

                return await response.Content.ReadAsStringAsync();
            }
            catch when (attempt < 3)
            {
                var delayMs = (int)Math.Pow(2, attempt - 1) * 1000;
                await Task.Delay(delayMs);
                return await Fetch(url, apiKey, attempt + 1);
            }
        }
    }

    /// Custom converter for Octopus dispatch date format: "yyyy-MM-dd HH:mm:sszzz"
    public class DispatchDateTimeConverter : JsonConverter<DateTime>
    {
        public override DateTime Read(
            ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
        {
            var str = reader.GetString() ?? "";
            if (DateTimeOffset.TryParseExact(
                    str, "yyyy-MM-dd HH:mm:sszzz",
                    System.Globalization.CultureInfo.InvariantCulture,
                    System.Globalization.DateTimeStyles.None,
                    out var dto))
                return dto.UtcDateTime;

            return DateTime.Parse(str, null,
                System.Globalization.DateTimeStyles.RoundtripKind);
        }

        public override void Write(
            Utf8JsonWriter writer, DateTime value, JsonSerializerOptions options)
            => writer.WriteStringValue(value.ToString("yyyy-MM-dd HH:mm:sszzz"));
    }
}
