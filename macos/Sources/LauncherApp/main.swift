import AppKit
import Darwin
import LauncherCore
import UniformTypeIdentifiers

private let productName = "Antigravity Proxy Launcher"
private let productVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.1.0"

private func writeError(_ message: String) {
    FileHandle.standardError.write(Data((message + "\n").utf8))
}

private final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let useProxy = NSButton(checkboxWithTitle: "使用代理 / Use proxy", target: nil, action: nil)
    private let autoDetect = NSButton(checkboxWithTitle: "自动查找 / Auto detect", target: nil, action: nil)
    private let proxyURL = NSTextField(string: "")
    private let appPath = NSTextField(string: "")
    private let clientPath = NSTextField(string: "")
    private let timeout = NSTextField(string: "30")
    private let output = NSTextView()
    private let status = NSTextField(labelWithString: "就绪 / Ready")
    private var actionButtons: [NSButton] = []
    private var fields: [NSControl] = []
    private(set) var busy = false
    var onLaunch: ((LauncherConfig) -> Void)?

    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 820, height: 680),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        window.title = "\(productName) \(productVersion) — 设置 / Settings"
        window.minSize = NSSize(width: 790, height: 660)
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        buildInterface()
        loadSettings()
        window.center()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    private func buildInterface() {
        guard let content = window?.contentView else { return }
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 9
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 18),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -16)
        ])

        let heading = label("让 Antigravity 使用你的代理", size: 21, weight: .semibold)
        stack.addArrangedSubview(heading)
        let introduction = label("首次保存后即可双击启动。请将启动器保存在 Antigravity 安装目录之外。\nFirst save your settings; proxy variables apply only to newly started application processes.", lines: 2)
        addFullWidth(introduction, to: stack)

        let options = NSStackView(views: [useProxy, autoDetect])
        options.orientation = .horizontal
        options.spacing = 22
        stack.addArrangedSubview(options)
        useProxy.target = self
        useProxy.action = #selector(updateProxyControls)

        addFullWidth(fieldRow("代理地址 / Proxy URL", field: proxyURL), to: stack)
        addFullWidth(fieldRow("Antigravity（可留空）", field: appPath, browse: #selector(browseApplication)), to: stack)
        addFullWidth(fieldRow("代理客户端（可留空）", field: clientPath, browse: #selector(browseProxyClient)), to: stack)

        let timeoutLabel = label("启动等待 / Timeout")
        timeoutLabel.widthAnchor.constraint(equalToConstant: 178).isActive = true
        timeout.alignment = .right
        timeout.widthAnchor.constraint(equalToConstant: 70).isActive = true
        let timeoutRow = NSStackView(views: [timeoutLabel, timeout, label("秒 / seconds（5–120）")])
        timeoutRow.orientation = .horizontal
        timeoutRow.alignment = .firstBaseline
        timeoutRow.spacing = 8
        stack.addArrangedSubview(timeoutRow)

        let note = label("支持 HTTP、SOCKS5。自动检测仅检查本机端口；远程代理请取消自动查找。\n代理客户端仅在端口未就绪时启动；设置变更后需退出并重新打开 Antigravity。", lines: 2)
        note.textColor = .secondaryLabelColor
        addFullWidth(note, to: stack)

        let configField = NSTextField(string: ConfigStore.configURL.path)
        configField.isEditable = false
        configField.isSelectable = true
        configField.lineBreakMode = .byTruncatingMiddle
        let configLabel = label("配置文件 / Config")
        configLabel.widthAnchor.constraint(equalToConstant: 178).isActive = true
        let configRow = NSStackView(views: [configLabel, configField])
        configRow.orientation = .horizontal
        configRow.alignment = .firstBaseline
        configRow.spacing = 8
        configField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        addFullWidth(configRow, to: stack)

        let buttons = NSStackView(views: [
            button("保存并启动", action: #selector(saveAndLaunch)),
            button("仅保存", action: #selector(saveOnly)),
            button("诊断 / Check", action: #selector(runDiagnostics)),
            button("日志与配置 / Files", action: #selector(showFiles))
        ])
        buttons.orientation = .horizontal
        buttons.spacing = 10
        stack.addArrangedSubview(buttons)

        let diagnosticLabel = label("本地诊断 / Local diagnostics（端口可连接不代表节点能访问 Google）")
        addFullWidth(diagnosticLabel, to: stack)
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        scroll.documentView = output
        output.isEditable = false
        output.isSelectable = true
        output.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        output.frame = NSRect(x: 0, y: 0, width: 760, height: 140)
        output.textContainerInset = NSSize(width: 8, height: 8)
        output.autoresizingMask = [.width]
        output.isVerticallyResizable = true
        output.isHorizontallyResizable = false
        output.textContainer?.widthTracksTextView = true
        scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 140).isActive = true
        scroll.setContentHuggingPriority(.defaultLow, for: .vertical)
        addFullWidth(scroll, to: stack)
        status.textColor = .secondaryLabelColor
        addFullWidth(status, to: stack)
        fields = [useProxy, autoDetect, proxyURL, appPath, clientPath, timeout]
    }

    private func label(_ text: String, size: CGFloat = 12, weight: NSFont.Weight = .regular, lines: Int = 1) -> NSTextField {
        let result = NSTextField(wrappingLabelWithString: text)
        result.font = .systemFont(ofSize: size, weight: weight)
        result.maximumNumberOfLines = lines
        result.setContentHuggingPriority(.required, for: .vertical)
        return result
    }

    private func addFullWidth(_ view: NSView, to stack: NSStackView) {
        stack.addArrangedSubview(view)
        view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    }

    private func fieldRow(_ text: String, field: NSTextField, browse: Selector? = nil) -> NSStackView {
        let name = label(text)
        name.widthAnchor.constraint(equalToConstant: 178).isActive = true
        field.usesSingleLineMode = true
        field.lineBreakMode = .byTruncatingMiddle
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let row = NSStackView(views: [name, field])
        row.orientation = .horizontal
        row.alignment = .firstBaseline
        row.spacing = 8
        if let action = browse {
            let browseButton = NSButton(title: "浏览…", target: self, action: action)
            browseButton.bezelStyle = .rounded
            browseButton.widthAnchor.constraint(equalToConstant: 76).isActive = true
            row.addArrangedSubview(browseButton)
            actionButtons.append(browseButton)
        }
        return row
    }

    private func button(_ title: String, action: Selector) -> NSButton {
        let result = NSButton(title: title, target: self, action: action)
        result.bezelStyle = .rounded
        actionButtons.append(result)
        return result
    }

    private func loadSettings() {
        var config = LauncherConfig()
        do { config = try ConfigStore.load() }
        catch {
            output.string = "无法读取配置 / Could not load settings:\n\(error.localizedDescription)\n\n当前显示默认值。点击保存才会替换配置；关闭窗口会保留原文件。"
            status.stringValue = "配置需要检查 / Review settings"
        }
        useProxy.state = config.useProxy ? .on : .off
        autoDetect.state = config.autoDetectProxy ? .on : .off
        proxyURL.stringValue = config.proxyURL
        appPath.stringValue = config.antigravityPath
        clientPath.stringValue = config.proxyClientPath
        timeout.stringValue = String(config.startupTimeoutSeconds)
        updateProxyControls()
    }

    private func readSettings() throws -> LauncherConfig {
        guard let seconds = Int(timeout.stringValue), (5...120).contains(seconds) else {
            throw NSError(domain: productName, code: 1, userInfo: [NSLocalizedDescriptionKey: "启动等待需为 5–120 的整数 / Timeout must be an integer between 5 and 120."])
        }
        var config = LauncherConfig()
        config.useProxy = useProxy.state == .on
        config.autoDetectProxy = autoDetect.state == .on
        config.proxyURL = proxyURL.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        config.antigravityPath = appPath.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        config.proxyClientPath = clientPath.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        config.startupTimeoutSeconds = seconds
        try ConfigStore.validate(config)
        return config
    }

    @objc private func updateProxyControls() {
        autoDetect.isEnabled = !busy && useProxy.state == .on
        proxyURL.isEnabled = !busy && useProxy.state == .on
        clientPath.isEnabled = !busy && useProxy.state == .on
    }

    func setBusy(_ value: Bool, message: String) {
        busy = value
        fields.forEach { $0.isEnabled = !value }
        actionButtons.forEach { $0.isEnabled = !value }
        updateProxyControls()
        status.stringValue = message
    }

    @objc private func saveOnly() {
        do {
            try ConfigStore.save(readSettings())
            status.stringValue = "已保存。下次双击即可启动 / Saved."
        } catch { showError(error) }
    }

    @objc private func saveAndLaunch() {
        do {
            let config = try readSettings()
            try ConfigStore.save(config)
            onLaunch?(config)
        } catch { showError(error) }
    }

    @objc private func runDiagnostics() {
        do {
            let config = try readSettings()
            setBusy(true, message: "正在检查本地配置和代理端口 / Checking…")
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let report = LauncherCore.diagnose(config)
                DispatchQueue.main.async {
                    self?.output.string = report
                    self?.setBusy(false, message: "诊断完成，未启动任何应用 / Diagnostics complete.")
                }
            }
        } catch { showError(error) }
    }

    @objc private func browseApplication() { browse(into: appPath, title: "选择 Antigravity.app") }
    @objc private func browseProxyClient() { browse(into: clientPath, title: "选择代理客户端 / Select proxy client") }

    private func browse(into field: NSTextField, title: String) {
        let panel = NSOpenPanel()
        panel.title = title
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.applicationBundle]
        panel.treatsFilePackagesAsDirectories = false
        if panel.runModal() == .OK, let url = panel.url { field.stringValue = url.path }
    }

    @objc private func showFiles() {
        do {
            let directory = ConfigStore.configURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            NSWorkspace.shared.open(directory)
        } catch { showError(error) }
    }

    func showError(_ error: Error) {
        ConfigStore.log("ERROR: \(error.localizedDescription)")
        output.string = error.localizedDescription
        status.stringValue = "请检查设置 / Review settings"
        let alert = NSAlert()
        alert.messageText = "\(productName) — 错误 / Error"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "好 / OK")
        if let window = window { alert.beginSheetModal(for: window) }
        else { alert.runModal() }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool { return !busy }

    func windowWillClose(_ notification: Notification) {
        NSApp.terminate(nil)
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
    private var settings: SettingsWindowController?
    private var progress: NSPanel?
    private var launching = false
    private let forceSettings: Bool

    init(forceSettings: Bool) { self.forceSettings = forceSettings }

    func applicationDidFinishLaunching(_ notification: Notification) {
        createMenu()
        if forceSettings || !ConfigStore.exists {
            showSettings()
            return
        }
        do { performLaunch(try ConfigStore.load()) }
        catch {
            showSettings()
            settings?.showError(error)
        }
    }

    private func createMenu() {
        let menu = NSMenu()
        let applicationItem = NSMenuItem()
        let applicationMenu = NSMenu(title: productName)
        let preferences = NSMenuItem(title: "设置… / Settings…", action: #selector(openSettings), keyEquivalent: ",")
        preferences.target = self
        applicationMenu.addItem(preferences)
        applicationMenu.addItem(.separator())
        applicationMenu.addItem(withTitle: "退出 / Quit \(productName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        applicationItem.submenu = applicationMenu
        menu.addItem(applicationItem)
        NSApp.mainMenu = menu
    }

    @objc private func openSettings() {
        if launching {
            settings?.window?.makeKeyAndOrderFront(nil)
            progress?.makeKeyAndOrderFront(nil)
        } else { showSettings() }
    }

    private func showSettings() {
        if settings == nil {
            settings = SettingsWindowController()
            settings?.onLaunch = { [weak self] config in self?.performLaunch(config) }
        }
        settings?.showWindow(nil)
        settings?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showProgress() {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 430, height: 105), styleMask: [.titled], backing: .buffered, defer: false)
        panel.title = productName
        let message = NSTextField(labelWithString: "正在检查代理并打开 Antigravity…\nChecking proxy and opening Antigravity…")
        message.frame = NSRect(x: 24, y: 39, width: 382, height: 42)
        panel.contentView?.addSubview(message)
        let indicator = NSProgressIndicator(frame: NSRect(x: 24, y: 18, width: 382, height: 14))
        indicator.style = .bar
        indicator.isIndeterminate = true
        indicator.startAnimation(nil)
        panel.contentView?.addSubview(indicator)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        progress = panel
    }

    private func performLaunch(_ config: LauncherConfig) {
        guard !launching else { return }
        launching = true
        if settings == nil { showProgress() }
        settings?.setBusy(true, message: "正在启动，等待应用就绪 / Starting Antigravity…")
        LauncherCore.launch(config) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.launching = false
                switch result {
                case .success:
                    NSApp.terminate(nil)
                case .failure(let error):
                    self.showSettings()
                    self.progress?.close()
                    self.progress = nil
                    self.settings?.setBusy(false, message: "启动失败 / Launch failed")
                    self.settings?.showError(error)
                }
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings()
        return false
    }
}

let arguments = Array(CommandLine.arguments.dropFirst())
switch arguments {
case ["--version"]:
    print("\(productName) \(productVersion)")
    exit(0)
case ["--help"], ["-h"]:
    print("""
    \(productName) \(productVersion)
    No arguments  First-run settings, or launch with saved settings.
    --settings    Open settings without starting Antigravity.
    --diagnose    Print local diagnostics without starting applications.
    --version     Print version.
    --help        Print help.
    Hold Option while opening the launcher to show settings.
    """)
    exit(0)
case ["--diagnose"]:
    do {
        print(LauncherCore.diagnose(try ConfigStore.load()))
        exit(0)
    } catch {
        writeError("Diagnostics failed: \(error.localizedDescription)")
        exit(1)
    }
case [], ["--settings"]:
    break
default:
    writeError("Unsupported arguments. Use --help for available options.")
    exit(2)
}

let application = NSApplication.shared
application.setActivationPolicy(.regular)
private let delegate = AppDelegate(forceSettings: arguments == ["--settings"] || NSEvent.modifierFlags.contains(.option))
application.delegate = delegate
application.run()
