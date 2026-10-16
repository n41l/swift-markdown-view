import Foundation
import CoreGraphics

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Presentation-only marks; the text storage still contains the Markdown source.
enum MarkdownEditorBlockAttribute {
    static let list = NSAttributedString.Key("markdownEditorListBlock")
    static let quote = NSAttributedString.Key("markdownEditorQuoteBlock")
}

/// Draws list bullets and quote bars in the editable TextKit 2 surface.
/// Both decorations sit outside the selectable source text.
final class MarkdownEditorBlockFragment: NSTextLayoutFragment {
    var accent: PlatformColor?

    override var renderingSurfaceBounds: CGRect {
        var bounds = super.renderingSurfaceBounds
        guard let width = textLayoutManager?.textContainer?.size.width else { return bounds }
        bounds.origin.x = -layoutFragmentFrame.origin.x
        bounds.size.width = width
        return bounds
    }

    override func draw(at point: CGPoint, in context: CGContext) {
        super.draw(at: point, in: context)
        guard let accent,
              let storage = (textLayoutManager?.textContentManager as? NSTextContentStorage)?.textStorage,
              let content = textLayoutManager?.textContentManager as? NSTextContentStorage else { return }

        let offset = content.offset(from: content.documentRange.location, to: rangeInElement.location)
        guard offset != NSNotFound else { return }
        let left = point.x - layoutFragmentFrame.origin.x
        context.saveGState()
        defer { context.restoreGState() }
        context.setFillColor(accent.cgColor)

        for line in textLineFragments {
            let index = offset + line.characterRange.location
            guard index >= 0, index < storage.length else { continue }
            let bounds = line.typographicBounds
            let y = point.y + bounds.origin.y

            if storage.attribute(MarkdownEditorBlockAttribute.quote, at: index, effectiveRange: nil) != nil {
                context.fill(CGRect(x: left + 2, y: y, width: 2, height: bounds.height))
            }
            if line.characterRange.location == 0,
               storage.attribute(MarkdownEditorBlockAttribute.list, at: index, effectiveRange: nil) != nil {
                let bullet = CGRect(x: left + 5, y: y + (bounds.height - 4) / 2, width: 4, height: 4)
                context.fillEllipse(in: bullet)
            }
        }
    }
}

final class MarkdownEditorBlockFragmentProvider: NSObject, NSTextLayoutManagerDelegate {
    var accent: PlatformColor

    init(accent: PlatformColor) {
        self.accent = accent
    }

    func textLayoutManager(
        _ textLayoutManager: NSTextLayoutManager,
        textLayoutFragmentFor location: any NSTextLocation,
        in textElement: NSTextElement
    ) -> NSTextLayoutFragment {
        let fragment = MarkdownEditorBlockFragment(textElement: textElement, range: textElement.elementRange)
        fragment.accent = accent
        return fragment
    }
}
