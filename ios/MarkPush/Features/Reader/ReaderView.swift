import ComposableArchitecture
import MarkdownUI
import SwiftUI

struct ReaderView: View {
    @Bindable var store: StoreOf<ReaderFeature>
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Reading progress bar
            ReadingProgressBar(progress: store.scrollProgress)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Document header
                    VStack(alignment: .leading, spacing: MPSpacing.sm) {
                        if let source = store.source {
                            SourceBadge(source: source)
                        }

                        Text(store.title)
                            .font(MPFont.readerH1)
                            .foregroundStyle(Color.mpTextPrimary)
                            .padding(.top, MPSpacing.xs)

                        HStack(spacing: MPSpacing.md) {
                            Label("\(max(1, store.wordCount / 200)) min read", systemImage: "clock")
                            Text("·")
                            Label("\(store.wordCount) words", systemImage: "text.word.spacing")
                        }
                        .font(MPFont.metadata)
                        .foregroundStyle(Color.mpTextTertiary)

                        if !store.tags.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: MPSpacing.xs) {
                                    ForEach(store.tags, id: \.self) { tag in
                                        TagPill(tag: tag)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, MPSpacing.screenPadding)
                    .padding(.top, MPSpacing.xl)
                    .padding(.bottom, MPSpacing.lg)

                    Divider()
                        .padding(.horizontal, MPSpacing.screenPadding)

                    // Markdown content
                    Markdown(store.content)
                        .markdownTheme(markpushTheme)
                        .padding(.horizontal, MPSpacing.screenPadding)
                        .padding(.top, MPSpacing.lg)
                        .padding(.bottom, 80)
                        .textSelection(.enabled)
                }
            }
            .scrollIndicators(.hidden)
        }
        .background(Color.mpBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { readerToolbar }
    }

    /// Custom MarkdownUI theme matching the MarkPush design palette.
    private var markpushTheme: MarkdownUI.Theme {
        .docC.text {
            ForegroundColor(Color.mpTextPrimary)
            FontSize(17)
        }
        .heading1 { configuration in
            configuration.label
                .markdownMargin(top: 24, bottom: 8)
                .markdownTextStyle {
                    FontSize(26)
                    FontWeight(.bold)
                    ForegroundColor(Color.mpTextPrimary)
                }
        }
        .heading2 { configuration in
            configuration.label
                .markdownMargin(top: 20, bottom: 6)
                .markdownTextStyle {
                    FontSize(22)
                    FontWeight(.bold)
                    ForegroundColor(Color.mpTextPrimary)
                }
        }
        .heading3 { configuration in
            configuration.label
                .markdownMargin(top: 16, bottom: 4)
                .markdownTextStyle {
                    FontSize(18)
                    FontWeight(.semibold)
                    ForegroundColor(Color.mpTextPrimary)
                }
        }
        .codeBlock { configuration in
            configuration.label
                .markdownTextStyle {
                    FontFamilyVariant(.monospaced)
                    FontSize(13.5)
                    ForegroundColor(Color(hex: 0xF0EFF4))
                }
                .padding(MPSpacing.md)
                .background(Color.mpCodeBackground)
                .clipShape(RoundedRectangle(cornerRadius: MPSpacing.badgeRadius))
                .markdownMargin(top: 8, bottom: 8)
        }
        .code {
            FontFamilyVariant(.monospaced)
            FontSize(14)
            ForegroundColor(Color.mpAccentSecondary)
            BackgroundColor(Color.mpCodeBackground.opacity(0.15))
        }
        .link {
            ForegroundColor(Color.mpAccent)
        }
        .blockquote { configuration in
            configuration.label
                .padding(.leading, MPSpacing.md)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(Color.mpAccent.opacity(0.4))
                        .frame(width: 3)
                }
                .markdownMargin(top: 8, bottom: 8)
        }
    }

    @ToolbarContentBuilder
    private var readerToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: MPSpacing.lg) {
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
