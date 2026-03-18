import ComposableArchitecture
import Foundation

@Reducer
struct ReaderFeature {
    @ObservableState
    struct State: Equatable, Identifiable {
        let documentID: UUID
        var id: UUID { documentID }
        let title: String
        let content: String
        let wordCount: Int
        let source: String?
        let tags: [String]
        var isTOCVisible: Bool = false
        var fontSize: CGFloat = 17
        var scrollProgress: Double = 0
    }

    enum Action {
        case toggleTOC
        case setFontSize(CGFloat)
        case scrollProgressChanged(Double)
        case shareDocument
        case copyMarkdown
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .toggleTOC:
                state.isTOCVisible.toggle()
                return .none

            case .setFontSize(let size):
                state.fontSize = max(12, min(28, size))
                return .none

            case .scrollProgressChanged(let progress):
                state.scrollProgress = progress
                return .none

            case .shareDocument, .copyMarkdown:
                return .none
            }
        }
    }
}
