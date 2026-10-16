import XCTest
import MarkdownModel
@testable import MarkdownAttributedKit

final class HeadingBadgeTests: XCTestCase {
    func testHeadingLevelIsDecorationNotCopiedText() {
        let content = MarkdownContent(parsing: "## 一段标题")
        let rendered = MarkdownAttributedBuilder().build(content)
        XCTAssertEqual(rendered.string, "一段标题")
        guard let decoration = rendered.attribute(
            NSAttributedString.Key("markdownBlockDecoration"), at: 0, effectiveRange: nil
        ) as? MarkdownBlockDecoration else {
            return XCTFail("Heading decoration was not attached")
        }
        XCTAssertEqual(decoration.kind, .heading(level: 2))
        let style = rendered.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertEqual(style?.tailIndent, -36)
    }
}
