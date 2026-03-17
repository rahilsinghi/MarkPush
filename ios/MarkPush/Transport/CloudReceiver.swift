import Foundation
import Supabase

/// Receives push messages via the Supabase cloud relay.
actor CloudReceiver {
    private let client: SupabaseClient
    private let deviceID: String
    private var continuation: AsyncStream<PushMessage>.Continuation?

    /// Stream of incoming push messages from the cloud relay.
    let messages: AsyncStream<PushMessage>

    init(supabaseURL: URL, supabaseKey: String, deviceID: String) {
        self.client = SupabaseClient(supabaseURL: supabaseURL, supabaseKey: supabaseKey)
        self.deviceID = deviceID
        var cont: AsyncStream<PushMessage>.Continuation?
        self.messages = AsyncStream { cont = $0 }
        self.continuation = cont
    }

    /// Subscribe to realtime changes on the pushes table.
    func start() async throws {
        let channel = client.realtimeV2.channel("pushes:\(deviceID)")

        let changes = await channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "pushes",
            filter: .eq("receiver_id", value: deviceID)
        )

        try await channel.subscribeWithError()

        for await change in changes {
            guard let payload = change.record["payload"]?.stringValue else { continue }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

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
