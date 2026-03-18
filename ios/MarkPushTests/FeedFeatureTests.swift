import ComposableArchitecture
import Foundation
import Testing

@testable import MarkPush

@MainActor
struct FeedFeatureTests {
    @Test
    func togglePin() async {
        let docState = FeedFeature.DocumentState(
            id: UUID(),
            title: "Test",
            content: "# Test\nTest excerpt",
            excerpt: "Test excerpt",
            source: "claude",
            wordCount: 100,
            readingTimeMinutes: 1,
            tags: ["test"],
            receivedAt: .now,
            isRead: false,
            isPinned: false
        )

        let store = TestStore(
            initialState: FeedFeature.State(documents: [docState])
        ) {
            FeedFeature()
        }

        await store.send(.togglePin(docState.id)) {
            $0.documents[id: docState.id]?.isPinned = true
        }

        await store.send(.togglePin(docState.id)) {
            $0.documents[id: docState.id]?.isPinned = false
        }
    }

    @Test
    func archiveDocument() async {
        let docState = FeedFeature.DocumentState(
            id: UUID(),
            title: "Test",
            content: "# Test",
            excerpt: "",
            source: nil,
            wordCount: 50,
            readingTimeMinutes: 1,
            tags: [],
            receivedAt: .now,
            isRead: false,
            isPinned: false
        )

        let store = TestStore(
            initialState: FeedFeature.State(documents: [docState])
        ) {
            FeedFeature()
        }

        await store.send(.archiveDocument(docState.id)) {
            $0.documents.remove(id: docState.id)
        }
    }

    @Test
    func markAsRead() async {
        let docState = FeedFeature.DocumentState(
            id: UUID(),
            title: "Test",
            content: "# Test",
            excerpt: "",
            source: nil,
            wordCount: 50,
            readingTimeMinutes: 1,
            tags: [],
            receivedAt: .now,
            isRead: false,
            isPinned: false
        )

        let store = TestStore(
            initialState: FeedFeature.State(documents: [docState])
        ) {
            FeedFeature()
        }

        await store.send(.markAsRead(docState.id)) {
            $0.documents[id: docState.id]?.isRead = true
        }
    }
}
