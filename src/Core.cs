using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using Microsoft.Win32;

namespace AntigravityProxyLauncher
{
    public sealed class LauncherConfig
    {
        public bool UseProxy = true;
        public bool AutoDetectProxy = true;
        public string ProxyUrl = "http://127.0.0.1:10808";
        public string AntigravityPath = "";
        public string ProxyClientPath = "";
        public int StartupTimeoutSeconds = 30;
    }

    public static class ConfigStore
    {
        private static readonly string StateRoot = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "AntigravityProxyLauncher");
        private static readonly object LogLock = new object();
        public static string ConfigPath { get { return Path.Combine(StateRoot, "config.ini"); } }
        public static string LogPath { get { return Path.Combine(StateRoot, "launcher.log"); } }
        public static bool Exists { get { return File.Exists(ConfigPath); } }

        public static LauncherConfig Load()
        {
            var config = new LauncherConfig();
            if (!Exists) return config;
            var keys = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            int number = 0;
            foreach (string line in File.ReadAllLines(ConfigPath, Encoding.UTF8))
            {
                number++;
                string text = line.Trim();
                if (text.Length == 0 || text.StartsWith("#") || text.StartsWith(";")) continue;
                int equals = text.IndexOf('=');
                if (equals < 1) throw new FormatException("Invalid config line / 配置行无效: " + number);
                string key = text.Substring(0, equals).Trim();
                string value = text.Substring(equals + 1).Trim();
                if (!keys.Add(key)) throw new FormatException("Duplicate config key / 重复配置项: " + key);
                bool boolean;
                int integer;
                switch (key.ToLowerInvariant())
                {
                    case "useproxy":
                        if (!Boolean.TryParse(value, out boolean)) throw InvalidValue(key);
                        config.UseProxy = boolean; break;
                    case "autodetectproxy":
                        if (!Boolean.TryParse(value, out boolean)) throw InvalidValue(key);
                        config.AutoDetectProxy = boolean; break;
                    case "proxyurl": config.ProxyUrl = value; break;
                    case "antigravitypath": config.AntigravityPath = value; break;
                    case "proxyclientpath": config.ProxyClientPath = value; break;
                    case "startuptimeoutseconds":
                        if (!Int32.TryParse(value, NumberStyles.Integer, CultureInfo.InvariantCulture, out integer)) throw InvalidValue(key);
                        config.StartupTimeoutSeconds = integer; break;
                    default: throw new FormatException("Unknown config key / 未知配置项: " + key);
                }
            }
            Validate(config);
            return config;
        }

        public static void Validate(LauncherConfig config)
        {
            if (config == null) throw new ArgumentNullException("config");
            foreach (string value in new[] { config.ProxyUrl, config.AntigravityPath, config.ProxyClientPath })
                if (value != null && (value.IndexOf('\r') >= 0 || value.IndexOf('\n') >= 0))
                    throw new ArgumentException("Settings cannot contain newlines / 设置中不能包含换行。");
            if (config.StartupTimeoutSeconds < 5 || config.StartupTimeoutSeconds > 120)
                throw new ArgumentException("Startup timeout must be 5–120 seconds / 启动超时必须为 5–120 秒。");
            if (!String.IsNullOrWhiteSpace(config.ProxyUrl)) LauncherEngine.ParseProxy(config.ProxyUrl);
            if (config.UseProxy && !config.AutoDetectProxy && String.IsNullOrWhiteSpace(config.ProxyUrl))
                throw new ArgumentException("Enter a proxy URL / 请填写代理地址。");
            if (!String.IsNullOrWhiteSpace(config.AntigravityPath)) AppLocator.ValidateExecutable(config.AntigravityPath, "Antigravity.exe");
            if (!String.IsNullOrWhiteSpace(config.ProxyClientPath)) AppLocator.ValidateExecutable(config.ProxyClientPath, null);
        }

        public static void Save(LauncherConfig config)
        {
            Validate(config);
            Directory.CreateDirectory(StateRoot);
            string temporary = ConfigPath + "." + Guid.NewGuid().ToString("N") + ".tmp";
            try
            {
                string[] lines = {
                    "# Antigravity Proxy Launcher; values are plain text. Do not store credentials.",
                    "UseProxy=" + config.UseProxy.ToString().ToLowerInvariant(),
                    "AutoDetectProxy=" + config.AutoDetectProxy.ToString().ToLowerInvariant(),
                    "ProxyUrl=" + (config.ProxyUrl ?? "").Trim(),
                    "AntigravityPath=" + (config.AntigravityPath ?? "").Trim(),
                    "ProxyClientPath=" + (config.ProxyClientPath ?? "").Trim(),
                    "StartupTimeoutSeconds=" + config.StartupTimeoutSeconds.ToString(CultureInfo.InvariantCulture)
                };
                File.WriteAllLines(temporary, lines, new UTF8Encoding(false));
                if (File.Exists(ConfigPath)) File.Replace(temporary, ConfigPath, null);
                else File.Move(temporary, ConfigPath);
            }
            finally { if (File.Exists(temporary)) File.Delete(temporary); }
        }

        public static void Log(string message)
        {
            lock (LogLock)
            {
                try
                {
                    Directory.CreateDirectory(StateRoot);
                    if (File.Exists(LogPath) && new FileInfo(LogPath).Length > 512 * 1024)
                    {
                        string previous = LogPath + ".previous";
                        if (File.Exists(previous)) File.Delete(previous);
                        File.Move(LogPath, previous);
                    }
                    File.AppendAllText(LogPath, "[" + DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff", CultureInfo.InvariantCulture) + "] " + message + Environment.NewLine, new UTF8Encoding(false));
                }
                catch (IOException) { }
                catch (UnauthorizedAccessException) { }
            }
        }

        private static FormatException InvalidValue(string key)
        {
            return new FormatException("Invalid config value / 配置值无效: " + key);
        }
    }

    public static class AppLocator
    {
        public static string FindAntigravity(string explicitPath)
        {
            if (!String.IsNullOrWhiteSpace(explicitPath)) return ValidateExecutable(explicitPath, "Antigravity.exe");
            var paths = new List<string>();
            foreach (RegistryHive hive in new[] { RegistryHive.CurrentUser, RegistryHive.LocalMachine })
            foreach (RegistryView view in new[] { RegistryView.Registry64, RegistryView.Registry32 })
            {
                try
                {
                    using (var root = RegistryKey.OpenBaseKey(hive, view))
                    {
                        using (var app = root.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\App Paths\Antigravity.exe"))
                            if (app != null) paths.Add(Convert.ToString(app.GetValue("")));
                        using (var uninstall = root.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Uninstall"))
                        {
                            if (uninstall == null) continue;
                            foreach (string name in uninstall.GetSubKeyNames())
                            {
                                try
                                {
                                    using (var product = uninstall.OpenSubKey(name))
                                    {
                                        if (product == null || !Convert.ToString(product.GetValue("DisplayName")).StartsWith("Antigravity", StringComparison.OrdinalIgnoreCase)) continue;
                                        string directory = Convert.ToString(product.GetValue("InstallLocation"));
                                        if (!String.IsNullOrWhiteSpace(directory)) paths.Add(Path.Combine(directory, "Antigravity.exe"));
                                        string icon = Convert.ToString(product.GetValue("DisplayIcon")).Trim();
                                        if (icon.StartsWith("\"") && icon.IndexOf('"', 1) > 1) paths.Add(icon.Split('"')[1]);
                                        else if (icon.Length != 0) paths.Add(icon.Split(',')[0]);
                                    }
                                }
                                catch (System.Security.SecurityException) { }
                                catch (UnauthorizedAccessException) { }
                                catch (ArgumentException) { }
                                catch (IOException) { }
                                catch (NotSupportedException) { }
                            }
                        }
                    }
                }
                catch (System.Security.SecurityException) { }
                catch (UnauthorizedAccessException) { }
            }
            paths.Add(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Programs", "antigravity", "Antigravity.exe"));
            foreach (var folder in new[] { Environment.SpecialFolder.ProgramFiles, Environment.SpecialFolder.ProgramFilesX86 })
                paths.Add(Path.Combine(Environment.GetFolderPath(folder), "Antigravity", "Antigravity.exe"));
            foreach (string path in paths.Where(p => !String.IsNullOrWhiteSpace(p)).Distinct(StringComparer.OrdinalIgnoreCase))
            {
                try { return ValidateExecutable(path, "Antigravity.exe"); }
                catch (ArgumentException) { }
                catch (IOException) { }
                catch (NotSupportedException) { }
                catch (UnauthorizedAccessException) { }
            }
            return null;
        }

        internal static string ValidateExecutable(string value, string expectedName)
        {
            string path = Environment.ExpandEnvironmentVariables(value.Trim().Trim('"'));
            if (!Path.IsPathRooted(path)) throw new ArgumentException("Use an absolute executable path / 请使用程序的绝对路径。");
            path = Path.GetFullPath(path);
            if (!String.Equals(Path.GetExtension(path), ".exe", StringComparison.OrdinalIgnoreCase) ||
                (expectedName != null && !String.Equals(Path.GetFileName(path), expectedName, StringComparison.OrdinalIgnoreCase)))
                throw new ArgumentException("Choose " + (expectedName ?? "an .exe file") + " / 请选取正确的可执行文件。");
            if (!File.Exists(path)) throw new FileNotFoundException("Executable not found / 找不到程序: " + path, path);
            return path;
        }
    }

    public static class LauncherEngine
    {
        private static readonly int SessionId = Process.GetCurrentProcess().SessionId;
        [DllImport("user32.dll")] private static extern bool ShowWindowAsync(IntPtr window, int command);
        [DllImport("user32.dll")] private static extern bool IsIconic(IntPtr window);
        [DllImport("user32.dll")] private static extern bool SetForegroundWindow(IntPtr window);
        [DllImport("user32.dll")] private static extern bool BringWindowToTop(IntPtr window);
        [DllImport("user32.dll")] private static extern IntPtr GetForegroundWindow();

        public static void Run(LauncherConfig config)
        {
            ConfigStore.Validate(config);
            string executable = AppLocator.FindAntigravity(config.AntigravityPath);
            if (executable == null) throw new FileNotFoundException("Antigravity was not found. Select Antigravity.exe in Settings. / 未找到 Antigravity，请在设置中选择程序。");
            string proxy = ResolveProxy(config);
            if (config.UseProxy && proxy == null && !String.IsNullOrWhiteSpace(config.ProxyClientPath))
            {
                string clientPath = AppLocator.ValidateExecutable(config.ProxyClientPath, null);
                ConfigStore.Log("Starting the configured proxy client.");
                using (Process.Start(new ProcessStartInfo(clientPath) { UseShellExecute = true, WorkingDirectory = Path.GetDirectoryName(clientPath) })) { }
                var timer = Stopwatch.StartNew();
                while (proxy == null && timer.ElapsedMilliseconds < 20000)
                {
                    Thread.Sleep(300);
                    proxy = ResolveProxy(config);
                }
            }
            if (config.UseProxy && proxy == null)
                throw new InvalidOperationException("No reachable proxy was found. Start your proxy client or change the URL in Settings. / 未找到可用代理，请启动代理客户端或修改地址。");
            if (config.UseProxy && !CanConnect(ParseProxy(proxy), true))
                throw new InvalidOperationException("The configured proxy cannot be reached. / 无法连接配置的代理服务器。");

            bool foreground;
            if (ShowWindow(executable, out foreground))
            {
                ConfigStore.Log("Existing main window shown; foreground=" + foreground + ". Environment variables cannot be changed for an already running instance.");
                return;
            }
            var start = CreateStartInfo(executable, config, proxy);
            ConfigStore.Log("Starting Antigravity. Proxy mode=" + (config.UseProxy ? "enabled" : "direct") + ".");
            using (var child = Process.Start(start))
            {
                if (child == null) throw new InvalidOperationException("Windows could not create the application process. / Windows 未能启动应用。");
                var timer = Stopwatch.StartNew();
                while (timer.ElapsedMilliseconds < config.StartupTimeoutSeconds * 1000)
                {
                    if (ShowWindow(executable, out foreground))
                    {
                        ConfigStore.Log("Main window shown; foreground=" + foreground + ".");
                        return;
                    }
                    Thread.Sleep(250);
                }
                string exit = child.HasExited ? " Exit code=" + child.ExitCode + "." : "";
                throw new InvalidOperationException("Antigravity did not display a main window before the timeout." + exit + " See launcher.log and Antigravity logs. / 启动超时，尚未显示主窗口。后台进程未被终止。");
            }
        }

        internal static ProcessStartInfo CreateStartInfo(string executable, LauncherConfig config, string proxy)
        {
            var start = new ProcessStartInfo(executable) { UseShellExecute = false, WorkingDirectory = Path.GetDirectoryName(executable) };
            foreach (string name in new[] { "HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "http_proxy", "https_proxy", "all_proxy", "NO_PROXY", "no_proxy" }) start.EnvironmentVariables.Remove(name);
            if (config.UseProxy)
            {
                start.EnvironmentVariables["HTTP_PROXY"] = proxy;
                start.EnvironmentVariables["HTTPS_PROXY"] = proxy;
                start.EnvironmentVariables["ALL_PROXY"] = proxy;
            }
            start.EnvironmentVariables["NO_PROXY"] = "localhost,127.0.0.1,::1,[::1]";
            start.EnvironmentVariables.Remove("ELECTRON_RUN_AS_NODE");
            return start;
        }

        public static string ResolveProxy(LauncherConfig config)
        {
            ConfigStore.Validate(config);
            if (!config.UseProxy) return null;
            if (!config.AutoDetectProxy)
            {
                Uri manual = ParseProxy(config.ProxyUrl);
                return !IsLocal(manual) || CanConnect(manual, false) ? manual.AbsoluteUri.TrimEnd('/') : null;
            }
            var candidates = new List<string> { config.ProxyUrl };
            foreach (string name in new[] { "HTTPS_PROXY", "HTTP_PROXY", "ALL_PROXY" }) candidates.Add(Environment.GetEnvironmentVariable(name));
            candidates.AddRange(SystemProxies());
            candidates.AddRange(new[] { "http://127.0.0.1:7890", "http://127.0.0.1:7897", "http://127.0.0.1:10808", "http://127.0.0.1:10809" });
            foreach (string candidate in candidates.Where(p => !String.IsNullOrWhiteSpace(p)).Distinct(StringComparer.OrdinalIgnoreCase))
            {
                Uri uri;
                try { uri = ParseProxy(candidate); }
                catch (ArgumentException) { continue; }
                // Auto detection only probes loopback. Remote proxies require explicit selection.
                if (IsLocal(uri) && CanConnect(uri, false)) return uri.AbsoluteUri.TrimEnd('/');
            }
            return null;
        }

        public static string Diagnose(LauncherConfig config)
        {
            var report = new StringBuilder();
            report.AppendLine("Antigravity Proxy Launcher diagnostics (no applications are started)");
            report.AppendLine("Config: " + ConfigStore.ConfigPath);
            report.AppendLine("Log: " + ConfigStore.LogPath);
            try
            {
                ConfigStore.Validate(config);
                report.AppendLine("Antigravity: " + (AppLocator.FindAntigravity(config.AntigravityPath) ?? "not found"));
                string proxy = ResolveProxy(config);
                report.AppendLine("Proxy mode: " + (!config.UseProxy ? "direct" : config.AutoDetectProxy ? "auto (loopback only)" : "manual"));
                if (proxy != null)
                {
                    Uri uri = ParseProxy(proxy);
                    report.AppendLine("Proxy: " + proxy);
                    report.AppendLine(IsLocal(uri) ? "Local TCP listener: reachable" : "Remote TCP endpoint: not tested by diagnostics");
                }
                else if (config.UseProxy) report.AppendLine("Proxy: no reachable local candidate");
                report.AppendLine("Proxy client: " + (String.IsNullOrWhiteSpace(config.ProxyClientPath) ? "not configured" : config.ProxyClientPath));
                report.AppendLine("A TCP listener does not prove HTTP/SOCKS support or access to Google.");
                report.AppendLine("Existing processes cannot receive updated environment variables; fully exit Antigravity before changing proxy settings.");
            }
            catch (Exception error) { report.AppendLine("Error: " + error.Message); }
            return report.ToString();
        }

        internal static Uri ParseProxy(string value)
        {
            Uri uri;
            if (!Uri.TryCreate((value ?? "").Trim(), UriKind.Absolute, out uri) ||
                (uri.Scheme != "http" && uri.Scheme != "socks5" && uri.Scheme != "socks5h") ||
                String.IsNullOrWhiteSpace(uri.Host) || uri.Port < 1 || uri.Port > 65535 ||
                uri.UserInfo.Length != 0 || uri.Query.Length != 0 || uri.Fragment.Length != 0 ||
                (uri.AbsolutePath != "" && uri.AbsolutePath != "/"))
                throw new ArgumentException("Use http://host:port or socks5://host:port, without credentials or a URL path. / 请使用不含凭据和路径的代理地址。");
            return uri;
        }

        private static bool IsLocal(Uri uri)
        {
            IPAddress address;
            return String.Equals(uri.DnsSafeHost, "localhost", StringComparison.OrdinalIgnoreCase) ||
                (IPAddress.TryParse(uri.DnsSafeHost, out address) && IPAddress.IsLoopback(address));
        }

        private static bool CanConnect(Uri uri, bool allowRemote)
        {
            if (!allowRemote && !IsLocal(uri)) return false;
            using (var client = new TcpClient())
            {
                try
                {
                    var pending = client.BeginConnect(uri.DnsSafeHost, uri.Port, null, null);
                    using (pending.AsyncWaitHandle)
                    {
                        if (!pending.AsyncWaitHandle.WaitOne(IsLocal(uri) ? 300 : 1500)) return false;
                        client.EndConnect(pending);
                        return client.Connected;
                    }
                }
                catch (SocketException) { return false; }
            }
        }

        private static IEnumerable<string> SystemProxies()
        {
            var proxies = new List<string>();
            try
            {
                using (var key = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Internet Settings"))
                {
                    if (key == null || Convert.ToInt32(key.GetValue("ProxyEnable", 0), CultureInfo.InvariantCulture) == 0) return proxies;
                    string server = Convert.ToString(key.GetValue("ProxyServer"));
                    foreach (string entry in server.Split(';'))
                    {
                        int equals = entry.IndexOf('=');
                        string protocol = equals < 0 ? "http" : entry.Substring(0, equals).Trim();
                        string address = (equals < 0 ? entry : entry.Substring(equals + 1)).Trim();
                        if (address.Length == 0) continue;
                        proxies.Add(address.Contains("://") ? address : (protocol == "socks" ? "socks5://" : "http://") + address);
                    }
                }
            }
            catch (System.Security.SecurityException) { }
            catch (UnauthorizedAccessException) { }
            return proxies;
        }

        private static bool ShowWindow(string executable, out bool foreground)
        {
            foreground = false;
            bool found = false;
            foreach (var process in Process.GetProcessesByName("Antigravity"))
            using (process)
            {
                try
                {
                    if (process.SessionId != SessionId || !String.Equals(process.MainModule.FileName, executable, StringComparison.OrdinalIgnoreCase)) continue;
                    process.Refresh();
                    IntPtr window = process.MainWindowHandle;
                    if (window == IntPtr.Zero) continue;
                    ShowWindowAsync(window, IsIconic(window) ? 9 : 5);
                    BringWindowToTop(window);
                    SetForegroundWindow(window);
                    foreground = GetForegroundWindow() == window;
                    found = true;
                    if (foreground) return true;
                }
                catch (InvalidOperationException) { }
                catch (Win32Exception) { }
                catch (UnauthorizedAccessException) { }
            }
            return found;
        }
    }
}
