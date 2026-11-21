import Darwin
import Foundation
import XCTest
@testable import LauncherCore

final class LauncherCoreTests: XCTestCase {
    func testDefaultsValidate() throws {
        try ConfigStore.validate(LauncherConfig())
    }

    func testProxyProtocolsAndIPv6() throws {
        for address in ["http://127.0.0.1:10808", "socks5://localhost:7890", "socks5h://[::1]:1080"] {
            XCTAssertNotNil(try LauncherCore.parseProxy(address).port)
        }
        XCTAssertTrue(LauncherCore.isLocal(try LauncherCore.parseProxy("http://[::1]:1080")))
        XCTAssertFalse(LauncherCore.isLocal(try LauncherCore.parseProxy("http://127.attacker.invalid:1080")))
    }

    func testRejectCredentialsAndInvalidURLs() {
        for address in ["localhost:10808", "https://localhost:8080", "file:///tmp/proxy", "http://user:secret@localhost:8080", "http://localhost:8080/api", "http://localhost:8080?q=x", "http://localhost:8080#x", "socks5://localhost", "http://localhost:0", "http://localhost:65536"] {
            XCTAssertThrowsError(try LauncherCore.parseProxy(address), address)
        }
    }

    func testValidationAndDirectModeStillRejectCredentials() {
        var config = LauncherConfig()
        config.startupTimeoutSeconds = 1
        XCTAssertThrowsError(try ConfigStore.validate(config))
        config = LauncherConfig()
        config.useProxy = false
        config.proxyURL = "http://user:secret@localhost:8080"
        XCTAssertThrowsError(try ConfigStore.validate(config))
        config.proxyURL = "http://localhost:8080\nUseProxy=false"
        XCTAssertThrowsError(try ConfigStore.validate(config))
    }

    func testChildEnvironmentIsolatedAndDirectModeClearsProxies() {
        let base = ["HTTPS_PROXY": "http://old.invalid:1234", "http_proxy": "http://old.invalid:1234", "ELECTRON_RUN_AS_NODE": "1", "KEEP_VALUE": "unchanged"]
        var config = LauncherConfig()
        var child = LauncherCore.childEnvironment(config: config, proxy: "http://127.0.0.1:15432", base: base)
        XCTAssertEqual(child["HTTPS_PROXY"], "http://127.0.0.1:15432")
        XCTAssertEqual(child["http_proxy"], "http://127.0.0.1:15432")
        XCTAssertNil(child["ELECTRON_RUN_AS_NODE"])
        XCTAssertEqual(child["KEEP_VALUE"], "unchanged")
        XCTAssertTrue(child["NO_PROXY"]?.contains("::1") ?? false)
        XCTAssertEqual(base["ELECTRON_RUN_AS_NODE"], "1")
        config.useProxy = false
        child = LauncherCore.childEnvironment(config: config, proxy: nil, base: base)
        XCTAssertEqual(child["HTTP_PROXY"], "")
        XCTAssertEqual(child["HTTPS_PROXY"], "")
        XCTAssertEqual(child["all_proxy"], "")
    }

    func testAtomicConfigRoundTripAndMalformedConfig() throws {
        let temporary = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temporary) }
        let path = temporary.appendingPathComponent("nested/config.json")
        XCTAssertEqual(try ConfigStore.load(from: path), LauncherConfig())
        var config = LauncherConfig()
        config.proxyURL = "socks5://127.0.0.1:7890"
        try ConfigStore.save(config, to: path)
        XCTAssertEqual(try ConfigStore.load(from: path), config)
        config.useProxy = false
        try ConfigStore.save(config, to: path)
        XCTAssertEqual(try ConfigStore.load(from: path), config)
        try Data("{bad json".utf8).write(to: path)
        XCTAssertThrowsError(try ConfigStore.load(from: path))
    }

    func testApplicationBundleWithSpacesAndInstallerRejection() throws {
        let temporary = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temporary) }
        let app = temporary.appendingPathComponent("folder with spaces/Antigravity.app")
        let contents = app.appendingPathComponent("Contents")
        let executable = contents.appendingPathComponent("MacOS/Antigravity")
        try FileManager.default.createDirectory(at: executable.deletingLastPathComponent(), withIntermediateDirectories: true)
        let plist: [String: Any] = ["CFBundleIdentifier": "test.launcher.antigravity", "CFBundleExecutable": "Antigravity", "CFBundlePackageType": "APPL"]
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0).write(to: contents.appendingPathComponent("Info.plist"))
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
        XCTAssertEqual(try LauncherCore.findApplication(explicitPath: app.path), app.standardizedFileURL.resolvingSymlinksInPath())
        XCTAssertThrowsError(try LauncherCore.findApplication(explicitPath: temporary.appendingPathComponent("Antigravity.dmg").path))
        XCTAssertThrowsError(try LauncherCore.findApplication(explicitPath: "/missing/Antigravity.app"))
    }

    func testLocalProxyListenerAndClosedManualPort() throws {
        let socketFD = socket(AF_INET, SOCK_STREAM, 0)
        XCTAssertGreaterThanOrEqual(socketFD, 0)
        guard socketFD >= 0 else { return }
        var socketIsOpen = true
        defer { if socketIsOpen { close(socketFD) } }
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = 0
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.bind(socketFD, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        }
        XCTAssertEqual(bound, 0)
        XCTAssertEqual(listen(socketFD, 8), 0)
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        _ = withUnsafeMutablePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(socketFD, $0, &length) }
        }
        let port = UInt16(bigEndian: address.sin_port)
        var config = LauncherConfig()
        config.autoDetectProxy = false
        config.proxyURL = "http://127.0.0.1:\(port)"
        XCTAssertEqual(try LauncherCore.resolveProxy(config), config.proxyURL)
        config.autoDetectProxy = true
        XCTAssertEqual(try LauncherCore.resolveProxy(config), config.proxyURL)
        close(socketFD)
        socketIsOpen = false
        config.autoDetectProxy = false
        XCTAssertNil(try LauncherCore.resolveProxy(config))
    }

    func testRemoteDiagnosticDoesNotConnect() {
        var config = LauncherConfig()
        config.autoDetectProxy = false
        config.proxyURL = "http://unresolvable.invalid:8080"
        XCTAssertTrue(LauncherCore.diagnose(config).contains("not tested by diagnostics"))
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("launcher-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
