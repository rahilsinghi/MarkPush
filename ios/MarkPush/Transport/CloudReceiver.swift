import Foundation
import os
import Supabase

/// Receives push messages via the Supabase cloud relay.
/// Uses the authenticated SupabaseClient to subscribe to Realtime changes.
actor CloudReceiver {
    private let client: SupabaseClient
    private let userID: String
    private var continuation: AsyncStream<PushMessage>.Continuation?
    private nonisolated let logger = Logger(subsystem: "com.rahilsinghi.markpush", category: "Cloud")

    /// Stream of incoming push messages from the cloud relay.
    nonisolated let messages: AsyncStream<PushMessage>

    /// Create a CloudReceiver using the authenticated Supabase client.
    /// - Parameters:
    ///   - client: The shared SupabaseClient (must have an active auth session).
    ///   - userID: The authenticated user's Supabase UUID.
    init(client: SupabaseClient, userID: String) {
        self.client = client
        self.userID = userID
        var cont: AsyncStream<PushMessage>.Continuation?
        self.messages = AsyncStream { cont = $0 }
        self.continuation = cont
    }

    /// Subscribe to realtime changes on the pushes table for this user.
    func start() async throws {
        let channel = client.realtimeV2.channel("pushes:\(userID)")

        let changes = await channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "pushes",
            filter: .eq("user_id", value: userID)
        )

        try await channel.subscribeWithError()
        logger.info("Subscribed to pushes for user_id: \(self.userID, privacy: .public)")

        for await change in changes {
            guard let payload = change.record["payload"]?.stringValue else { continue }

            let decoder = JSONDecoder()
            // Handle Go's RFC3339Nano timestamps with fractional seconds.
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

            guard let data = payload.data(using: .utf8),
                  let message = try? decoder.decode(PushMessage.self, from: data) else { continue }

            // Mark as delivered.
            let deliveredAt = ISO8601DateFormatter().string(from: .now)
            _ = try? await client.from("pushes")
                .update(["delivered": "true", "delivered_at": deliveredAt])
                .eq("id", value: change.record["id"]?.stringValue ?? "")
                .execute()

            continuation?.yield(message)
        }
    }

    /// Stop receiving.
    func stop() {
        continuation?.finish()
    }
}
