using System;
using System.IO;
using System.Threading;
using System.Windows.Forms;

// A local test double, never included in release assets or used to launch the real application.
internal static class AntigravityFixture
{
    [STAThread]
    private static void Main(string[] args)
    {
        if (args.Length == 1 && args[0] == "--headless") { Thread.Sleep(45000); return; }
        string[] names = { "HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "NO_PROXY" };
        using (var writer = new StreamWriter(Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "fixture-environment.txt")))
            foreach (string name in names) writer.WriteLine(name + "=" + Environment.GetEnvironmentVariable(name));
        using (var form = new Form { Text = "Launcher regression fixture", Width = 420, Height = 180 })
        using (var timer = new System.Windows.Forms.Timer { Interval = 30000 })
        {
            form.Controls.Add(new Label { Text = "Local regression test. This window closes automatically.", Dock = DockStyle.Fill });
            timer.Tick += delegate { form.Close(); };
            timer.Start();
            Application.Run(form);
        }
    }
}
