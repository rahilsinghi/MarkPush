import ComposableArchitecture
import SwiftData
import SwiftUI

struct LibraryView: View {
    @Bindable var store: StoreOf<LibraryFeature>
    @Query(sort: \MarkDocument.receivedAt, order: .reverse) private var documents: [MarkDocument]

    var body: some View {
        List {
            if filteredDocuments.isEmpty {
                ContentUnavailableView.search(text: store.searchQuery)
            } else {
                ForEach(filteredDocuments) { doc in
                    LibraryRow(document: doc)
                }
            }
        }
        .listStyle(.plain)
        .searchable(text: $store.searchQuery.sending(\.searchQueryChanged), prompt: "Search documents")
        .navigationTitle("Library")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Picker("Filter", selection: $store.selectedFilter.sending(\.filterSelected)) {
                        ForEach(LibraryFeature.State.Filter.allCases, id: \.self) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    Picker("Sort", selection: $store.sortOrder.sending(\.sortOrderSelected)) {
                        ForEach(LibraryFeature.State.SortOrder.allCases, id: \.self) { order in
                            Text(order.rawValue).tag(order)
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
                .accessibilityLabel("Filter and sort")
            }
        }
    }

    private var filteredDocuments: [MarkDocument] {
        var result = documents

        switch store.selectedFilter {
        case .all:
            result = result.filter { !$0.isArchived }
        case .unread:
            result = result.filter { !$0.isRead && !$0.isArchived }
        case .pinned:
            result = result.filter { $0.isPinned }
        case .archived:
            result = result.filter { $0.isArchived }
        }

        if !store.searchQuery.isEmpty {
            let query = store.searchQuery.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(query) ||
                $0.content.lowercased().contains(query) ||
                $0.tags.contains(where: { $0.lowercased().contains(query) })
            }
        }

        return result
    }
}

struct LibraryRow: View {
    let document: MarkDocument

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(document.title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                if document.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Text(document.excerpt)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack {
                Text(document.receivedAt, style: .relative)
                Text("·")
                Text("\(document.readingTimeMinutes) min read")
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}
