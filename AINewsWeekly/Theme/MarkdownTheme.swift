import SwiftUI
import MarkdownUI

// MarkdownUI theme — editorial cream, serif headings, monospace code blocks
// with off-white surface and amber border. Matches the design system in
// Theme/Colors.swift. Code blocks get a Copy affordance; that's wired up in
// LearnDetailView, not here (theming is purely visual).
extension Theme {
    static let inkEditorial = Theme()
        .text {
            ForegroundColor(.inkText)
            FontFamilyVariant(.normal)
            FontSize(.em(1.0))
            BackgroundColor(.clear)
        }
        .heading1 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontFamilyVariant(.normal)
                    FontSize(.em(1.5))
                    FontWeight(.semibold)
                    ForegroundColor(.inkText)
                }
                .padding(.bottom, 8)
        }
        .heading2 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontFamilyVariant(.normal)
                    FontSize(.em(1.25))
                    FontWeight(.semibold)
                    ForegroundColor(.inkText)
                }
                .padding(.top, 16)
                .padding(.bottom, 4)
        }
        .heading3 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.semibold)
                    ForegroundColor(.inkText)
                }
                .padding(.top, 8)
        }
        .paragraph { configuration in
            configuration.label
                .relativeLineSpacing(.em(0.25))
                .markdownMargin(top: 0, bottom: 16)
        }
        .listItem { configuration in
            configuration.label.markdownMargin(top: 4, bottom: 0)
        }
        .code {
            FontFamilyVariant(.monospaced)
            FontSize(.em(0.95))
            BackgroundColor(.inkCodeBg)
        }
        .codeBlock { configuration in
            configuration.label
                .relativeLineSpacing(.em(0.25))
                .markdownTextStyle {
                    FontFamilyVariant(.monospaced)
                    FontSize(.em(0.92))
                    ForegroundColor(.inkText)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.inkCodeBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.inkAmberSoft, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .markdownMargin(top: 8, bottom: 16)
        }
        .link { ForegroundColor(.inkAmber) }
}
