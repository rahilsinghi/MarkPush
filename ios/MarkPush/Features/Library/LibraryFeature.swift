import ComposableArchitecture
import Foundation

@Reducer
struct LibraryFeature {
    @ObservableState
    struct State: Equatable {
        var searchQuery: String = ""
        var selectedFilter: Filter = .all
        var sortOrder: SortOrder = .newest

        enum Filter: String, CaseIterable, Equatable {
            case all = "All"
            case unread = "Unread"
            case pinned = "Pinned"
            case archived = "Archived"
        }

        enum SortOrder: String, CaseIterable, Equatable {
            case newest = "Newest"
            case oldest = "Oldest"
            case title = "Title"
        }
    }

    enum Action {
        case searchQueryChanged(String)
        case filterSelected(State.Filter)
        case sortOrderSelected(State.SortOrder)
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .searchQueryChanged(let query):
                state.searchQuery = query
                return .none

            case .filterSelected(let filter):
                state.selectedFilter = filter
                return .none

            case .sortOrderSelected(let order):
                state.sortOrder = order
                return .none
            }
        }
    }
}
