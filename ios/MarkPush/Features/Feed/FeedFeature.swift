import ComposableArchitecture
import Foundation

@Reducer
struct FeedFeature {
    @ObservableState
    struct State: Equatable {
        var documents: IdentifiedArrayOf<DocumentState> = []
        var isConnected: Bool = false
        var isReceiving: Bool = false
        @Presents var reader: ReaderFeature.State?
    }

    struct DocumentState: Equatable, Identifiable {
        let id: UUID
        let title: String
        let content: String
        let excerpt: String
        let source: String?
        let wordCount: Int
        let readingTimeMinutes: Int
        let tags: [String]
        let receivedAt: Date
        var isRead: Bool
        var isPinned: Bool
    }

    enum Action {
        case startReceiving
        case messageReceived(PushMessage)
        case documentDecrypted(DocumentState)
        case decryptionFailed(String)
        case documentTapped(UUID)
        case togglePin(UUID)
        case archiveDocument(UUID)
        case markAsRead(UUID)
        case stopReceiving
        case reader(PresentationAction<ReaderFeature.Action>)
    }

    @Dependency(\.markPushClient) var client
    @Dependency(\.persistenceClient) var persistence

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .startReceiving:
                guard !state.isReceiving else { return .none }
                state.isReceiving = true
                state.isConnected = true
                return .run { send in
                    let messages = await client.startReceiving()
                    for await message in messages {
                        await send(.messageReceived(message))
                    }
                }

            case .messageReceived(let message):
                return .run { send in
                    do {
                        let content = try await client.decryptContent(message)
                        let doc = DocumentState(
                            id: UUID(uuidString: message.id) ?? UUID(),
                            title: message.title,
                            content: content,
                            excerpt: extractExcerpt(from: content),
                            source: message.source,
                            wordCount: message.wordCount,
                            readingTimeMinutes: max(1, message.wordCount / 200),
                            tags: message.tags ?? [],
                            receivedAt: message.timestamp,
                            isRead: false,
                            isPinned: false
                        )
                        await send(.documentDecrypted(doc))
                    } catch {
                        await send(.decryptionFailed(error.localizedDescription))
                    }
                }

            case .documentDecrypted(let doc):
                state.documents.insert(doc, at: 0)
                // Persist to SwiftData for the Library.
                return .run { _ in
                    try? await persistence.saveDocument(
                        doc.id, doc.title, doc.content, doc.source,
                        doc.tags, doc.wordCount, "", doc.receivedAt
                    )
                }

            case .decryptionFailed:
                return .none

            case .documentTapped(let id):
                guard let doc = state.documents[id: id] else { return .none }
                state.documents[id: id]?.isRead = true
                state.reader = ReaderFeature.State(
                    documentID: doc.id,
                    title: doc.title,
                    content: doc.content,
                    wordCount: doc.wordCount,
                    source: doc.source,
                    tags: doc.tags
                )
                return .none

            case .togglePin(let id):
                state.documents[id: id]?.isPinned.toggle()
                return .none

            case .archiveDocument(let id):
                state.documents.remove(id: id)
                return .none

            case .markAsRead(let id):
                state.documents[id: id]?.isRead = true
                return .none

            case .stopReceiving:
                state.isReceiving = false
                state.isConnected = false
                return .run { _ in
                    await client.stopReceiving()
                }

            case .reader:
                return .none
            }
        }
        .ifLet(\.$reader, action: \.reader) {
            ReaderFeature()
        }
    }
}

private func extractExcerpt(from content: String) -> String {
    let lines = content.components(separatedBy: .newlines)
    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty && !trimmed.hasPrefix("#") {
            return String(trimmed.prefix(200))
        }
    }
    return ""
}
