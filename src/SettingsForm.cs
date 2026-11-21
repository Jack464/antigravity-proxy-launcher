using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace AntigravityProxyLauncher
{
    internal sealed class SettingsForm : Form
    {
        private readonly CheckBox useProxy = new CheckBox();
        private readonly CheckBox autoDetect = new CheckBox();
        private readonly TextBox proxyUrl = new TextBox();
        private readonly TextBox appPath = new TextBox();
        private readonly TextBox clientPath = new TextBox();
        private readonly NumericUpDown startupTimeout = new NumericUpDown();
        private readonly TextBox diagnostics = new TextBox();
        private readonly Label status = new Label();
        private readonly TableLayoutPanel fields = new TableLayoutPanel();
        private readonly FlowLayoutPanel actions = new FlowLayoutPanel();
        private bool busy;

        internal SettingsForm()
        {
            Text = Program.ProductName + " " + Program.Version + " — 设置 / Settings";
            StartPosition = FormStartPosition.CenterScreen;
            AutoScaleMode = AutoScaleMode.Dpi;
            Font = new Font("Microsoft YaHei UI", 9F);
            ClientSize = new Size(810, 690);
            MinimumSize = new Size(826, 729);
            try { Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath); }
            catch (ArgumentException) { }

            TableLayoutPanel layout = new TableLayoutPanel();
            layout.Dock = DockStyle.Fill;
            layout.Padding = new Padding(20, 16, 20, 14);
            layout.ColumnCount = 1;
            layout.RowCount = 8;
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 35));
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 58));
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 235));
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 54));
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 48));
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 25));
            layout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 28));
            Controls.Add(layout);

            Label heading = new Label();
            heading.Text = "让 Antigravity 使用你的代理";
            heading.Font = new Font(Font.FontFamily, 15F, FontStyle.Bold);
            heading.AutoSize = true;
            layout.Controls.Add(heading, 0, 0);

            Label introduction = new Label();
            introduction.Text = "首次运行请确认代理和应用位置，保存后即可双击启动。\r\n" +
                "请将此程序放在独立文件夹中，避免应用更新清理；代理设置只用于新启动的应用进程。";
            introduction.Dock = DockStyle.Fill;
            layout.Controls.Add(introduction, 0, 1);

            fields.Dock = DockStyle.Fill;
            fields.ColumnCount = 3;
            fields.RowCount = 6;
            fields.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 164));
            fields.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
            fields.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 95));
            for (int row = 0; row < 6; row++)
                fields.RowStyles.Add(new RowStyle(SizeType.Absolute, 38));
            layout.Controls.Add(fields, 0, 2);

            FlowLayoutPanel proxyOptions = new FlowLayoutPanel();
            proxyOptions.Dock = DockStyle.Fill;
            proxyOptions.WrapContents = false;
            useProxy.Text = "使用代理 / Use proxy";
            useProxy.AutoSize = true;
            autoDetect.Text = "自动查找代理 / Auto detect";
            autoDetect.AutoSize = true;
            proxyOptions.Controls.Add(useProxy);
            proxyOptions.Controls.Add(autoDetect);
            fields.Controls.Add(proxyOptions, 0, 0);
            fields.SetColumnSpan(proxyOptions, 3);
            AddField(1, "代理地址 / Proxy URL", proxyUrl, null);
            AddField(2, "应用位置（可留空）", appPath, delegate { BrowseExecutable(appPath, "选择 Antigravity.exe", "Antigravity.exe|Antigravity.exe"); });
            AddField(3, "代理客户端（可留空）", clientPath, delegate { BrowseExecutable(clientPath, "选择代理客户端 / Select proxy client", "Windows programs (*.exe)|*.exe"); });

            startupTimeout.Minimum = 5;
            startupTimeout.Maximum = 120;
            startupTimeout.Increment = 5;
            startupTimeout.Width = 90;
            FlowLayoutPanel timeoutPanel = new FlowLayoutPanel();
            timeoutPanel.Dock = DockStyle.Fill;
            timeoutPanel.WrapContents = false;
            timeoutPanel.Controls.Add(startupTimeout);
            timeoutPanel.Controls.Add(new Label { Text = "秒 / seconds", AutoSize = true, Padding = new Padding(3, 5, 0, 0) });
            AddField(4, "启动等待 / Timeout", timeoutPanel, null);

            Label note = new Label();
            note.Text = "支持 http:// 与 socks5://。自动模式会优先尝试填写的地址；代理客户端仅在端口未就绪时启动。";
            note.Dock = DockStyle.Fill;
            note.ForeColor = SystemColors.GrayText;
            fields.Controls.Add(note, 0, 5);
            fields.SetColumnSpan(note, 3);

            TableLayoutPanel pathPanel = new TableLayoutPanel();
            pathPanel.Dock = DockStyle.Fill;
            pathPanel.ColumnCount = 1;
            pathPanel.RowCount = 2;
            pathPanel.RowStyles.Add(new RowStyle(SizeType.Absolute, 21));
            pathPanel.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
            pathPanel.Controls.Add(new Label { Text = "配置文件 / Configuration file", AutoSize = true }, 0, 0);
            TextBox configLocation = new TextBox();
            configLocation.Text = ConfigStore.ConfigPath;
            configLocation.ReadOnly = true;
            configLocation.Dock = DockStyle.Fill;
            pathPanel.Controls.Add(configLocation, 0, 1);
            layout.Controls.Add(pathPanel, 0, 3);

            actions.Dock = DockStyle.Fill;
            actions.WrapContents = false;
            actions.Padding = new Padding(0, 6, 0, 0);
            Button launch = AddButton("保存并启动", 114, async delegate { await SaveAndLaunch(); });
            AddButton("仅保存", 85, delegate { SaveOnly(); });
            AddButton("诊断 / Check", 112, async delegate { await RunDiagnostics(); });
            AddButton("创建桌面快捷方式", 151, delegate { CreateShortcut(); });
            AddButton("打开日志", 91, delegate { OpenLogs(); });
            AcceptButton = launch;
            layout.Controls.Add(actions, 0, 4);

            Label diagnosticLabel = new Label();
            diagnosticLabel.Text = "本地诊断 / Local diagnostics（端口可用不代表节点能够访问 Google）";
            diagnosticLabel.AutoSize = true;
            layout.Controls.Add(diagnosticLabel, 0, 5);
            diagnostics.Dock = DockStyle.Fill;
            diagnostics.Multiline = true;
            diagnostics.ReadOnly = true;
            diagnostics.ScrollBars = ScrollBars.Both;
            diagnostics.WordWrap = false;
            diagnostics.Font = new Font("Consolas", 9F);
            layout.Controls.Add(diagnostics, 0, 6);
            status.Text = "就绪 / Ready";
            status.Dock = DockStyle.Fill;
            status.Padding = new Padding(0, 6, 0, 0);
            layout.Controls.Add(status, 0, 7);

            useProxy.CheckedChanged += delegate { UpdateProxyControls(); };
            FormClosing += delegate(object sender, FormClosingEventArgs args) { if (busy) args.Cancel = true; };
            LoadSettings();
        }

        private void AddField(int row, string label, Control input, Action browse)
        {
            fields.Controls.Add(new Label { Text = label, Dock = DockStyle.Fill, TextAlign = ContentAlignment.MiddleLeft }, 0, row);
            input.Dock = DockStyle.Fill;
            input.Margin = new Padding(3, 6, 8, 5);
            fields.Controls.Add(input, 1, row);
            if (browse == null)
                fields.SetColumnSpan(input, 2);
            else
            {
                Button button = new Button();
                button.Text = "浏览…";
                button.Dock = DockStyle.Fill;
                button.Margin = new Padding(0, 4, 0, 4);
                button.Click += delegate { browse(); };
                fields.Controls.Add(button, 2, row);
            }
        }

        private Button AddButton(string text, int width, EventHandler handler)
        {
            Button button = new Button();
            button.Text = text;
            button.Size = new Size(width, 32);
            button.Margin = new Padding(0, 0, 8, 0);
            button.Click += handler;
            actions.Controls.Add(button);
            return button;
        }

        private void LoadSettings()
        {
            LauncherConfig config;
            try { config = ConfigStore.Load(); }
            catch (Exception error)
            {
                config = new LauncherConfig();
                diagnostics.Text = "无法读取配置 / Could not read settings:\r\n" + error.Message +
                    "\r\n\r\n下方字段使用默认值。保存将替换现有配置；关闭窗口则保留原文件。";
            }
            useProxy.Checked = config.UseProxy;
            autoDetect.Checked = config.AutoDetectProxy;
            proxyUrl.Text = config.ProxyUrl;
            appPath.Text = config.AntigravityPath;
            clientPath.Text = config.ProxyClientPath;
            startupTimeout.Value = Math.Max(5, Math.Min(120, config.StartupTimeoutSeconds));
            UpdateProxyControls();
        }

        private LauncherConfig ReadSettings()
        {
            return new LauncherConfig
            {
                UseProxy = useProxy.Checked,
                AutoDetectProxy = autoDetect.Checked,
                ProxyUrl = proxyUrl.Text.Trim(),
                AntigravityPath = appPath.Text.Trim(),
                ProxyClientPath = clientPath.Text.Trim(),
                StartupTimeoutSeconds = (int)startupTimeout.Value
            };
        }

        private void UpdateProxyControls()
        {
            autoDetect.Enabled = useProxy.Checked;
            proxyUrl.Enabled = useProxy.Checked;
            clientPath.Enabled = useProxy.Checked;
        }

        private void SetBusy(bool value, string message)
        {
            busy = value;
            fields.Enabled = !value;
            actions.Enabled = !value;
            UseWaitCursor = value;
            status.Text = message;
        }

        private void SaveOnly()
        {
            try
            {
                LauncherConfig config = ReadSettings();
                ConfigStore.Validate(config);
                ConfigStore.Save(config);
                status.Text = "已保存。下次双击启动器即可启动 / Saved.";
            }
            catch (Exception error) { ShowError(error); }
        }

        private async Task SaveAndLaunch()
        {
            try
            {
                LauncherConfig config = ReadSettings();
                ConfigStore.Validate(config);
                ConfigStore.Save(config);
                SetBusy(true, "正在启动，等待应用窗口 / Starting Antigravity…");
                await Task.Run(delegate { LauncherEngine.Run(config); });
                SetBusy(false, "应用已打开 / Antigravity is open.");
                Close();
            }
            catch (Exception error)
            {
                SetBusy(false, "启动失败，请检查诊断 / Launch failed.");
                ShowError(error);
            }
        }

        private async Task RunDiagnostics()
        {
            try
            {
                LauncherConfig config = ReadSettings();
                SetBusy(true, "正在检查本地配置和代理端口 / Checking…");
                diagnostics.Text = await Task.Run(delegate { return LauncherEngine.Diagnose(config); });
                SetBusy(false, "诊断完成，未启动任何应用 / Diagnostics complete.");
            }
            catch (Exception error)
            {
                SetBusy(false, "诊断失败 / Diagnostics failed.");
                diagnostics.Text = error.Message;
            }
        }

        private void BrowseExecutable(TextBox target, string title, string filter)
        {
            using (OpenFileDialog dialog = new OpenFileDialog())
            {
                dialog.Title = title;
                dialog.Filter = filter;
                dialog.CheckFileExists = true;
                if (File.Exists(target.Text)) dialog.FileName = target.Text;
                if (dialog.ShowDialog(this) == DialogResult.OK) target.Text = dialog.FileName;
            }
        }

        private void CreateShortcut()
        {
            object shell = null;
            object shortcut = null;
            try
            {
                string desktop = Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory);
                if (String.IsNullOrEmpty(desktop) || !Directory.Exists(desktop))
                    throw new DirectoryNotFoundException("找不到当前用户桌面 / User desktop was not found.");
                string path = Path.Combine(desktop, "Antigravity Proxy Launcher.lnk");
                Type shellType = Type.GetTypeFromProgID("WScript.Shell");
                if (shellType == null) throw new NotSupportedException("Windows Script Host COM is unavailable.");
                shell = Activator.CreateInstance(shellType);
                shortcut = shellType.InvokeMember("CreateShortcut", BindingFlags.InvokeMethod, null, shell, new object[] { path });
                Type shortcutType = shortcut.GetType();
                shortcutType.InvokeMember("TargetPath", BindingFlags.SetProperty, null, shortcut, new object[] { Application.ExecutablePath });
                shortcutType.InvokeMember("Arguments", BindingFlags.SetProperty, null, shortcut, new object[] { "" });
                shortcutType.InvokeMember("WorkingDirectory", BindingFlags.SetProperty, null, shortcut, new object[] { Path.GetDirectoryName(Application.ExecutablePath) });
                shortcutType.InvokeMember("IconLocation", BindingFlags.SetProperty, null, shortcut, new object[] { Application.ExecutablePath + ",0" });
                shortcutType.InvokeMember("Description", BindingFlags.SetProperty, null, shortcut, new object[] { Program.ProductName });
                shortcutType.InvokeMember("Save", BindingFlags.InvokeMethod, null, shortcut, null);
                status.Text = "已创建桌面快捷方式 / Desktop shortcut created.";
                MessageBox.Show(this, "已创建：" + path + "\r\n\r\n快捷方式指向当前程序；请保留此程序所在文件夹。\r\nKeep this executable in its current folder so the shortcut keeps working.", Program.ProductName, MessageBoxButtons.OK, MessageBoxIcon.Information);
            }
            catch (Exception error) { ShowError(error); }
            finally
            {
                if (shortcut != null && Marshal.IsComObject(shortcut)) Marshal.ReleaseComObject(shortcut);
                if (shell != null && Marshal.IsComObject(shell)) Marshal.ReleaseComObject(shell);
            }
        }

        private void OpenLogs()
        {
            try
            {
                string directory = Path.GetDirectoryName(ConfigStore.LogPath);
                Directory.CreateDirectory(directory);
                Process.Start(new ProcessStartInfo(directory) { UseShellExecute = true });
            }
            catch (Exception error) { ShowError(error); }
        }

        private void ShowError(Exception error)
        {
            ConfigStore.Log("ERROR: " + error.Message);
            diagnostics.Text = error.Message;
            MessageBox.Show(this, error.Message, Program.ProductName, MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }
}
