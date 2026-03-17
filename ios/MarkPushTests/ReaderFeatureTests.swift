import ComposableArchitecture
import Foundation
import Testing

@testable import MarkPush

@MainActor
struct ReaderFeatureTests {
    private func makeState() -> ReaderFeature.State {
        ReaderFeature.State(
            documentID: UUID(),
            title: "Test Doc",
            content: "# Test\n\nHello world",
            wordCount: 3,
            source: "claude",
            tags: ["test"]
        )
    }

    @Test
    func toggleTOC() async {
        let store = TestStore(initialState: makeState()) {
            ReaderFeature()
        }

        await store.send(.toggleTOC) {
            $0.isTOCVisible = true
        }
        await store.send(.toggleTOC) {
            $0.isTOCVisible = false
        }
    }

    @Test
    func setFontSize() async {
        let store = TestStore(initialState: makeState()) {
            ReaderFeature()
        }

        await store.send(.setFontSize(22)) {
            $0.fontSize = 22
        }
    }

    @Test
    func fontSizeClamped() async {
        let store = TestStore(initialState: makeState()) {
            ReaderFeature()
        }

        await store.send(.setFontSize(5)) {
            $0.fontSize = 12 // min
        }

        await store.send(.setFontSize(50)) {
            $0.fontSize = 28 // max
        }
    }

    @Test
    func scrollProgress() async {
        let store = TestStore(initialState: makeState()) {
            ReaderFeature()
        }

        await store.send(.scrollProgressChanged(0.5)) {
            $0.scrollProgress = 0.5
        }
    }
}
