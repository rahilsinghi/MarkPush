import ComposableArchitecture
import Testing

@testable import MarkPush

@MainActor
struct LibraryFeatureTests {

    @Test
    func searchQueryChanged_updatesQuery() async {
        let store = TestStore(initialState: LibraryFeature.State()) {
            LibraryFeature()
        }

        await store.send(.searchQueryChanged("markdown")) {
            $0.searchQuery = "markdown"
        }
    }

    @Test
    func filterSelected_updatesFilter() async {
        let store = TestStore(initialState: LibraryFeature.State()) {
            LibraryFeature()
        }

        await store.send(.filterSelected(.unread)) {
            $0.selectedFilter = .unread
        }
    }

    @Test
    func filterSelected_cycleAllFilters() async {
        let store = TestStore(initialState: LibraryFeature.State()) {
            LibraryFeature()
        }

        await store.send(.filterSelected(.pinned)) {
            $0.selectedFilter = .pinned
        }

        await store.send(.filterSelected(.archived)) {
            $0.selectedFilter = .archived
        }

        await store.send(.filterSelected(.all)) {
            $0.selectedFilter = .all
        }
    }

    @Test
    func sortOrderSelected_updatesSortOrder() async {
        let store = TestStore(initialState: LibraryFeature.State()) {
            LibraryFeature()
        }

        await store.send(.sortOrderSelected(.oldest)) {
            $0.sortOrder = .oldest
        }
    }

    @Test
    func sortOrderSelected_cycleAllOrders() async {
        let store = TestStore(initialState: LibraryFeature.State()) {
            LibraryFeature()
        }

        await store.send(.sortOrderSelected(.title)) {
            $0.sortOrder = .title
        }

        await store.send(.sortOrderSelected(.newest)) {
            $0.sortOrder = .newest
        }
    }
}
