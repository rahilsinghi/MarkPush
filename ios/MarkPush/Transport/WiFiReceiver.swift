import Foundation
import Network

/// Receives push messages over local WiFi using Network.framework.
/// Advertises via Bonjour so the CLI can discover this device.
/// Uses raw TCP with JSON framing (length-prefixed messages).
actor WiFiReceiver {
    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private let deviceID: String
    private let port: NWEndpoint.Port = 49152
    private var continuation: AsyncStream<PushMessage>.Continuation?

    /// Stream of incoming push messages.
    nonisolated let messages: AsyncStream<PushMessage>

    init(deviceID: String) {
        self.deviceID = deviceID
        var cont: AsyncStream<PushMessage>.Continuation?
        self.messages = AsyncStream { cont = $0 }
        self.continuation = cont
    }

    /// Start listening for incoming TCP connections.
    func start() throws {
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true

        listener = try NWListener(using: parameters, on: port)

        // Advertise via Bonjour.
        listener?.service = NWListener.Service(
            name: "MarkPush",
            type: "_markpush._tcp",
            domain: "local",
            txtRecord: NWTXTRecord(["id": deviceID, "v": "1"])
        )

        listener?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("[WiFi] Listening on port \(self?.port.rawValue ?? 0)")
            case .failed(let error):
                print("[WiFi] Listener failed: \(error)")
            default:
                break
            }
        }

        listener?.newConnectionHandler = { [weak self] connection in
            Task { await self?.handleConnection(connection) }
        }

        listener?.start(queue: .global(qos: .userInitiated))
    }

    /// Stop listening and close all connections.
    func stop() {
        listener?.cancel()
        listener = nil
        for connection in connections {
            connection.cancel()
        }
        connections.removeAll()
        continuation?.finish()
    }

    private func handleConnection(_ connection: NWConnection) {
        connections.append(connection)

        // Wait for the connection to be ready before receiving data.
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("[WiFi] Connection ready from \(connection.endpoint)")
                Task { await self?.receiveData(on: connection) }
            case .failed(let error):
                print("[WiFi] Connection failed: \(error)")
            case .cancelled:
                print("[WiFi] Connection cancelled")
            default:
                break
            }
        }

        connection.start(queue: .global(qos: .userInitiated))
    }

    private func receiveData(on connection: NWConnection) {
        // Read up to 1MB — enough for any markdown document.
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1_048_576) { [weak self] data, _, isComplete, error in
            guard let self else { return }

            if let data, !data.isEmpty {
                Task { await self.processData(data, connection: connection) }
            }

            if let error {
                print("[WiFi] Receive error: \(error)")
                return
            }

            if !isComplete {
                Task { await self.receiveData(on: connection) }
            }
        }
    }

    private func processData(_ data: Data, connection: NWConnection) {
        let decoder = JSONDecoder()
        // Go's json.Marshal uses RFC3339Nano (with fractional seconds).
        // Swift's .iso8601 doesn't handle fractional seconds, so use a custom strategy.
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)

            let fmt = ISO8601DateFormatter()
            fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fmt.date(from: str) { return date }

            fmt.formatOptions = [.withInternetDateTime]
            if let date = fmt.date(from: str) { return date }

            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Invalid date: \(str)")
        }

        guard let message = try? decoder.decode(PushMessage.self, from: data) else {
            print("[WiFi] Failed to decode message (\(data.count) bytes)")
            if let str = String(data: data, encoding: .utf8) {
                print("[WiFi] Raw data: \(str.prefix(200))")
            }
            return
        }

        // Send ack.
        let ack = AckMessage.received(for: message.id)
        if let ackData = try? JSONEncoder().encode(ack) {
            connection.send(content: ackData, completion: .contentProcessed { _ in })
        }

        continuation?.yield(message)
    }
}
