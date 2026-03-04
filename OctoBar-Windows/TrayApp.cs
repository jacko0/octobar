// File: TrayApp.cs
// Windows system-tray host — equivalent to OctoBarApp (the SwiftUI MenuBarExtra scene).
// Manages the NotifyIcon, popup panel, settings window, and notifications.

using System;
using System.Drawing;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace OctoBar
{
    public class TrayApp : ApplicationContext
    {
        private readonly NotifyIcon     _trayIcon;
        private readonly TariffMonitor  _monitor;
        private readonly SynchronizationContext _uiCtx;

        private PopupForm?    _popup;
        private SettingsForm? _settingsForm;

        public TrayApp()
        {
            // Capture the WinForms UI synchronisation context so background events
            // can marshal back safely (mirrors @MainActor in the Swift original).
            _uiCtx = SynchronizationContext.Current
                     ?? throw new InvalidOperationException("No SynchronizationContext found.");

            _monitor = new TariffMonitor();
            _monitor.NotifyAction    = ShowBalloon;
            _monitor.DisplayChanged += (_, _) => _uiCtx.Post(_ => UpdateTrayIcon(), null);

            _trayIcon = new NotifyIcon
            {
                Visible     = true,
                Text        = "OctoBar",
                Icon        = CreateBoltIcon(isCheap: false),
                ContextMenuStrip = BuildContextMenu(),
            };
            _trayIcon.MouseClick += OnTrayMouseClick;
        }

        // MARK: - Context menu (right-click)

        private ContextMenuStrip BuildContextMenu()
        {
            var menu = new ContextMenuStrip();
            menu.Items.Add("Refresh",   null, (_, _) => _ = _monitor.RefreshAsync());
            menu.Items.Add("Settings\u2026", null, (_, _) => ShowSettings());
            menu.Items.Add(new ToolStripSeparator());
            menu.Items.Add("Quit", null, (_, _) => ExitThread());
            return menu;
        }

        // MARK: - Tray icon

        private void UpdateTrayIcon()
        {
            var display = _monitor.Display;

            var oldIcon = _trayIcon.Icon;
            _trayIcon.Icon = CreateBoltIcon(display.IsCheap);
            oldIcon?.Dispose();

            _trayIcon.Text = $"OctoBar  {display.PriceLabel}";

            _popup?.UpdateDisplay(display);
        }

        // MARK: - Left-click: toggle popup

        private void OnTrayMouseClick(object? sender, MouseEventArgs e)
        {
            if (e.Button == MouseButtons.Left)
                TogglePopup();
        }

        private void TogglePopup()
        {
            if (_popup != null && !_popup.IsDisposed && _popup.Visible)
            {
                _popup.Hide();
                return;
            }

            if (_popup == null || _popup.IsDisposed)
            {
                _popup = new PopupForm(_monitor);
                _popup.RefreshClicked  += (_, _) => _ = _monitor.RefreshAsync();
                _popup.SettingsClicked += (_, _) => ShowSettings();
                _popup.QuitClicked     += (_, _) => ExitThread();
            }

            PositionAndShowPopup();
        }

        private void PositionAndShowPopup()
        {
            if (_popup == null) return;

            _popup.UpdateDisplay(_monitor.Display);

            // Position near the bottom-right corner (system tray area)
            var workArea   = Screen.PrimaryScreen!.WorkingArea;
            var popupSize  = _popup.Size;
            var x = workArea.Right  - popupSize.Width  - 4;
            var y = workArea.Bottom - popupSize.Height - 4;

            _popup.Location = new Point(x, y);
            _popup.Show();
            _popup.Activate();
        }

        // MARK: - Settings window

        private void ShowSettings()
        {
            _popup?.Hide();

            if (_settingsForm == null || _settingsForm.IsDisposed)
            {
                _settingsForm = new SettingsForm(_monitor);
                _settingsForm.FormClosed += (_, _) => _settingsForm = null;
            }

            _settingsForm.Show();
            _settingsForm.BringToFront();
        }

        // MARK: - Balloon notification (replaces UNUserNotificationCenter)

        private void ShowBalloon(string title, string body)
            => _uiCtx.Post(_ =>
                _trayIcon.ShowBalloonTip(6000, title, body, ToolTipIcon.Info), null);

        // MARK: - Icon rendering
        // Draws a coloured lightning-bolt polygon into a 16×16 bitmap,
        // replicating the macOS NSImage bolt rendering.

        private static Icon CreateBoltIcon(bool isCheap)
        {
            const int size = 16;
            using var bmp = new Bitmap(size, size, System.Drawing.Imaging.PixelFormat.Format32bppArgb);
            using var g   = Graphics.FromImage(bmp);
            g.Clear(Color.Transparent);
            g.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;

            var color = isCheap
                ? Color.FromArgb(52, 199, 89)   // systemGreen
                : Color.FromArgb(255, 149, 0);  // systemOrange

            using var brush = new SolidBrush(color);

            // Simple lightning-bolt shape (two triangles forming a zig-zag)
            var bolt = new PointF[]
            {
                new(9.5f, 1f),
                new(4f,   8.5f),
                new(8f,   8.5f),
                new(6.5f, 15f),
                new(12f,  7f),
                new(8f,   7f),
            };
            g.FillPolygon(brush, bolt);

            var hIcon = bmp.GetHicon();
            return Icon.FromHandle(hIcon);
        }

        // MARK: - Cleanup

        protected override void Dispose(bool disposing)
        {
            if (disposing)
            {
                _trayIcon.Visible = false;
                _trayIcon.Dispose();
                _popup?.Dispose();
                _settingsForm?.Dispose();
            }
            base.Dispose(disposing);
        }
    }
}
