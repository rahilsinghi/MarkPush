import ComposableArchitecture
import SwiftUI

struct FeedView: View {
    @Bindable var store: StoreOf<FeedFeature>

    var body: some View {
        ZStack {
            Color.mpBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Custom header — replaces navigation bar to avoid iOS 26 system buttons.
                HStack {
                    Text("MarkPush")
                        .font(MPFont.appTitle)
                        .foregroundStyle(Color.mpTextPrimary)
                    Spacer()
                    ConnectionBadge(isConnected: store.isConnected)
                }
                .padding(.horizontal, MPSpacing.screenPadding)
                .padding(.vertical, MPSpacing.sm)

                if store.documents.isEmpty {
                    emptyState
                } else {
                    documentList
                }
            }
        }
        .navigationBarHidden(true)
        .task { store.send(.startReceiving) }
    }

    private var emptyState: some View {
        VStack(spacing: MPSpacing.lg) {
            Spacer()

            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundStyle(Color.mpTextTertiary)

            VStack(spacing: MPSpacing.sm) {
                Text("No Documents Yet")
                    .font(MPFont.cardTitle)
                    .foregroundStyle(Color.mpTextPrimary)

                Text("Push your first document from the terminal:")
                    .font(MPFont.body)
                    .foregroundStyle(Color.mpTextSecondary)

                Text("markpush push README.md")
                    .font(MPFont.code)
                    .foregroundStyle(Color.mpAccent)
                    .padding(.horizontal, MPSpacing.lg)
                    .padding(.vertical, MPSpacing.sm)
                    .background(Color.mpCodeBackground.opacity(0.1), in: RoundedRectangle(cornerRadius: MPSpacing.badgeRadius))
                    .padding(.top, MPSpacing.xs)
            }

            Spacer()
        }
    }

    private var documentList: some View {
        ScrollView {
            LazyVStack(spacing: MPSpacing.md) {
                ForEach(store.documents) { doc in
                    DocCard(document: doc)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            store.send(.documentTapped(doc.id))
                        }
                        .contextMenu {
                            Button(doc.isPinned ? "Unpin" : "Pin") {
                                store.send(.togglePin(doc.id))
                            }
                            Button("Archive", role: .destructive) {
                                store.send(.archiveDocument(doc.id))
                            }
                        }
                }
            }
            .padding(.horizontal, MPSpacing.screenPadding)
            .padding(.top, MPSpacing.sm)
        }
        .scrollIndicators(.hidden)
        .navigationDestination(item: $store.scope(state: \.reader, action: \.reader)) { readerStore in
            ReaderView(store: readerStore)
        }
    }
}

// MARK: - Connection Badge

struct ConnectionBadge: View {
    let isConnected: Bool

    var body: some View {
        HStack(spacing: MPSpacing.xs) {
            Circle()
                .fill(isConnected ? Color.mpConnected : Color.mpDisconnected)
                .frame(width: 8, height: 8)
            Text(isConnected ? "Connected" : "Disconnected")
                .font(MPFont.metadata)
                .foregroundStyle(Color.mpTextSecondary)
        }
        .padding(.horizontal, MPSpacing.sm)
        .padding(.vertical, MPSpacing.xs)
        .background(Color.mpSurface, in: Capsule())
        .accessibilityLabel(isConnected ? "Connected" : "Disconnected")
    }
}
