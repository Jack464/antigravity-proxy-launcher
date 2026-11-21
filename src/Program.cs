using System;
using System.Reflection;
using System.Windows.Forms;

namespace AntigravityProxyLauncher
{
    internal static class Program
    {
        internal const string ProductName = "Antigravity Proxy Launcher";
        internal static string Version
        {
            get { return Assembly.GetExecutingAssembly().GetName().Version.ToString(3); }
        }

        [STAThread]
        private static int Main(string[] args)
        {
            bool settings = args.Length == 1 && args[0] == "--settings";
            bool diagnose = args.Length == 1 && args[0] == "--diagnose";
            if (args.Length == 1 && args[0] == "--version")
            {
                Console.WriteLine(ProductName + " " + Version);
                return 0;
            }
            if (args.Length == 1 && (args[0] == "--help" || args[0] == "-h"))
            {
                Console.WriteLine(ProductName + " " + Version);
                Console.WriteLine("No arguments: first-run setup, or launch using saved settings.");
                Console.WriteLine("--settings   Open settings without launching Antigravity.");
                Console.WriteLine("--diagnose   Print local diagnostics; do not launch applications.");
                Console.WriteLine("--version    Print version.");
                Console.WriteLine("--help       Print this help.");
                return 0;
            }
            if (args.Length != 0 && !settings && !diagnose)
            {
                Console.Error.WriteLine("Unsupported arguments. Use --help for available options.");
                return 2;
            }

            if (diagnose)
            {
                try
                {
                    Console.WriteLine(LauncherEngine.Diagnose(ConfigStore.Load()));
                    return 0;
                }
                catch (Exception error)
                {
                    Console.Error.WriteLine("Diagnostics failed: " + error.Message);
                    return 1;
                }
            }

            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            try
            {
                if (settings || !ConfigStore.Exists)
                    return OpenSettings();

                LauncherEngine.Run(ConfigStore.Load());
                return 0;
            }
            catch (Exception error)
            {
                ConfigStore.Log("ERROR: " + error.Message);
                DialogResult answer = MessageBox.Show(
                    "启动失败 / Launch failed\r\n\r\n" + error.Message +
                    "\r\n\r\n日志 / Log: " + ConfigStore.LogPath +
                    "\r\n\r\n是否打开设置检查代理和应用路径？\r\nOpen settings to review the proxy and application paths?",
                    ProductName, MessageBoxButtons.YesNo, MessageBoxIcon.Error);
                if (answer == DialogResult.Yes)
                    return OpenSettings();
                return 1;
            }
        }

        private static int OpenSettings()
        {
            using (SettingsForm form = new SettingsForm())
                Application.Run(form);
            return 0;
        }
    }
}
