import Foundation
import Network
import os

/// Receives push messages over local WiFi using Network.framework.
/// Advertises via Bonjour so the CLI can discover this device.
/// Uses raw TCP with JSON framing (length-prefixed messages).
actor WiFiReceiver {
    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private let deviceID: String
    private let port: NWEndpoint.Port = .any
    private var continuation: AsyncStream<PushMessage>.Continuation?
    private nonisolated let logger = Logger(subsystem: "com.rahilsinghi.markpush", category: "WiFi")

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

        let newListener = try NWListener(using: parameters, on: port)
        self.listener = newListener

        // Advertise via Bonjour.
        newListener.service = NWListener.Service(
            name: "MarkPush",
            type: "_markpush._tcp",
            domain: "local",
            txtRecord: NWTXTRecord(["id": deviceID, "v": "1"])
        )

        let log = logger
        newListener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                let actualPort = newListener.port?.rawValue ?? 0
                log.info("Listening on port \(actualPort)")
            case .failed(let error):
                log.error("Listener failed: \(error)")
            default:
                break
            }
        }

        newListener.newConnectionHandler = { [weak self] connection in
            Task { await self?.handleConnection(connection) }
        }

        newListener.start(queue: .global(qos: .userInitiated))
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

        let log = logger
        // Wait for the connection to be ready before receiving data.
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                log.info("Connection ready from \(String(describing: connection.endpoint))")
                Task { await self?.receiveData(on: connection) }
            case .failed(let error):
                log.error("Connection failed: \(error)")
            case .cancelled:
                log.debug("Connection cancelled")
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
                self.logger.error("Receive error: \(error)")
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
            logger.error("Failed to decode message (\(data.count) bytes)")
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
