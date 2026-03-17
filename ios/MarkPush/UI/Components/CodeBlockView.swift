import SwiftUI

/// Styled code block with copy button and language label.
struct CodeBlockView: View {
    let code: String
    let language: String?
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: language label + copy button
            HStack {
                if let language, !language.isEmpty {
                    Text(language)
                        .font(MPFont.codeSmall)
                        .foregroundStyle(Color.mpTextTertiary)
                }
                Spacer()
                Button {
                    UIPasteboard.general.string = code
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        copied = false
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 11))
                        Text(copied ? "Copied" : "Copy")
                            .font(MPFont.codeSmall)
                    }
                    .foregroundStyle(copied ? Color.mpConnected : Color.mpTextTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(copied ? "Copied to clipboard" : "Copy code")
            }
            .padding(.horizontal, MPSpacing.md)
            .padding(.vertical, MPSpacing.sm)

            // Code content
            Text(code)
                .font(MPFont.code)
                .foregroundStyle(Color(hex: 0xF0EFF4))
                .padding(.horizontal, MPSpacing.md)
                .padding(.bottom, MPSpacing.md)
                .textSelection(.enabled)
        }
        .background(Color.mpCodeBackground)
        .clipShape(RoundedRectangle(cornerRadius: MPSpacing.badgeRadius))
    }
}
