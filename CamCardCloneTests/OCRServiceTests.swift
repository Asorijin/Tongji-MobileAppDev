import XCTest
#if canImport(UIKit)
import UIKit
#endif
#if canImport(CamCardDomain)
import CamCardDomain
#else
@testable import CamCardClone
#endif

/// T07：OCR 产生原始文本。Vision 只能在 iOS 模拟器上运行；
/// Windows 下本文件编译为空，由 FieldParserTests / FixtureParserTests 覆盖后续环节。
final class OCRServiceTests: XCTestCase {
    #if canImport(UIKit)
    private func fixtureData(_ id: String) throws -> Data {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try Data(contentsOf: root.appendingPathComponent("docs/test-cards/images/\(id)_flat.png"))
    }

    func testVisionRecognizesSyntheticChineseCard() async throws {
        let data = try fixtureData("C01")
        let result = try await VisionOCRService().recognizeText(in: data, languages: ["zh-Hans", "en-US"])
        XCTAssertTrue(result.rawText.contains("朱宏明"), "原始文本：\(result.rawText)")
        XCTAssertTrue(result.rawText.contains("同济大学"))
        XCTAssertFalse(result.blocks.isEmpty)
    }

    /// OCR 输出必须能直接进入字段解析链路（端到端的最小闭环）。
    func testRecognizedTextFlowsIntoParser() async throws {
        let data = try fixtureData("C01")
        let rawText = try await VisionCardTextExtractor().extractText(from: data)
        let fields = BusinessCardFieldParser().parse(rawText)
        // Vision 的识别结果受字体渲染影响，这里断言核心字段而不是逐字符相等。
        XCTAssertEqual(fields.name, "朱宏明")
        XCTAssertEqual(fields.company, "同济大学")
        XCTAssertTrue(fields.mobiles.contains("138 0000 0001"))
    }

    func testUnreadableImageThrows() async {
        do {
            _ = try await VisionOCRService().recognizeText(in: Data([0x00]), languages: ["zh-Hans"])
            XCTFail("非图片数据应抛出错误")
        } catch {
            // 期望路径
        }
    }
    #endif
}
