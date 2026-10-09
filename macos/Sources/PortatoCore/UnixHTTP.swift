import Foundation
import Network

final class UnixConnection {
    private let connection: NWConnection
    private let timeout: TimeInterval
    private var buffer = Data()

    init(socket: String, timeout: TimeInterval) throws {
        self.timeout = timeout
        connection = NWConnection(to: .unix(path: socket), using: .tcp)
        let ready = DispatchSemaphore(value: 0)
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready, .failed, .waiting, .cancelled: ready.signal()
            default: break
            }
        }
        connection.start(queue: DispatchQueue.global(qos: .utility))
        guard ready.wait(timeout: .now() + timeout) == .success, connection.state == .ready else {
            let state = connection.state
            connection.cancel()
            switch state {
            case .failed(let error), .waiting(let error):
                if case .posix(let code) = error, code == .ENOENT || code == .ECONNREFUSED {
                    throw IPCError.daemonUnavailable
                }
            default: break
            }
            throw IPCError.message("Could not connect to the daemon. Check its socket and permissions before restarting it.")
        }
        connection.stateUpdateHandler = nil
    }

    deinit { connection.cancel() }
    func cancel() { connection.cancel() }

    func send(_ data: Data) throws {
        let done = DispatchSemaphore(value: 0)
        var failure: NWError?
        connection.send(content: data, completion: .contentProcessed { error in
            failure = error
            done.signal()
        })
        guard done.wait(timeout: .now() + timeout) == .success, failure == nil else {
            throw IPCError.message("Could not send request to daemon.")
        }
    }

    private func receive() throws -> Data {
        let done = DispatchSemaphore(value: 0)
        var received = Data()
        var failed = false
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, _, error in
            received = data ?? Data()
            failed = error != nil
            done.signal()
        }
        guard done.wait(timeout: .now() + timeout) == .success else {
            connection.cancel()
            throw IPCError.message("Daemon response timed out.")
        }
        guard !failed else { throw IPCError.message("Daemon connection closed.") }
        return received
    }

    func read(until delimiter: Data, limit: Int = 65536) throws -> Data {
        while true {
            if let range = buffer.range(of: delimiter) {
                let result = buffer.subdata(in: buffer.startIndex..<range.lowerBound)
                buffer.removeSubrange(buffer.startIndex..<range.upperBound)
                return result
            }
            guard buffer.count < limit else { throw IPCError.message("Daemon response exceeds size limit.") }
            let data = try receive()
            guard !data.isEmpty else { throw IPCError.message("Incomplete daemon response.") }
            buffer.append(data)
        }
    }

    func read(count: Int) throws -> Data {
        guard count >= 0, count <= 4 * 1024 * 1024 else { throw IPCError.message("Invalid response size.") }
        while buffer.count < count {
            let data = try receive()
            guard !data.isEmpty else { throw IPCError.message("Incomplete daemon response.") }
            buffer.append(data)
        }
        let result = buffer.prefix(count)
        buffer.removeFirst(count)
        return Data(result)
    }

    func readToEnd() throws -> Data {
        var result = buffer
        buffer.removeAll()
        while true {
            let data = try receive()
            if data.isEmpty { return result }
            result.append(data)
            guard result.count <= 4 * 1024 * 1024 else { throw IPCError.message("Response too large.") }
        }
    }
}

final class HTTPResponse {
    let connection: UnixConnection
    let status: Int
    private let chunked: Bool
    private let contentLength: Int?
    private let crlf = Data("\r\n".utf8)

    init(location: DaemonLocation, method: String, path: String, streaming: Bool = false, payload: Data = Data(), timeout: TimeInterval? = nil) throws {
        connection = try UnixConnection(socket: location.socket, timeout: timeout ?? (streaming ? 25 : 5))
        var request = "\(method) \(path) HTTP/1.1\r\nHost: portato\r\nConnection: \(streaming ? "keep-alive" : "close")\r\n"
        if let token = try? String(contentsOf: location.tokenURL, encoding: .utf8) {
            let clean = token.trimmingCharacters(in: .whitespacesAndNewlines)
            guard clean.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }), clean.count == 64 else {
                throw IPCError.message("Invalid daemon authentication token.")
            }
            request += "Authorization: Bearer \(clean)\r\n"
        }
        if streaming { request += "Accept: text/event-stream\r\n" }
        request += "Content-Type: application/json\r\nContent-Length: \(payload.count)\r\n\r\n"
        try connection.send(Data(request.utf8) + payload)
        let header = try connection.read(until: Data("\r\n\r\n".utf8))
        guard let text = String(data: header, encoding: .utf8) else { throw IPCError.message("Invalid HTTP response.") }
        let lines = text.components(separatedBy: "\r\n")
        guard let first = lines.first, let code = Int(first.split(separator: " ").dropFirst().first ?? "") else {
            throw IPCError.message("Invalid HTTP status.")
        }
        status = code
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            let pair = line.split(separator: ":", maxSplits: 1)
            if pair.count == 2 { headers[pair[0].lowercased()] = pair[1].trimmingCharacters(in: .whitespaces) }
        }
        chunked = headers["transfer-encoding"]?.lowercased() == "chunked"
        contentLength = headers["content-length"].flatMap(Int.init)
    }

    func nextChunk() throws -> Data? {
        guard chunked else { throw IPCError.message("Expected chunked daemon event stream.") }
        let line = try connection.read(until: crlf)
        guard let text = String(data: line, encoding: .utf8),
              let size = Int(text.split(separator: ";").first ?? "", radix: 16), size >= 0 else {
            throw IPCError.message("Invalid HTTP chunk.")
        }
        if size == 0 { return nil }
        let data = try connection.read(count: size)
        guard try connection.read(count: 2) == crlf else { throw IPCError.message("Invalid HTTP chunk ending.") }
        return data
    }

    func body() throws -> Data {
        if chunked {
            var data = Data()
            while let chunk = try nextChunk() {
                data.append(chunk)
                guard data.count <= 4 * 1024 * 1024 else { throw IPCError.message("Response too large.") }
            }
            return data
        }
        if let count = contentLength { return try connection.read(count: count) }
        return try connection.readToEnd()
    }

    func validate() throws {
        guard (200...299).contains(status) else {
            if status == 401 { throw IPCError.message("Daemon authentication changed. Reconnecting…") }
            let data = try body()
            let decoded = try? JSONDecoder().decode(DaemonError.self, from: data)
            throw IPCError.message(decoded?.error ?? "Daemon returned HTTP \(status).")
        }
    }
    private struct DaemonError: Decodable { let error: String }
}
