// File: Program.cs
// Entry point for OctoBar Windows — equivalent to the @main OctoBarApp Swift struct.

using System;
using System.Windows.Forms;

namespace OctoBar
{
    internal static class Program
    {
        [STAThread]
        static void Main()
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.SetHighDpiMode(HighDpiMode.SystemAware);
            Application.Run(new TrayApp());
        }
    }
}
