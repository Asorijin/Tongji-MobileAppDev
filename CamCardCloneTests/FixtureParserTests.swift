import Foundation
import XCTest
#if canImport(CamCardDomain)
import CamCardDomain
#else
@testable import CamCardClone
#endif

/// T08：字段级准确率评价。把全部 40 张合成名片的 ocrText 交给解析器，
/// 与 fixtures 里的 groundTruth 逐字段比较，要求 100% 一致。
///
/// 数据集共 41 张：C01–C40 参与字段准确率评价；C41 为空白卡片（kind=exception），
/// 只用于 T20「无法识别」异常路径，不参与准确率统计。
///
/// 注意：这里的 ocrText 是脚本按"阅读顺序"合成的 OCR 输出，用于验证解析规则；
/// 真实 Vision 的识别结果由 T20 在模拟器上单独统计（见 docs/ocr-accuracy.md）。
final class FixtureParserTests: XCTestCase {
    private struct GroundTruth: Decodable {
        var name: String?
        var company: String?
        var jobTitle: String?
        var department: String?
        var address: String?
        var postalCode: String?
        var mobile: String?
        var officePhone: String?
        var fax: String?
        var email: String?
        var website: String?
    }

    private struct Fixture: Decodable {
        var id: String
        var kind: String
        var ocrText: String
        var groundTruth: GroundTruth
    }

    private func loadAllFixtures() throws -> [Fixture] {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // CamCardCloneTests
            .deletingLastPathComponent()   // 仓库根目录
        let directory = root.appendingPathComponent("docs/test-cards/fixtures")
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("C") && $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        XCTAssertEqual(files.count, 41, "数据集应为 41 张合成名片（40 张准确率 + 1 张空白异常卡）")
        return try files.map { try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: $0)) }
    }

    private func loadFixtures() throws -> [Fixture] {
        try loadAllFixtures().filter { $0.kind != "exception" }
    }

    func testAllFixturesMatchGroundTruth() throws {
        let parser = BusinessCardFieldParser()
        var failures: [String] = []

        let fixtures = try loadFixtures()
        XCTAssertEqual(fixtures.count, 40, "字段准确率测试集应为 40 张合成名片")

        for fixture in fixtures {
            let fields = parser.parse(fixture.ocrText)
            let gt = fixture.groundTruth
            func expect(_ label: String, _ got: String?, _ want: String?) {
                if got != want { failures.append("\(fixture.id) \(label): got \(got ?? "nil"), want \(want ?? "nil")") }
            }
            func expectArray(_ label: String, _ got: [String], _ want: String?) {
                let expected = want.map { [$0] } ?? []
                if got != expected { failures.append("\(fixture.id) \(label): got \(got), want \(expected)") }
            }
            expect("name", fields.name, gt.name)
            expect("company", fields.company, gt.company)
            expect("jobTitle", fields.jobTitle, gt.jobTitle)
            expect("department", fields.department, gt.department)
            expect("address", fields.address, gt.address)
            expect("postalCode", fields.postalCode, gt.postalCode)
            expectArray("mobile", fields.mobiles, gt.mobile)
            expectArray("officePhone", fields.officePhones, gt.officePhone)
            expectArray("fax", fields.faxes, gt.fax)
            expectArray("email", fields.emails, gt.email)
            expectArray("website", fields.websites, gt.website)
            // 确定性要求：已识别的行不允许残留（"Apple" 这类歧义行按设计保留为未分类，
            // 对应 Ground Truth 也不含该字段，因此这里只对完全匹配的卡片要求无残留）。
            if fields.unclassifiedLines.isEmpty == false {
                failures.append("\(fixture.id) unclassified: \(fields.unclassifiedLines)")
            }
        }

        XCTAssertTrue(failures.isEmpty, "字段级准确率未达 100%：\n" + failures.joined(separator: "\n"))
    }

    /// OCR/AI 的概率性与确定性边界：同一输入重复解析结果必须完全一致。
    func testEveryFixtureParsesDeterministically() throws {
        let parser = BusinessCardFieldParser()
        for fixture in try loadFixtures() {
            let first = parser.parse(fixture.ocrText)
            for _ in 0..<3 {
                XCTAssertEqual(parser.parse(fixture.ocrText), first, fixture.id)
            }
        }
    }

    /// C41 空白卡片：OCR 无文本 → 解析器不得凭空生成任何字段（作业 §8 AI 边界）。
    func testBlankCardProducesNoFields() throws {
        let all = try loadAllFixtures()
        let blank = try XCTUnwrap(all.first { $0.kind == "exception" }, "缺少空白异常卡片 C41")
        XCTAssertEqual(blank.ocrText, "")
        let fields = BusinessCardFieldParser().parse(blank.ocrText)
        XCTAssertFalse(fields.hasAnyField, "空白输入不应产生任何字段")
        XCTAssertTrue(fields.unclassifiedLines.isEmpty)
    }
}
