using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using AntigravityProxyLauncher;

internal static class LauncherTests
{
    private static int passed;

    private static int Main(string[] args)
    {
        try
        {
            Test("Default settings validate", delegate { ConfigStore.Validate(new LauncherConfig()); });
            Test("Proxy protocols and IPv6", delegate
            {
                foreach (string address in new[] { "http://127.0.0.1:10808", "socks5://localhost:7890", "socks5h://[::1]:1080" })
                    Assert(LauncherEngine.ParseProxy(address).Port > 0, "Port missing");
            });
            Test("Reject malformed URLs and embedded credentials", delegate
            {
                foreach (string address in new[] { "localhost:10808", "https://localhost:8080", "file:///tmp/proxy", "http://user:password@127.0.0.1:10808", "http://localhost:8080/api", "http://localhost:8080?secret=x", "http://localhost:8080#x", "socks5://localhost", "http://localhost:0" })
                    Throws(delegate { LauncherEngine.ParseProxy(address); });
            });
            Test("Config cannot inject extra lines", delegate
            {
                Throws(delegate { ConfigStore.Validate(new LauncherConfig { ProxyUrl = "http://localhost:7890\nUseProxy=false" }); });
                Throws(delegate { ConfigStore.Validate(new LauncherConfig { StartupTimeoutSeconds = 1 }); });
                Throws(delegate { ConfigStore.Validate(new LauncherConfig { UseProxy = true, AutoDetectProxy = false, ProxyUrl = "" }); });
                Throws(delegate { ConfigStore.Validate(new LauncherConfig { UseProxy = false, ProxyUrl = "http://user:password@localhost:7890" }); });
            });
            Test("Proxy settings are passed only to child processes", delegate
            {
                string originalHttp = Environment.GetEnvironmentVariable("HTTP_PROXY");
                string originalHttps = Environment.GetEnvironmentVariable("HTTPS_PROXY");
                var start = LauncherEngine.CreateStartInfo("Antigravity.exe", new LauncherConfig(), "http://127.0.0.1:14321");
                Assert(!start.UseShellExecute, "Shell execution would lose environment overrides");
                Assert(start.EnvironmentVariables["HTTP_PROXY"] == "http://127.0.0.1:14321", "Missing HTTP_PROXY");
                Assert(start.EnvironmentVariables["HTTPS_PROXY"] == start.EnvironmentVariables["HTTP_PROXY"], "Missing HTTPS_PROXY");
                Assert(start.EnvironmentVariables["ALL_PROXY"] == start.EnvironmentVariables["HTTP_PROXY"], "Missing ALL_PROXY");
                Assert(start.EnvironmentVariables["NO_PROXY"].Contains("localhost") && start.EnvironmentVariables["NO_PROXY"].Contains("::1"), "Local callbacks would be proxied");
                Assert(start.EnvironmentVariables["ELECTRON_RUN_AS_NODE"] == null, "Electron node mode was inherited");
                Assert(Environment.GetEnvironmentVariable("HTTP_PROXY") == originalHttp && Environment.GetEnvironmentVariable("HTTPS_PROXY") == originalHttps, "Parent environment was modified");
            });
            Test("Direct mode clears inherited proxies", delegate
            {
                string previous = Environment.GetEnvironmentVariable("HTTPS_PROXY");
                try
                {
                    Environment.SetEnvironmentVariable("HTTPS_PROXY", "http://127.0.0.1:9999");
                    var start = LauncherEngine.CreateStartInfo("Antigravity.exe", new LauncherConfig { UseProxy = false }, null);
                    Assert(start.EnvironmentVariables["HTTPS_PROXY"] == null && start.EnvironmentVariables["HTTP_PROXY"] == null && start.EnvironmentVariables["ALL_PROXY"] == null, "Direct mode retained a proxy");
                    Assert(Environment.GetEnvironmentVariable("HTTPS_PROXY") == "http://127.0.0.1:9999", "Parent proxy was changed");
                }
                finally { Environment.SetEnvironmentVariable("HTTPS_PROXY", previous); }
            });
            Test("Preferred local proxy is detected", delegate
            {
                var listener = new TcpListener(IPAddress.Loopback, 0);
                listener.Start();
                try
                {
                    string address = "http://127.0.0.1:" + ((IPEndPoint)listener.LocalEndpoint).Port;
                    Assert(LauncherEngine.ResolveProxy(new LauncherConfig { ProxyUrl = address }) == address, "Preferred live listener was not selected");
                    Assert(LauncherEngine.ResolveProxy(new LauncherConfig { UseProxy = false }) == null, "Direct mode detected a proxy");
                }
                finally { listener.Stop(); }
            });
            Test("Closed manual proxy is unavailable", delegate
            {
                var listener = new TcpListener(IPAddress.Loopback, 0);
                listener.Start();
                int port = ((IPEndPoint)listener.LocalEndpoint).Port;
                listener.Stop();
                Assert(LauncherEngine.ResolveProxy(new LauncherConfig { AutoDetectProxy = false, ProxyUrl = "http://127.0.0.1:" + port }) == null, "A closed local port was accepted");
            });
            Test("Remote diagnostic mode does not make network requests", delegate
            {
                var config = new LauncherConfig { AutoDetectProxy = false, ProxyUrl = "http://unresolvable.invalid:8080" };
                string report = LauncherEngine.Diagnose(config);
                Assert(report.Contains("not tested by diagnostics"), "Remote endpoint was probed or hidden");
            });
            Test("Explicit paths survive spaces and reject installers", delegate
            {
                string directory = Path.Combine(Path.GetTempPath(), "launcher tests " + Guid.NewGuid().ToString("N"));
                Directory.CreateDirectory(directory);
                try
                {
                    string application = Path.Combine(directory, "Antigravity.exe");
                    File.WriteAllBytes(application, new byte[] { 0 });
                    Assert(AppLocator.FindAntigravity(application) == application, "Explicit app path was not selected");
                    string installer = Path.Combine(directory, "AntigravitySetup.exe");
                    File.WriteAllBytes(installer, new byte[] { 0 });
                    Throws(delegate { AppLocator.FindAntigravity(installer); });
                    Throws(delegate { AppLocator.FindAntigravity(Path.Combine(directory, "missing", "Antigravity.exe")); });
                    Throws(delegate { AppLocator.FindAntigravity("Antigravity.exe"); });
                }
                finally { Directory.Delete(directory, true); }
            });
            if (args.Length == 1) Test("Headless helper does not block a new GUI; repeat launch reuses the window", delegate { RunGuiRegression(args[0]); });
            Console.WriteLine("PASS: " + passed + " test groups.");
            return 0;
        }
        catch (Exception error) { Console.Error.WriteLine(error); return 1; }
    }

    private static void RunGuiRegression(string fixture)
    {
        string application = Path.GetFullPath(fixture);
        string capture = Path.Combine(Path.GetDirectoryName(application), "fixture-environment.txt");
        if (File.Exists(capture)) File.Delete(capture);
        using (var helper = Process.Start(new ProcessStartInfo(application, "--headless") { UseShellExecute = false }))
        {
            Process window = null;
            var listener = new TcpListener(IPAddress.Loopback, 0);
            listener.Start();
            try
            {
                string proxy = "http://127.0.0.1:" + ((IPEndPoint)listener.LocalEndpoint).Port;
                var config = new LauncherConfig { AntigravityPath = application, AutoDetectProxy = false, ProxyUrl = proxy, StartupTimeoutSeconds = 10 };
                LauncherEngine.Run(config);
                Assert(!helper.HasExited, "Headless helper was terminated");
                window = Process.GetProcessesByName("Antigravity").FirstOrDefault(p => {
                    try { return p.MainWindowHandle != IntPtr.Zero && String.Equals(p.MainModule.FileName, application, StringComparison.OrdinalIgnoreCase); }
                    catch { p.Dispose(); return false; }
                });
                Assert(window != null, "Regression GUI was not created");
                int mainId = window.Id;
                Assert(File.ReadAllText(capture).Contains("HTTPS_PROXY=" + proxy), "Proxy was not inherited by the GUI process");
                LauncherEngine.Run(config);
                Assert(!window.HasExited && window.Id == mainId && !helper.HasExited, "Repeat launch did not reuse the existing window");
            }
            finally
            {
                listener.Stop();
                if (window != null)
                {
                    window.CloseMainWindow();
                    if (!window.WaitForExit(3000)) window.Kill();
                    window.Dispose();
                }
                // Only the fixture helper created by this test is stopped; real applications are never touched.
                if (!helper.HasExited) { helper.Kill(); helper.WaitForExit(3000); }
            }
        }
    }

    private static void Test(string name, Action action)
    {
        action();
        passed++;
        Console.WriteLine("PASS " + name);
    }

    private static void Assert(bool condition, string message)
    {
        if (!condition) throw new InvalidOperationException(message);
    }

    private static void Throws(Action action)
    {
        try { action(); }
        catch (ArgumentException) { return; }
        catch (IOException) { return; }
        throw new InvalidOperationException("Expected a validation error.");
    }
}
