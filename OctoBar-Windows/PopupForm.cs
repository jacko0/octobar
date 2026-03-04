// File: PopupForm.cs
// The drop-down panel shown when the user left-clicks the tray icon.
// Equivalent to the SwiftUI MenuContentView popup.

using System;
using System.Drawing;
using System.Linq;
using System.Windows.Forms;

namespace OctoBar
{
    public class PopupForm : Form
    {
        public event EventHandler? RefreshClicked;
        public event EventHandler? SettingsClicked;
        public event EventHandler? QuitClicked;

        private readonly Label _rateLabel;
        private readonly Label _statusLabel;
        private readonly Label _timingLabel;
        private readonly Label _updatedLabel;
        private readonly Label _scheduleTitleLabel;
        private readonly FlowLayoutPanel _schedulePanel;

        private static readonly Color BgColor   = Color.FromArgb(38, 38, 38);
        private static readonly Color FgColor   = Color.FromArgb(240, 240, 240);
        private static readonly Color DimColor  = Color.FromArgb(140, 140, 140);
        private static readonly Color GreenColor = Color.FromArgb(52, 199, 89);

        public PopupForm(TariffMonitor monitor)
        {
            // Window setup — borderless, always-on-top, hidden from taskbar
            Text            = "OctoBar";
            FormBorderStyle = FormBorderStyle.None;
            TopMost         = true;
            ShowInTaskbar   = false;
            BackColor       = BgColor;
            ForeColor       = FgColor;
            Padding         = new Padding(14);
            AutoSize        = true;
            AutoSizeMode    = AutoSizeMode.GrowAndShrink;

            // Hide when the window loses focus
            Deactivate += (_, _) => Hide();

            var layout = new FlowLayoutPanel
            {
                Dock          = DockStyle.Fill,
                FlowDirection = FlowDirection.TopDown,
                WrapContents  = false,
                AutoSize      = true,
                AutoSizeMode  = AutoSizeMode.GrowAndShrink,
                BackColor     = BgColor,
            };
            Controls.Add(layout);

            // ── Header ──────────────────────────────────────────────────
            var header = new Label
            {
                Text      = "OctoBar",
                Font      = new Font("Segoe UI", 11, FontStyle.Bold),
                ForeColor = FgColor,
                AutoSize  = true,
                Margin    = new Padding(0, 0, 0, 8),
            };
            layout.Controls.Add(header);

            // ── Rate detail ─────────────────────────────────────────────
            _rateLabel = MakeLabel("", "Consolas", 10, FontStyle.Bold);
            _rateLabel.Margin = new Padding(0, 0, 0, 2);
            layout.Controls.Add(_rateLabel);

            // ── Status text ─────────────────────────────────────────────
            _statusLabel = MakeLabel("Loading\u2026", "Segoe UI", 9);
            layout.Controls.Add(_statusLabel);

            // ── Timing label ─────────────────────────────────────────────
            _timingLabel = MakeLabel("", "Segoe UI", 9);
            _timingLabel.ForeColor = DimColor;
            _timingLabel.Margin    = new Padding(0, 0, 0, 6);
            layout.Controls.Add(_timingLabel);

            // ── Tariff schedule ──────────────────────────────────────────
            _scheduleTitleLabel = MakeLabel("Tariff Schedule", "Segoe UI", 8, FontStyle.Bold);
            _scheduleTitleLabel.ForeColor = DimColor;
            _scheduleTitleLabel.Visible   = false;
            _scheduleTitleLabel.Margin    = new Padding(0, 4, 0, 2);
            layout.Controls.Add(_scheduleTitleLabel);

            _schedulePanel = new FlowLayoutPanel
            {
                FlowDirection = FlowDirection.TopDown,
                WrapContents  = false,
                AutoSize      = true,
                AutoSizeMode  = AutoSizeMode.GrowAndShrink,
                BackColor     = BgColor,
                Visible       = false,
                Margin        = new Padding(0, 0, 0, 6),
            };
            layout.Controls.Add(_schedulePanel);

            // ── Last-updated label ────────────────────────────────────────
            _updatedLabel = MakeLabel("", "Segoe UI", 8);
            _updatedLabel.ForeColor = Color.FromArgb(100, 100, 100);
            _updatedLabel.Margin    = new Padding(0, 4, 0, 4);
            layout.Controls.Add(_updatedLabel);

            // ── Button bar ────────────────────────────────────────────────
            var buttonBar = new FlowLayoutPanel
            {
                FlowDirection = FlowDirection.LeftToRight,
                WrapContents  = false,
                AutoSize      = true,
                AutoSizeMode  = AutoSizeMode.GrowAndShrink,
                BackColor     = BgColor,
                Margin        = new Padding(0, 4, 0, 0),
            };

            var refreshBtn  = MakeButton("Refresh");
            var settingsBtn = MakeButton("Settings\u2026");
            var quitBtn     = MakeButton("Quit");

            refreshBtn.Click  += (s, e) => RefreshClicked?.Invoke(s, e);
            settingsBtn.Click += (s, e) => SettingsClicked?.Invoke(s, e);
            quitBtn.Click     += (s, e) => QuitClicked?.Invoke(s, e);

            buttonBar.Controls.AddRange(new Control[] { refreshBtn, settingsBtn, quitBtn });
            layout.Controls.Add(buttonBar);

            // Populate with current state
            UpdateDisplay(monitor.Display);
        }

        // MARK: - Update

        public void UpdateDisplay(DisplayState display)
        {
            if (InvokeRequired) { Invoke(() => UpdateDisplay(display)); return; }

            _rateLabel.Text    = display.RateDetail;
            _rateLabel.Visible = !string.IsNullOrEmpty(display.RateDetail);

            _statusLabel.Text = display.StatusText;

            _timingLabel.Text    = display.TimingLabel;
            _timingLabel.Visible = !string.IsNullOrEmpty(display.TimingLabel);

            _updatedLabel.Text = display.LastUpdatedLabel;

            // Rebuild schedule rows
            _schedulePanel.Controls.Clear();
            if (display.Schedule.Any())
            {
                _scheduleTitleLabel.Visible = true;
                _schedulePanel.Visible      = true;

                foreach (var slot in display.Schedule)
                {
                    var row = new FlowLayoutPanel
                    {
                        FlowDirection = FlowDirection.LeftToRight,
                        WrapContents  = false,
                        AutoSize      = true,
                        AutoSizeMode  = AutoSizeMode.GrowAndShrink,
                        BackColor     = BgColor,
                        Margin        = new Padding(0, 1, 0, 1),
                    };

                    // Coloured dot
                    var dot = new Panel
                    {
                        Size      = new Size(7, 7),
                        BackColor = slot.IsActive ? GreenColor : Color.FromArgb(90, 90, 90),
                        Margin    = new Padding(0, 4, 5, 0),
                    };

                    var text = slot.TimeRange + (slot.IsActive ? "  now" : "");
                    var timeLabel = new Label
                    {
                        Text      = text,
                        Font      = new Font("Consolas", 8),
                        ForeColor = slot.IsActive ? GreenColor : DimColor,
                        AutoSize  = true,
                    };

                    row.Controls.Add(dot);
                    row.Controls.Add(timeLabel);
                    _schedulePanel.Controls.Add(row);
                }
            }
            else
            {
                _scheduleTitleLabel.Visible = false;
                _schedulePanel.Visible      = false;
            }
        }

        // MARK: - Helpers

        private static Label MakeLabel(string text, string fontFamily, float size,
            FontStyle style = FontStyle.Regular)
            => new()
            {
                Text      = text,
                Font      = new Font(fontFamily, size, style),
                ForeColor = FgColor,
                AutoSize  = true,
                BackColor = BgColor,
            };

        private static Button MakeButton(string text)
            => new()
            {
                Text      = text,
                FlatStyle = FlatStyle.Flat,
                BackColor = Color.FromArgb(65, 65, 65),
                ForeColor = FgColor,
                AutoSize  = true,
                Margin    = new Padding(0, 0, 5, 0),
                Padding   = new Padding(6, 3, 6, 3),
                FlatAppearance = { BorderColor = Color.FromArgb(90, 90, 90) },
                UseVisualStyleBackColor = false,
            };
    }
}
