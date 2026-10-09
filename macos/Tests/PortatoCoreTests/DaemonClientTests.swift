import Foundation
import PortatoCore

final class DaemonClientTests {
    private var directory: URL!
    private var server: Process!
    private var location: DaemonLocation!

    func setUpWithError() throws {
        directory = URL(fileURLWithPath: "/tmp/portato-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        location = DaemonLocation(socket: directory.appendingPathComponent("ipc.sock").path)
        try String(repeating: "a", count: 64).write(to: location.tokenURL, atomically: true, encoding: .utf8)
        server = Process()
        server.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        let fixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Fixtures/daemon.js")
        server.arguments = ["bun", fixture.path, location.socket]
        try server.run()
        for _ in 0..<100 {
            if FileManager.default.fileExists(atPath: location.socket) { return }
            Thread.sleep(forTimeInterval: 0.02)
        }
        throw IPCError.message("Fixture failed to start")
    }

    func tearDownWithError() throws {
        if server?.isRunning == true { server.terminate(); server.waitUntilExit() }
        if let directory { try FileManager.default.removeItem(at: directory) }
    }

    func testConfigurationRoundTrip() throws {
        let client = DaemonClient(location: location)
        checkEqual(try client.info().protocolVersion, 1)
        checkEqual(try client.info().configPath, "/tmp/config.yaml")
        var value: [String: Any] = ["name": "editor-test", "type": "local", "local": "127.0.0.1:3200", "remote": "127.0.0.1:3000", "ssh": "host", "enabled": false, "tags": ["work"], "jump": "bastion"]
        try client.saveTunnel(value, originalName: nil)
        checkEqual(try client.configuration().first?["jump"] as? String, "bastion")
        value["local"] = "127.0.0.1:3201"
        try client.saveTunnel(value, originalName: "editor-test")
        checkEqual(try client.configuration().first?["local"] as? String, "127.0.0.1:3201")
        try client.reload()
        checkThrows(try client.deleteTunnel(name: "bad/name"))
        try client.deleteTunnel(name: "editor-test")
        checkEqual(try client.configuration().count, 0)
    }

    func testAuthenticatedActionsAndTokenRotation() throws {
        let client = DaemonClient(location: location)
        checkEqual(try client.list().first?.state, "off")
        try client.perform(.enable, name: "web")
        checkEqual(try client.list().first?.state, "connected")
        try String(repeating: "b", count: 64).write(to: location.tokenURL, atomically: true, encoding: .utf8)
        try client.perform(.restart, name: "web")
        try client.perform(.disable, name: "web")
        checkEqual(try client.list().first?.state, "off")
    }

    func testChunkedEventsAcrossFramesIgnoreHeartbeats() throws {
        var changes = 0
        checkThrows(try DaemonClient(location: location).events { changes += 1 })
        checkEqual(changes, 1)
    }

    func testErrorsAndUnsafeNames() throws {
        let client = DaemonClient(location: location)
        checkThrows(try client.perform(.enable, name: "missing")) { error in
            checkEqual(error.localizedDescription, "unknown tunnel")
        }
        checkThrows(try client.perform(.enable, name: "web/disable"))
        try "invalid\r\nHeader: value".write(to: location.tokenURL, atomically: true, encoding: .utf8)
        checkThrows(try client.list())
    }

    func testStaleMarkerFallsBackWithoutRemovingFiles() throws {
        let folder = directory.appendingPathComponent("portato")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let canonical = folder.appendingPathComponent("portato-\(getuid()).sock")
        try FileManager.default.createSymbolicLink(at: canonical, withDestinationURL: URL(fileURLWithPath: location.socket))
        try FileManager.default.copyItem(at: location.tokenURL, to: folder.appendingPathComponent("portato.token"))
        let markerURL = folder.appendingPathComponent("daemon.socket")
        let marker = try JSONSerialization.data(withJSONObject: ["socket": "/tmp/nonexistent-portato.sock", "pid": 123])
        try marker.write(to: markerURL)
        let discovered = try DaemonLocation.discover(environment: ["XDG_CONFIG_HOME": directory.path, "XDG_STATE_HOME": directory.path])
        checkEqual(discovered.socket, canonical.path)
        checkEqual(try DaemonClient(location: discovered).list().count, 1)
        checkEqual(try Data(contentsOf: markerURL), marker)
    }

    func testDiscoveryOverridesAndBrowserURLs() throws {
        let config = directory.appendingPathComponent("portato")
        try FileManager.default.createDirectory(at: config, withIntermediateDirectories: true)
        let marker = try JSONSerialization.data(withJSONObject: ["socket": location.socket, "pid": 123])
        try marker.write(to: config.appendingPathComponent("daemon.socket"))
        checkEqual(try DaemonLocation.discover(environment: ["XDG_CONFIG_HOME": directory.path]).socket, location.socket)
        checkEqual(try DaemonLocation.discover(environment: ["PORTATO_SOCKET": "/tmp/override.sock"]).socket, "/tmp/override.sock")
        let status = try JSONDecoder().decode(TunnelStatus.self, from: Data("{\"name\":\"web\",\"type\":\"local\",\"local\":\"0.0.0.0:3200\",\"remote\":\"127.0.0.1:3000\",\"state\":\"connected\"}".utf8))
        checkEqual(status.browserURL?.absoluteString, "http://localhost:3200")
    }

    func testStartupRequiresAbsentDaemon() throws {
        let missing = DaemonClient(location: DaemonLocation(socket: directory.appendingPathComponent("missing.sock").path))
        checkThrows(try missing.info()) { error in
            checkEqual((error as? IPCError)?.allowsDaemonStart, true)
        }
        let client = DaemonClient(location: location)
        let responses: [[String: Any]] = [
            ["status": 404, "body": ["error": "not found"]],
            ["status": 401, "body": ["error": "unauthorized"]],
            ["status": 200, "body": ["protocol": 2, "config_path": "/tmp/config.yaml"]],
            ["status": 200, "body": ["unexpected": true]]
        ]
        for response in responses {
            try JSONSerialization.data(withJSONObject: ["/info": response])
                .write(to: directory.appendingPathComponent("responses.json"))
            checkThrows(try client.info()) { error in
                checkEqual((error as? IPCError)?.allowsDaemonStart == true, false)
            }
        }
    }

    func testDiscoveryKeepsUnusableLiveDaemon() throws {
        let config = directory.appendingPathComponent("portato")
        try FileManager.default.createDirectory(at: config, withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: ["socket": location.socket, "pid": 123])
            .write(to: config.appendingPathComponent("daemon.socket"))
        try JSONSerialization.data(withJSONObject: ["/healthz": ["status": 401, "body": ["error": "unauthorized"]]])
            .write(to: directory.appendingPathComponent("responses.json"))
        checkEqual(try DaemonLocation.discover(environment: ["XDG_CONFIG_HOME": directory.path]).socket, location.socket)
        try "invalid-token".write(to: location.tokenURL, atomically: true, encoding: .utf8)
        checkEqual(try DaemonLocation.discover(environment: ["XDG_CONFIG_HOME": directory.path]).socket, location.socket)
    }
}
