import ComposableArchitecture
import MarkdownUI
import SwiftUI

struct ReaderView: View {
    @Bindable var store: StoreOf<ReaderFeature>
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Document header
                VStack(alignment: .leading, spacing: 8) {
                    if let source = store.source {
                        SourceBadge(source: source)
                    }
                    Text(store.title)
                        .font(.system(.largeTitle, design: .serif, weight: .bold))

                    HStack(spacing: 12) {
                        Label("\(max(1, store.wordCount / 200)) min read", systemImage: "clock")
                        Label("\(store.wordCount) words", systemImage: "text.word.spacing")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    if !store.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(store.tags, id: \.self) { tag in
                                    TagPill(tag: tag)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

                Divider()
                    .padding(.horizontal, 20)

                // Markdown content
                Markdown(store.content)
                    .markdownTheme(.docC)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 60)
                    .textSelection(.enabled)
            }
        }
        .scrollIndicators(.hidden)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { readerToolbar }
    }

    @ToolbarContentBuilder
    private var readerToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: 16) {
                Button { store.send(.toggleTOC) } label: {
                    Image(systemName: "list.bullet")
                }
                .accessibilityLabel("Table of contents")

                Menu {
                    Button("Copy Markdown") { store.send(.copyMarkdown) }
                    Button("Share") { store.send(.shareDocument) }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share options")
            }
        }
    }
}
