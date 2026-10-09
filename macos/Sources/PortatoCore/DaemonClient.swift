import Foundation

public struct DaemonClient {
    public let location: DaemonLocation
    public init(location: DaemonLocation) { self.location = location }

    public func list() throws -> [TunnelStatus] {
        let response = try HTTPResponse(location: location, method: "GET", path: "/tubers")
        try response.validate()
        return try JSONDecoder().decode([TunnelStatus]?.self, from: response.body()) ?? []
    }

    public func perform(_ action: TunnelAction, name: String) throws {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        guard !name.isEmpty, name.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            throw IPCError.message("Invalid tunnel name.")
        }
        let response = try HTTPResponse(location: location, method: "POST", path: "/tubers/\(name)/\(action.rawValue)")
        try response.validate()
        _ = try response.body()
    }

    public func info() throws -> DaemonInfo {
        let response = try HTTPResponse(location: location, method: "GET", path: "/info")
        if response.status == 404 { throw IPCError.message("Update the running Go daemon to the version bundled with this app, then restart it.") }
        try response.validate()
        let info = try JSONDecoder().decode(DaemonInfo.self, from: response.body())
        guard info.protocolVersion == 1 else { throw IPCError.message("This daemon uses an unsupported protocol. Update the app and Go core together.") }
        return info
    }

    public func configuration() throws -> [[String: Any]] {
        let response = try HTTPResponse(location: location, method: "GET", path: "/config")
        try response.validate()
        let object = try JSONSerialization.jsonObject(with: response.body()) as? [String: Any]
        return object?["tubers"] as? [[String: Any]] ?? []
    }

    public func saveTunnel(_ value: [String: Any], originalName: String?) throws {
        let path = try originalName.map { "/tubers/" + (try validName($0)) } ?? "/tubers"
        let response = try HTTPResponse(location: location, method: originalName == nil ? "POST" : "PUT",
                                        path: path, payload: JSONSerialization.data(withJSONObject: value))
        try response.validate()
        _ = try response.body()
    }

    public func deleteTunnel(name: String) throws {
        let response = try HTTPResponse(location: location, method: "DELETE", path: "/tubers/" + validName(name))
        try response.validate()
        _ = try response.body()
    }

    public func reload() throws {
        let response = try HTTPResponse(location: location, method: "POST", path: "/reload")
        try response.validate()
        _ = try response.body()
    }

    private func validName(_ name: String) throws -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        guard !name.isEmpty, name.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            throw IPCError.message("Invalid tunnel name.")
        }
        return name
    }

    public func events(onChange: () -> Void) throws {
        let response = try HTTPResponse(location: location, method: "GET", path: "/events", streaming: true)
        try response.validate()
        var pending = Data()
        while let chunk = try response.nextChunk() {
            pending.append(chunk)
            while let range = pending.range(of: Data("\n\n".utf8)) {
                let frame = String(decoding: pending.subdata(in: pending.startIndex..<range.lowerBound), as: UTF8.self)
                pending.removeSubrange(pending.startIndex..<range.upperBound)
                if frame.split(separator: "\n").contains(where: { $0.hasPrefix("data:") }) { onChange() }
            }
            guard pending.count < 65536 else { throw IPCError.message("Daemon event exceeds size limit.") }
        }
        throw IPCError.message("Daemon disconnected. Reconnecting…")
    }
}
