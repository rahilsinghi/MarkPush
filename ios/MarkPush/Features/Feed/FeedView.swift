import ComposableArchitecture
import SwiftUI

struct FeedView: View {
    @Bindable var store: StoreOf<FeedFeature>

    var body: some View {
        Group {
            if store.documents.isEmpty {
                emptyState
            } else {
                documentList
            }
        }
        .navigationTitle("MarkPush")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                ConnectionBadge(isConnected: store.isConnected)
            }
        }
        .task { store.send(.startReceiving) }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Documents Yet", systemImage: "doc.text")
        } description: {
            Text("Push your first document from the terminal:")
            Text("markpush push README.md")
                .font(.system(.body, design: .monospaced))
                .padding(.top, 4)
        }
    }

    private var documentList: some View {
        List {
            ForEach(store.documents) { doc in
                DocCard(document: doc)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button("Archive", role: .destructive) {
                            store.send(.archiveDocument(doc.id))
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button(doc.isPinned ? "Unpin" : "Pin") {
                            store.send(.togglePin(doc.id))
                        }
                        .tint(.orange)
                    }
                    .onTapGesture {
                        store.send(.markAsRead(doc.id))
                    }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Connection Badge

struct ConnectionBadge: View {
    let isConnected: Bool

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isConnected ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            Text(isConnected ? "Connected" : "Disconnected")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityLabel(isConnected ? "Connected" : "Disconnected")
    }
}
