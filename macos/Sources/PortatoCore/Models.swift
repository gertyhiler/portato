import Foundation

public struct TunnelStatus: Decodable {
    public let name: String
    public let type: String
    public let local: String
    public let remote: String
    public let state: String
    public let error: String?
    public let tags: [String]?
    public let pending_host: String?
    public let pending_passphrase: String?
    public let pending_password: String?

    public var authenticationHint: String? {
        if !(pending_host ?? "").isEmpty { return "Host key confirmation required — open TUI" }
        if !(pending_passphrase ?? "").isEmpty { return "Key passphrase required — open TUI" }
        if !(pending_password ?? "").isEmpty { return "SSH password required — open TUI" }
        return nil
    }

    public var isActive: Bool { ["connecting", "connected", "reconnecting"].contains(state) }
    public var browserURL: URL? {
        guard type == "local", state == "connected" else { return nil }
        var parts = URLComponents(string: "http://\(local)")
        guard let port = parts?.port, (1...65535).contains(port),
              let host = parts?.host, !host.isEmpty,
              parts?.user == nil, parts?.password == nil,
              parts?.query == nil, parts?.fragment == nil,
              parts?.path.isEmpty == true else { return nil }
        if ["0.0.0.0", "[::]", "::"].contains(host) { parts?.host = "localhost" }
        return parts?.url
    }
}

public enum TunnelAction: String { case enable, disable, restart }

public enum IPCError: Error, LocalizedError {
    case daemonUnavailable
    case message(String)
    public var allowsDaemonStart: Bool {
        if case .daemonUnavailable = self { return true }
        return false
    }
    public var errorDescription: String? {
        switch self {
        case .daemonUnavailable: return "Daemon unavailable. Start it with portato install or portato daemon."
        case .message(let text): return text
        }
    }
}

public struct DaemonLocation {
    public let socket: String
    public var tokenURL: URL {
        URL(fileURLWithPath: socket).deletingLastPathComponent().appendingPathComponent("portato.token")
    }

    public static func discover(environment: [String: String] = ProcessInfo.processInfo.environment,
                                home: URL = FileManager.default.homeDirectoryForCurrentUser) throws -> DaemonLocation {
        if let path = environment["PORTATO_SOCKET"], !path.isEmpty { return DaemonLocation(socket: path) }
        let config = environment["XDG_CONFIG_HOME"].flatMap { $0.isEmpty ? nil : $0 }
            .map { URL(fileURLWithPath: $0) } ?? home.appendingPathComponent("Library/Application Support")
        let markerURL = config.appendingPathComponent("portato/daemon.socket")
        if let data = try? Data(contentsOf: markerURL),
           let marker = try? JSONDecoder().decode(Marker.self, from: data),
           !marker.socket.isEmpty, marker.pid > 0 {
            let candidate = DaemonLocation(socket: marker.socket)
            do {
                _ = try HTTPResponse(location: candidate, method: "GET", path: "/healthz", timeout: 0.3)
                return candidate
            } catch {
                if (error as? IPCError)?.allowsDaemonStart != true { return candidate }
            }
        }
        let state = environment["XDG_STATE_HOME"].flatMap { $0.isEmpty ? nil : $0 }
            .map { URL(fileURLWithPath: $0) } ?? home.appendingPathComponent("Library/Application Support")
        return DaemonLocation(socket: state.appendingPathComponent("portato/portato-\(getuid()).sock").path)
    }

    public init(socket: String) { self.socket = socket }
    private struct Marker: Decodable { let socket: String; let pid: Int }
}

public struct DaemonInfo: Decodable {
    public let protocolVersion: Int
    public let configPath: String
    enum CodingKeys: String, CodingKey { case protocolVersion = "protocol", configPath = "config_path" }
}
