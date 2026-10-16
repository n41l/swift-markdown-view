import XCTest
@testable import SwiftMarkdownEditorCore

final class MarkdownBlockStyleTests: XCTestCase {
    func testTouchInSecondParagraphOnlyChangesThatBlock() {
        let source = "第一段 😀\n\n第二段 **重点**"
        let offset = ("第一段 😀\n\n第二" as NSString).length
        let change = MarkdownBlockStyling.transform(source, atUTF16Offset: offset, to: .h2)
        XCTAssertEqual(change?.change.apply(to: source), "第一段 😀\n\n## 第二段 **重点**")
    }

    func testContiguousListChangesAsOneBlockAndPreservesText() {
        let source = "前文\n\n- 苹果\n- 香蕉\n\n后文"
        let offset = ("前文\n\n- 苹果\n- 香" as NSString).length
        let change = MarkdownBlockStyling.transform(source, atUTF16Offset: offset, to: .numberedList)
        XCTAssertEqual(change?.change.apply(to: source), "前文\n\n1. 苹果\n2. 香蕉\n\n后文")
    }

    func testCodeFenceTouchInsideBlankLineChangesWholeCodeBlock() {
        let source = "开头\n\n```swift\nlet x = 1\n\nprint(x)\n```\n\n结尾"
        let offset = ("开头\n\n```swift\nlet x = 1\n" as NSString).length
        let change = MarkdownBlockStyling.transform(source, atUTF16Offset: offset, to: .quote)
        XCTAssertEqual(change?.change.apply(to: source), "开头\n\n> let x = 1\n> \n> print(x)\n\n结尾")
    }

    func testCodeFenceGrowsPastBackticksInContent() {
        let source = "some ``` code"
        let change = MarkdownBlockStyling.transform(source, atUTF16Offset: 3, to: .code)
        XCTAssertEqual(change?.change.apply(to: source), "````\nsome ``` code\n````")
    }

    func testSameStyleDoesNothing() {
        XCTAssertNil(MarkdownBlockStyling.transform("# 标题", atUTF16Offset: 3, to: .h1))
    }
}
