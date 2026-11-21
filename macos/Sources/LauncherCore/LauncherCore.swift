import AppKit
import Foundation
import Network
import SystemConfiguration

public struct LauncherConfig: Codable, Equatable {
    public var useProxy = true
    public var autoDetectProxy = true
    public var proxyURL = "http://127.0.0.1:10808"
    public var antigravityPath = ""
    public var proxyClientPath = ""
    public var startupTimeoutSeconds = 30

    public init() {}
}

public struct LauncherError: LocalizedError {
    public let message: String
    public var errorDescription: String? { message }
    public init(_ message: String) { self.message = message }
}

public enum ConfigStore {
    private static let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("AntigravityProxyLauncher", isDirectory: true)
    private static let logLock = NSLock()
    public static var configURL: URL { root.appendingPathComponent("config.json") }
    public static var logURL: URL { root.appendingPathComponent("launcher.log") }
    public static var exists: Bool { FileManager.default.fileExists(atPath: configURL.path) }

    public static func load() throws -> LauncherConfig {
        try load(from: configURL)
    }

    static func load(from url: URL) throws -> LauncherConfig {
        guard FileManager.default.fileExists(atPath: url.path) else { return LauncherConfig() }
        let config = try JSONDecoder().decode(LauncherConfig.self, from: Data(contentsOf: url))
        try validate(config)
        return config
    }

    public static func save(_ config: LauncherConfig) throws {
        try save(config, to: configURL)
    }

    static func save(_ config: LauncherConfig, to url: URL) throws {
        try validate(config)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    public static func validate(_ config: LauncherConfig) throws {
        guard (5...120).contains(config.startupTimeoutSeconds) else {
            throw LauncherError("启动等待必须为 5–120 秒。 / Startup timeout must be 5–120 seconds.")
        }
        for value in [config.proxyURL, config.antigravityPath, config.proxyClientPath] {
            guard !value.contains("\n"), !value.contains("\r"), !value.contains("\0") else {
                throw LauncherError("设置中不能包含换行或空字符。 / Settings must not contain newlines or null characters.")
            }
        }
        if !config.proxyURL.trimmingCharacters(in: .whitespaces).isEmpty {
            _ = try LauncherCore.parseProxy(config.proxyURL)
        } else if config.useProxy && !config.autoDetectProxy {
            throw LauncherError("请填写代理地址。 / Enter a proxy URL.")
        }
        if !config.antigravityPath.isEmpty {
            _ = try LauncherCore.validateApplication(config.antigravityPath, antigravityOnly: true)
        }
        if !config.proxyClientPath.isEmpty {
            _ = try LauncherCore.validateApplication(config.proxyClientPath, antigravityOnly: false)
        }
    }

    public static func log(_ message: String) {
        logLock.lock()
        defer { logLock.unlock() }
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            if let size = (try? FileManager.default.attributesOfItem(atPath: logURL.path)[.size]) as? NSNumber,
               size.intValue > 512 * 1024 {
                let previous = logURL.appendingPathExtension("previous")
                if FileManager.default.fileExists(atPath: previous.path) { try FileManager.default.removeItem(at: previous) }
                try FileManager.default.moveItem(at: logURL, to: previous)
            }
            let line = "[\(ISO8601DateFormatter().string(from: Date()))] \(message)\n"
            if !FileManager.default.fileExists(atPath: logURL.path) {
                try Data(line.utf8).write(to: logURL, options: .atomic)
            } else {
                let handle = try FileHandle(forWritingTo: logURL)
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: Data(line.utf8))
            }
        } catch { /* Logging must not prevent launching the application. */ }
    }
}

public enum LauncherCore {
    public static func findApplication(explicitPath: String) throws -> URL? {
        if !explicitPath.trimmingCharacters(in: .whitespaces).isEmpty {
            return try validateApplication(explicitPath, antigravityOnly: true)
        }
        var candidates = [
            URL(fileURLWithPath: "/Applications/Antigravity.app", isDirectory: true),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications/Antigravity.app", isDirectory: true)
        ]
        if let registered = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.google.antigravity") {
            candidates.append(registered)
        }
        for candidate in candidates {
            if let application = try? validateApplication(candidate.path, antigravityOnly: true) { return application }
        }
        return nil
    }

    static func validateApplication(_ value: String, antigravityOnly: Bool) throws -> URL {
        let path = (value.trimmingCharacters(in: .whitespaces) as NSString).expandingTildeInPath
        guard path.hasPrefix("/"), URL(fileURLWithPath: path).pathExtension.lowercased() == "app" else {
            throw LauncherError("请选择已安装的 .app 应用，不要选择 DMG 或 PKG 安装包。 / Choose an installed .app, not a DMG or PKG installer.")
        }
        let url = URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL.resolvingSymlinksInPath()
        guard let bundle = Bundle(url: url),
              bundle.infoDictionary?["CFBundlePackageType"] as? String == "APPL",
              let executable = bundle.executableURL,
              FileManager.default.isExecutableFile(atPath: executable.path) else {
            throw LauncherError("应用不存在或不是可运行的应用包。 / The selected application bundle is missing or invalid.")
        }
        if antigravityOnly && url.lastPathComponent.lowercased() != "antigravity.app"
            && bundle.bundleIdentifier != "com.google.antigravity" {
            throw LauncherError("请选择 Antigravity.app。 / Choose Antigravity.app.")
        }
        return url
    }

    public static func resolveProxy(_ config: LauncherConfig) throws -> String? {
        try ConfigStore.validate(config)
        guard config.useProxy else { return nil }
        if !config.autoDetectProxy {
            let url = try parseProxy(config.proxyURL)
            if isLocal(url) && !canConnect(url, allowRemote: false) { return nil }
            return normalizedProxy(url)
        }
        var candidates = [config.proxyURL]
        for key in ["HTTPS_PROXY", "HTTP_PROXY", "ALL_PROXY", "https_proxy", "http_proxy", "all_proxy"] {
            if let value = ProcessInfo.processInfo.environment[key] { candidates.append(value) }
        }
        candidates.append(contentsOf: systemProxies())
        candidates.append(contentsOf: [7890, 7897, 10808, 10809].map { "http://127.0.0.1:\($0)" })
        var seen = Set<String>()
        for candidate in candidates where seen.insert(candidate).inserted {
            guard let url = try? parseProxy(candidate), isLocal(url), canConnect(url, allowRemote: false) else { continue }
            return normalizedProxy(url)
        }
        return nil
    }

    public static func diagnose(_ config: LauncherConfig) -> String {
        var lines = [
            "Antigravity Proxy Launcher — macOS diagnostics",
            "Config: \(ConfigStore.configURL.path)",
            "Log: \(ConfigStore.logURL.path)",
            "No applications are started; no Google authentication or internet requests are performed."
        ]
        do {
            try ConfigStore.validate(config)
            lines.append("Antigravity: \(try findApplication(explicitPath: config.antigravityPath)?.path ?? "not found")")
            lines.append("Proxy mode: \(!config.useProxy ? "direct" : config.autoDetectProxy ? "auto (loopback only)" : "manual")")
            if let proxy = try resolveProxy(config) {
                lines.append("Proxy: \(proxy)")
                lines.append(isLocal(try parseProxy(proxy)) ? "Local TCP listener: reachable" : "Remote endpoint: not tested by diagnostics")
            } else if config.useProxy {
                lines.append("Proxy: no reachable local candidate")
            }
            lines.append("Proxy client: \(config.proxyClientPath.isEmpty ? "not configured" : config.proxyClientPath)")
            lines.append("TCP reachability does not prove HTTP/SOCKS support or access to Google.")
            lines.append("Already running apps cannot receive new environment variables; quit Antigravity before changing proxy settings.")
        } catch { lines.append("Error: \(error.localizedDescription)") }
        return lines.joined(separator: "\n")
    }

    public static func launch(_ config: LauncherConfig, completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try ConfigStore.validate(config)
                guard let application = try findApplication(explicitPath: config.antigravityPath) else {
                    throw LauncherError("未找到 Antigravity.app，请在设置中选择应用。 / Antigravity was not found; select it in Settings.")
                }
                var proxy = try resolveProxy(config)
                if config.useProxy && proxy == nil && !config.proxyClientPath.isEmpty {
                    try startProxyClient(config.proxyClientPath)
                    let deadline = Date().addingTimeInterval(20)
                    while proxy == nil && Date() < deadline {
                        Thread.sleep(forTimeInterval: 0.3)
                        proxy = try resolveProxy(config)
                    }
                }
                if config.useProxy && proxy == nil {
                    throw LauncherError("未找到可用代理，请打开代理客户端或修改地址。 / No reachable proxy was found; start your client or change the URL.")
                }
                if let proxy = proxy, !canConnect(try parseProxy(proxy), allowRemote: true) {
                    throw LauncherError("无法连接配置的代理服务器。 / The configured proxy cannot be reached.")
                }
                DispatchQueue.main.async { openApplication(application, config: config, proxy: proxy, completion: completion) }
            } catch {
                ConfigStore.log("ERROR: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    private static func openApplication(_ url: URL, config: LauncherConfig, proxy: String?, completion: @escaping (Result<Void, Error>) -> Void) {
        if let existing = NSWorkspace.shared.runningApplications.first(where: {
            !$0.isTerminated && $0.activationPolicy == .regular && $0.bundleURL?.resolvingSymlinksInPath() == url
        }) {
            let activated = existing.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
            ConfigStore.log("Existing application activated=\(activated). Its environment cannot be updated; quit it before changing proxies.")
            completion(.success(()))
            return
        }
        let options = NSWorkspace.OpenConfiguration()
        options.activates = true
        options.addsToRecentItems = false
        options.allowsRunningApplicationSubstitution = false
        options.environment = childEnvironment(config: config, proxy: proxy)
        let deadline = Date().addingTimeInterval(Double(config.startupTimeoutSeconds))
        var completed = false
        // This gate is used only on the main queue, including late Workspace callbacks.
        func finish(_ result: Result<Void, Error>) {
            guard !completed else { return }
            completed = true
            completion(result)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(config.startupTimeoutSeconds)) {
            finish(.failure(LauncherError("等待应用启动超时，后台进程未被终止。 / Application startup timed out; no processes were terminated.")))
        }
        ConfigStore.log("Starting Antigravity. Proxy mode=\(config.useProxy ? "enabled" : "direct").")
        NSWorkspace.shared.openApplication(at: url, configuration: options) { app, error in
            DispatchQueue.main.async {
                guard !completed else { return }
                if let error = error { finish(.failure(error)); return }
                guard let app = app else {
                    finish(.failure(LauncherError("macOS 未返回应用实例。 / macOS did not return a running application.")))
                    return
                }
                waitForApplication(app, deadline: deadline, completion: finish)
            }
        }
    }

    private static func waitForApplication(_ app: NSRunningApplication, deadline: Date, completion: @escaping (Result<Void, Error>) -> Void) {
        if app.isTerminated {
            completion(.failure(LauncherError("Antigravity 启动后退出，请检查应用日志。 / Antigravity exited during startup; check its logs.")))
        } else if app.isFinishedLaunching {
            let activated = app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
            ConfigStore.log("Application finished launching. PID=\(app.processIdentifier), activated=\(activated).")
            completion(.success(()))
        } else if Date() >= deadline {
            completion(.failure(LauncherError("等待应用启动超时，后台进程未被终止。 / Application startup timed out; no processes were terminated.")))
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { waitForApplication(app, deadline: deadline, completion: completion) }
        }
    }

    private static func startProxyClient(_ path: String) throws {
        let url = try validateApplication(path, antigravityOnly: false)
        let semaphore = DispatchSemaphore(value: 0)
        let lock = NSLock()
        var launchError: Error?
        DispatchQueue.main.async {
            let options = NSWorkspace.OpenConfiguration()
            options.activates = false
            NSWorkspace.shared.openApplication(at: url, configuration: options) { _, error in
                lock.lock(); launchError = error; lock.unlock()
                semaphore.signal()
            }
        }
        guard semaphore.wait(timeout: .now() + 20) == .success else {
            throw LauncherError("代理客户端启动超时。 / Proxy client startup timed out.")
        }
        lock.lock(); let error = launchError; lock.unlock()
        if let error = error { throw error }
    }

    static func childEnvironment(config: LauncherConfig, proxy: String?, base: [String: String] = ProcessInfo.processInfo.environment) -> [String: String] {
        var environment = base
        for key in Array(environment.keys) where ["http_proxy", "https_proxy", "all_proxy", "no_proxy", "electron_run_as_node"].contains(key.lowercased()) {
            environment.removeValue(forKey: key)
        }
        // LaunchServices may also inherit launchd values. Explicitly empty proxy overrides in direct mode.
        for key in ["HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "http_proxy", "https_proxy", "all_proxy"] {
            environment[key] = config.useProxy ? (proxy ?? "") : ""
        }
        environment["NO_PROXY"] = "localhost,127.0.0.1,::1,[::1]"
        environment["no_proxy"] = environment["NO_PROXY"]
        return environment
    }

    static func parseProxy(_ value: String) throws -> URL {
        let text = value.trimmingCharacters(in: .whitespaces)
        guard let parts = URLComponents(string: text),
              let scheme = parts.scheme?.lowercased(), ["http", "socks5", "socks5h"].contains(scheme),
              let host = parts.host, !host.isEmpty,
              let port = parts.port, (1...65535).contains(port),
              parts.user == nil, parts.password == nil, parts.query == nil, parts.fragment == nil,
              parts.path.isEmpty || parts.path == "/", let url = parts.url else {
            throw LauncherError("请使用 http://host:port 或 socks5://host:port，不含凭据或额外路径。 / Use a proxy URL without credentials or a path.")
        }
        return url
    }

    private static func normalizedProxy(_ url: URL) -> String {
        var result = url.absoluteString
        if result.hasSuffix("/") { result.removeLast() }
        return result
    }

    static func isLocal(_ url: URL) -> Bool {
        let host = (url.host ?? "").lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        if host == "localhost" || host == "::1" { return true }
        let components = host.split(separator: ".")
        return components.count == 4 && components[0] == "127" && components.allSatisfy { Int($0).map { (0...255).contains($0) } ?? false }
    }

    static func canConnect(_ url: URL, allowRemote: Bool) -> Bool {
        guard allowRemote || isLocal(url), let port = url.port, let endpointPort = NWEndpoint.Port(rawValue: UInt16(port)), let host = url.host else { return false }
        let endpointHost = host.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        let connection = NWConnection(host: NWEndpoint.Host(endpointHost), port: endpointPort, using: .tcp)
        let semaphore = DispatchSemaphore(value: 0)
        let lock = NSLock()
        var connected = false
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                lock.lock(); connected = true; lock.unlock()
                semaphore.signal()
            case .failed, .cancelled: semaphore.signal()
            default: break
            }
        }
        connection.start(queue: DispatchQueue.global(qos: .utility))
        _ = semaphore.wait(timeout: .now() + (isLocal(url) ? 0.3 : 1.5))
        connection.cancel()
        lock.lock(); defer { lock.unlock() }
        return connected
    }

    private static func systemProxies() -> [String] {
        guard let settings = SCDynamicStoreCopyProxies(nil) as? [String: Any] else { return [] }
        let protocols = [
            (kSCPropNetProxiesHTTPEnable as String, kSCPropNetProxiesHTTPProxy as String, kSCPropNetProxiesHTTPPort as String, "http"),
            (kSCPropNetProxiesHTTPSEnable as String, kSCPropNetProxiesHTTPSProxy as String, kSCPropNetProxiesHTTPSPort as String, "http"),
            (kSCPropNetProxiesSOCKSEnable as String, kSCPropNetProxiesSOCKSProxy as String, kSCPropNetProxiesSOCKSPort as String, "socks5")
        ]
        return protocols.compactMap { enabled, hostKey, portKey, scheme in
            guard (settings[enabled] as? NSNumber)?.boolValue == true,
                  let host = settings[hostKey] as? String, let port = settings[portKey] as? NSNumber else { return nil }
            let escapedHost = host.contains(":") && !host.hasPrefix("[") ? "[\(host)]" : host
            return "\(scheme)://\(escapedHost):\(port)"
        }
    }
}
