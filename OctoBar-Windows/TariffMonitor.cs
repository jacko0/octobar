// File: TariffMonitor.cs
// Central model: owns settings, the poll loop, and published display state.
// Ported from the Swift TariffMonitor @MainActor class.

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;

namespace OctoBar
{
    public class TariffMonitor
    {
        // MARK: - State

        public DisplayState Display { get; private set; } = new();

        /// Fired on a background thread whenever Display changes — callers must marshal to UI thread.
        public event EventHandler? DisplayChanged;

        // MARK: - Settings

        public string ApiKey { get; set; } = "";
        public string AccountNumber { get; set; } = "";
        public double CheapThreshold { get; set; } = 9.5;
        public bool NotificationsEnabled { get; set; }

        public bool IsCheap    => Display.IsCheap;
        public string PriceLabel => Display.PriceLabel;

        // MARK: - Private

        private TariffState _state = TariffState.Unknown();
        private List<DispatchSlot> _dispatches = new();
        private bool _wasCheap;

        private CancellationTokenSource? _pollCts;
        private readonly OctopusService _service = new();

        /// Callback used by TrayApp to show a Windows balloon/toast notification.
        public Action<string, string>? NotifyAction;

        private static readonly string SettingsPath = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
            "OctoBar", "settings.json");

        // MARK: - Init

        public TariffMonitor()
        {
            LoadSettings();
            StartPolling();
        }

        // MARK: - Persistence

        public void LoadSettings()
        {
            try
            {
                if (!File.Exists(SettingsPath)) return;
                var json     = File.ReadAllText(SettingsPath);
                var settings = JsonSerializer.Deserialize<AppSettings>(json);
                if (settings is null) return;
                ApiKey               = settings.ApiKey;
                AccountNumber        = settings.AccountNumber;
                CheapThreshold       = settings.CheapThreshold > 0 ? settings.CheapThreshold : 9.5;
                NotificationsEnabled = settings.NotificationsEnabled;
            }
            catch { /* ignore settings errors on first run */ }
        }

        public void SaveSettings()
        {
            try
            {
                Directory.CreateDirectory(Path.GetDirectoryName(SettingsPath)!);
                var settings = new AppSettings
                {
                    ApiKey               = ApiKey,
                    AccountNumber        = AccountNumber,
                    CheapThreshold       = CheapThreshold,
                    NotificationsEnabled = NotificationsEnabled
                };
                var json = JsonSerializer.Serialize(settings, new JsonSerializerOptions { WriteIndented = true });
                File.WriteAllText(SettingsPath, json);
            }
            catch { /* ignore */ }
        }

        // MARK: - Polling

        public void StartPolling()
        {
            _pollCts?.Cancel();
            _pollCts = new CancellationTokenSource();
            var ct = _pollCts.Token;

            _ = Task.Run(async () =>
            {
                while (!ct.IsCancellationRequested)
                {
                    await RefreshAsync();
                    try { await Task.Delay(TimeSpan.FromMinutes(5), ct); }
                    catch (OperationCanceledException) { break; }
                }
            }, ct);
        }

        // MARK: - Refresh

        public async Task RefreshAsync()
        {
            if (string.IsNullOrWhiteSpace(ApiKey) || string.IsNullOrWhiteSpace(AccountNumber))
            {
                _state = TariffState.Error("Configure API key & account in Settings");
                UpdateDerivedState();
                return;
            }

            try
            {
                var ratesTask    = _service.FetchRates(ApiKey, AccountNumber);
                var dispatchTask = _service.FetchDispatchSlots(ApiKey, AccountNumber);

                var rates = await ratesTask;

                List<DispatchSlot> dispatches;
                try   { dispatches = await dispatchTask; }
                catch { dispatches = new List<DispatchSlot>(); }

                var result = ProcessRates(rates, dispatches, CheapThreshold);
                _dispatches = dispatches;

                switch (result.Kind)
                {
                    case RefreshResultKind.NoRate:
                        _state = TariffState.Error("No rate found for current time");
                        break;

                    case RefreshResultKind.Cheap:
                        if (!_wasCheap && NotificationsEnabled)
                            SendNotification();
                        _wasCheap = true;
                        _state    = result.State!;
                        break;

                    case RefreshResultKind.Standard:
                        _wasCheap = false;
                        _state    = result.State!;
                        break;
                }
            }
            catch (Exception ex)
            {
                _state = TariffState.Error(ex.Message);
            }

            UpdateDerivedState();
        }

        // MARK: - Off-thread processing (mirrors Swift's nonisolated static processRates)

        private enum RefreshResultKind { NoRate, Cheap, Standard }
        private record RefreshResult(RefreshResultKind Kind, TariffState? State = null);

        private static RefreshResult ProcessRates(
            List<UnitRate> rates, List<DispatchSlot> dispatches, double threshold)
        {
            var now     = DateTime.UtcNow;
            var current = rates.FirstOrDefault(
                r => r.ValidFrom <= now && (r.ValidTo ?? DateTime.MaxValue) > now);

            if (current is null) return new RefreshResult(RefreshResultKind.NoRate);

            var isCheapByRate     = current.ValueIncVat <= threshold;
            var activeDispatch    = dispatches.FirstOrDefault(d => d.StartDt <= now && d.EndDt > now);
            var isCheapByDispatch = activeDispatch is not null;
            var isCheapNow        = isCheapByRate || isCheapByDispatch;

            if (isCheapNow)
            {
                var until       = activeDispatch?.EndDt ?? current.ValidTo;
                var displayRate = isCheapByDispatch && !isCheapByRate
                    ? rates.Select(r => r.ValueIncVat).DefaultIfEmpty(current.ValueIncVat).Min()
                    : current.ValueIncVat;
                return new RefreshResult(RefreshResultKind.Cheap,
                    TariffState.Cheap(displayRate, until));
            }
            else
            {
                var nextOffPeak = rates
                    .Where(r => r.ValueIncVat <= threshold && r.ValidFrom > now)
                    .Select(r => (DateTime?)r.ValidFrom)
                    .DefaultIfEmpty(null)
                    .Min();

                var nextDispatch = dispatches
                    .Where(d => d.StartDt > now)
                    .Select(d => (DateTime?)d.StartDt)
                    .DefaultIfEmpty(null)
                    .Min();

                DateTime? next = (nextOffPeak, nextDispatch) switch
                {
                    (not null, not null) => nextOffPeak < nextDispatch ? nextOffPeak : nextDispatch,
                    (not null, null)     => nextOffPeak,
                    (null, not null)     => nextDispatch,
                    _                    => null
                };

                return new RefreshResult(RefreshResultKind.Standard,
                    TariffState.Standard(current.ValueIncVat, next));
            }
        }

        // MARK: - Notification

        private void SendNotification()
            => NotifyAction?.Invoke(
                "OctoBar \u2014 Cheap Rate Active",
                "Intelligent Go cheap window has started. Time to charge!");

        // MARK: - Helpers

        private void UpdateDerivedState()
        {
            var d = new DisplayState();
            d.IsCheap = _state.IsCheap;

            if (_state.Rate.HasValue)
            {
                var rounded = Math.Round(_state.Rate.Value * 10) / 10;
                d.PriceLabel = rounded == Math.Round(rounded)
                    ? $"{rounded:0}p/kWh"
                    : $"{rounded:0.0}p/kWh";
                d.RateDetail = $"{_state.Rate.Value:0.00}p/kWh";
            }

            d.StatusText = _state.Kind switch
            {
                TariffStateKind.Cheap    => "\u2705 Cheap Intelligent Go Active",
                TariffStateKind.Standard => "Standard Rate",
                TariffStateKind.Unknown  => "Loading\u2026",
                TariffStateKind.Error    => $"\u26a0 {_state.ErrorMessage}",
                _                        => "Loading\u2026"
            };

            d.TimingLabel = _state.Kind switch
            {
                TariffStateKind.Cheap    when _state.Until.HasValue =>
                    $"Cheap until {_state.Until.Value.ToLocalTime():HH:mm}",
                TariffStateKind.Standard when _state.NextCheap.HasValue =>
                    $"Next cheap at {_state.NextCheap.Value.ToLocalTime():HH:mm}",
                _ => ""
            };

            d.LastUpdatedLabel = $"Updated {DateTime.Now:HH:mm}";

            var now = DateTime.UtcNow;
            d.Schedule = _dispatches
                .Where(s => s.EndDt > now)
                .OrderBy(s => s.StartDt)
                .Select(s => new ScheduleSlot
                {
                    Id        = s.StartDt,
                    TimeRange = $"{s.StartDt.ToLocalTime():HH:mm} \u2013 {s.EndDt.ToLocalTime():HH:mm}",
                    IsActive  = s.StartDt <= now && s.EndDt > now
                })
                .ToList();

            Display = d;
            DisplayChanged?.Invoke(this, EventArgs.Empty);
        }
    }
}
