// File: SettingsForm.cs
// Settings window — opened via the "Settings…" button in the popup.
// Equivalent to the SwiftUI SettingsView.

using System;
using System.Drawing;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace OctoBar
{
    public class SettingsForm : Form
    {
        private readonly TariffMonitor _monitor;

        private readonly TextBox       _apiKeyBox;
        private readonly TextBox       _accountBox;
        private readonly NumericUpDown _thresholdBox;
        private readonly CheckBox      _notifyCheck;
        private readonly Button        _saveBtn;
        private readonly Label         _savedLabel;

        public SettingsForm(TariffMonitor monitor)
        {
            _monitor = monitor;

            Text            = "OctoBar Settings";
            ClientSize      = new Size(360, 310);
            FormBorderStyle = FormBorderStyle.FixedDialog;
            MaximizeBox     = false;
            MinimizeBox     = false;
            StartPosition   = FormStartPosition.CenterScreen;

            int y   = 16;
            int lx  = 16;
            int fx  = 150;
            int fw  = 180;

            // ── Octopus API Credentials ────────────────────────────────
            AddSectionHeader("Octopus API Credentials", lx, ref y);

            AddLabel("API Key:", lx, y);

            _apiKeyBox = new TextBox
            {
                Location     = new Point(fx, y),
                Width        = fw - 55,
                PasswordChar = '\u25cf',
            };
            Controls.Add(_apiKeyBox);

            var revealBtn = new Button
            {
                Text     = "Show",
                Location = new Point(fx + _apiKeyBox.Width + 4, y - 1),
                Width    = 50,
                Height   = _apiKeyBox.Height + 2,
            };
            revealBtn.Click += (_, _) =>
            {
                var revealed = _apiKeyBox.PasswordChar == '\0';
                _apiKeyBox.PasswordChar = revealed ? '\u25cf' : '\0';
                revealBtn.Text          = revealed ? "Show" : "Hide";
            };
            Controls.Add(revealBtn);
            y += _apiKeyBox.Height + 8;

            AddLabel("Account Number:", lx, y);
            _accountBox = new TextBox
            {
                Location         = new Point(fx, y),
                Width            = fw,
                PlaceholderText  = "A-AAAA1111",
            };
            Controls.Add(_accountBox);
            y += _accountBox.Height + 16;

            // ── Cheap-Rate Threshold ───────────────────────────────────
            AddSectionHeader("Cheap-Rate Threshold", lx, ref y);

            AddLabel("Cheap rate \u2264", lx, y);
            _thresholdBox = new NumericUpDown
            {
                Location     = new Point(fx, y),
                Width        = 65,
                Minimum      = 1,
                Maximum      = 100,
                DecimalPlaces = 1,
                Increment    = 0.5m,
                Value        = 9.5m,
            };
            Controls.Add(_thresholdBox);

            var pLabel = new Label
            {
                Text     = "p/kWh",
                Location = new Point(fx + 69, y + 3),
                AutoSize = true,
            };
            Controls.Add(pLabel);
            y += _thresholdBox.Height + 4;

            var caption = new Label
            {
                Text      = "Default: 9.5 p/kWh (Intelligent Go off-peak rate)",
                Location  = new Point(lx, y),
                ForeColor = SystemColors.GrayText,
                Font      = new Font(Font.FontFamily, 8),
                AutoSize  = true,
            };
            Controls.Add(caption);
            y += caption.PreferredHeight + 16;

            // ── Notifications ──────────────────────────────────────────
            AddSectionHeader("Notifications", lx, ref y);

            _notifyCheck = new CheckBox
            {
                Text     = "Alert when cheap rate starts",
                Location = new Point(lx, y),
                AutoSize = true,
            };
            Controls.Add(_notifyCheck);
            y += _notifyCheck.Height + 20;

            // ── Buttons ────────────────────────────────────────────────
            _savedLabel = new Label
            {
                Text      = "Saved",
                ForeColor = Color.Green,
                Location  = new Point(lx, y + 4),
                AutoSize  = true,
                Visible   = false,
            };
            Controls.Add(_savedLabel);

            _saveBtn = new Button
            {
                Text     = "Save",
                Location = new Point(ClientSize.Width - 95, y),
                Width    = 80,
            };
            _saveBtn.Click += OnSaveClick;
            Controls.Add(_saveBtn);
            y += _saveBtn.Height + 16;

            // ── Footer ─────────────────────────────────────────────────
            var footer = new Label
            {
                Text      = "S.Jackson 2026",
                ForeColor = SystemColors.GrayText,
                Font      = new Font(Font.FontFamily, 8),
                Location  = new Point(0, ClientSize.Height - 24),
                Size      = new Size(ClientSize.Width, 20),
                TextAlign = ContentAlignment.MiddleCenter,
            };
            Controls.Add(footer);

            // Populate fields from current monitor state
            _apiKeyBox.Text    = _monitor.ApiKey;
            _accountBox.Text   = _monitor.AccountNumber;
            _thresholdBox.Value = (decimal)Math.Clamp(_monitor.CheapThreshold, 1, 100);
            _notifyCheck.Checked = _monitor.NotificationsEnabled;
        }

        // MARK: - Helpers

        private void AddSectionHeader(string text, int x, ref int y)
        {
            var label = new Label
            {
                Text      = text,
                Location  = new Point(x, y),
                Font      = new Font(Font.FontFamily, 9, FontStyle.Bold),
                AutoSize  = true,
            };
            Controls.Add(label);
            y += label.PreferredHeight + 6;
        }

        private void AddLabel(string text, int x, int y)
        {
            var label = new Label
            {
                Text     = text,
                Location = new Point(x, y + 3),
                AutoSize = true,
            };
            Controls.Add(label);
        }

        // MARK: - Save

        private async void OnSaveClick(object? sender, EventArgs e)
        {
            _monitor.ApiKey               = _apiKeyBox.Text.Trim();
            _monitor.AccountNumber        = _accountBox.Text.Trim();
            _monitor.CheapThreshold       = (double)_thresholdBox.Value;
            _monitor.NotificationsEnabled = _notifyCheck.Checked;
            _monitor.SaveSettings();

            _savedLabel.Visible = true;
            _saveBtn.Enabled    = false;

            await _monitor.RefreshAsync();
            Close();
        }
    }
}
