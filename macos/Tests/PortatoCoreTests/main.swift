import Foundation
import PortatoCore

func checkEqual<T: Equatable>(_ actual: T, _ expected: T, file: StaticString = #filePath, line: UInt = #line) {
    precondition(actual == expected, "Assertion failed at \(file):\(line): \(actual) != \(expected)")
}

func checkThrows<T>(_ expression: @autoclosure () throws -> T, verify: ((Error) -> Void)? = nil) {
    do {
        _ = try expression()
        fatalError("Expected an error")
    } catch { verify?(error) }
}

if CommandLine.arguments.contains("--real-daemon") {
    guard let socket = ProcessInfo.processInfo.environment["PORTATO_SOCKET"], socket.hasPrefix("/tmp/portato-smoke-") else {
        fatalError("Real-daemon checks require the isolated smoke socket")
    }
    let client = DaemonClient(location: DaemonLocation(socket: socket))
    let name = "native-editor-probe"
    do {
        checkEqual(try client.info().protocolVersion, 1)
        var value: [String: Any] = ["name": name, "type": "local", "ssh": "localhost", "local": "127.0.0.1:32191", "remote": "127.0.0.1:3000", "enabled": false, "tags": ["native-test"]]
        try client.saveTunnel(value, originalName: nil)
        defer { try? client.deleteTunnel(name: name) }
        value["remote"] = "127.0.0.1:3001"
        try client.saveTunnel(value, originalName: name)
        let saved = try client.configuration().first { $0["name"] as? String == name }
        checkEqual(saved?["remote"] as? String, "127.0.0.1:3001")
        checkEqual(saved?["tags"] as? [String], ["native-test"])
        var invalid = value
        invalid["type"] = "invalid"
        checkThrows(try client.saveTunnel(invalid, originalName: name))
        try client.reload()
        checkEqual(try client.configuration().first { $0["name"] as? String == name }?["remote"] as? String, "127.0.0.1:3001")
        try client.deleteTunnel(name: name)
        checkEqual(try client.configuration().contains { $0["name"] as? String == name }, false)
        print("PASS: native configuration CRUD, validation and persistence against Go daemon")
    } catch {
        fputs("Real daemon check failed: \(error)\n", stderr)
        exit(1)
    }
    exit(0)
}

let checks: [(String, (DaemonClientTests) throws -> Void)] = [
    ("configuration round trip", { try $0.testConfigurationRoundTrip() }),
    ("authenticated actions and token rotation", { try $0.testAuthenticatedActionsAndTokenRotation() }),
    ("chunked events and heartbeats", { try $0.testChunkedEventsAcrossFramesIgnoreHeartbeats() }),
    ("errors and unsafe names", { try $0.testErrorsAndUnsafeNames() }),
    ("stale marker fallback", { try $0.testStaleMarkerFallsBackWithoutRemovingFiles() }),
    ("startup requires absent daemon", { try $0.testStartupRequiresAbsentDaemon() }),
    ("discovery preserves unusable live daemon", { try $0.testDiscoveryKeepsUnusableLiveDaemon() }),
    ("discovery and browser URLs", { try $0.testDiscoveryOverridesAndBrowserURLs() })
]
for (name, check) in checks {
    let fixture = DaemonClientTests()
    do {
        try fixture.setUpWithError()
        defer { try? fixture.tearDownWithError() }
        try check(fixture)
        print("PASS: \(name)")
    } catch {
        try? fixture.tearDownWithError()
        fputs("FAIL: \(name): \(error.localizedDescription)\n", stderr)
        exit(1)
    }
}
print("All \(checks.count) IPC checks passed")
