import Foundation
import XCTest
#if canImport(UIKit)
import UIKit
#endif
#if canImport(CamCardDomain)
import CamCardDomain
#else
@testable import CamCardClone
#endif

/// B 层（端到端）评价：Vision OCR → 字段解析器 → 与 Ground Truth 逐字段比较。
///
/// A 层（FixtureParserTests）验证的是「给定正确 OCR 文本时的解析规则」，是确定性的、100% 的验收门槛；
/// 本用例验证的是「Vision 真实识别 + 解析」的端到端能力，属于概率性评价（作业 §5），
/// 只对「虚构字段 = 0」（§8 硬约束）与「40 张全部完成识别」做断言，
/// 其余指标（字段准确率、召回、名片级全对率）写入报告并打印，不在测试里设阈值——
/// 概率性结果不能用一张固定的及格线掩盖真实表现。
///
/// 产出（每次运行覆盖，CI 以工件保存）：
/// - build/ocr-accuracy-report.md   人读：汇总 + 错误明细 + 原始 OCR 文本
/// - build/ocr-accuracy-report.json 机读：每张名片的原始输出、解析字段、Ground Truth、逐字段判定
///
/// 仅在 iOS 模拟器 / 真机上运行（Vision）；Windows 上编译为空。
final class VisionAccuracyTests: XCTestCase {
    #if canImport(UIKit)
    private static let fieldOrder = [
        "name", "company", "jobTitle", "department", "address", "postalCode",
        "mobile", "officePhone", "fax", "email", "website",
    ]

    private struct GroundTruthCard: Decodable {
        var name, company, jobTitle, department, address, postalCode: String?
        var mobile, officePhone, fax, email, website: String?
    }

    private struct FixtureMeta: Decodable {
        struct Images: Decodable { var flat: String }
        var id: String
        var kind: String
        var layoutText: [String]?
        var images: Images?
    }

    private struct EvaluatedCard {
        var id: String
        var truth: [String: [String]]
        var layoutText: [String]
        var flatImagePath: String
    }

    private var repoRoot: URL {
        // 从本文件的编译期路径向上找包含数据集标记的目录，兼容绝对路径与相对路径两种编译方式。
        var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<6 {
            if FileManager.default.fileExists(atPath: directory.appendingPathComponent("docs/test-cards/ground-truth.json").path) {
                return directory
            }
            directory = directory.deletingLastPathComponent()
        }
        return URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // CamCardCloneTests
            .deletingLastPathComponent()   // 仓库根目录
    }

    private var runtimeDescription: String {
        let environment = ProcessInfo.processInfo.environment
        let model = environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "真机"
        return "\(model) / \(ProcessInfo.processInfo.operatingSystemVersionString)"
    }

    /// 40 张参与评价的名片（C41 为空白异常卡，不参与），按 id 排序，便于逐张对照。
    private func loadEvaluatedCards() throws -> [EvaluatedCard] {
        let fixtureDir = repoRoot.appendingPathComponent("docs/test-cards/fixtures")
        let files = try FileManager.default.contentsOfDirectory(at: fixtureDir, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("C") && $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        let truthURL = repoRoot.appendingPathComponent("docs/test-cards/ground-truth.json")
        let truth = try JSONDecoder().decode([String: GroundTruthCard].self, from: Data(contentsOf: truthURL))

        var cards: [EvaluatedCard] = []
        for file in files {
            let meta = try JSONDecoder().decode(FixtureMeta.self, from: Data(contentsOf: file))
            guard meta.kind != "exception", let card = truth[meta.id] else { continue }
            var values: [String: [String]] = [:]
            func put(_ field: String, _ value: String?) { values[field] = value.map { [$0] } ?? [] }
            put("name", card.name)
            put("company", card.company)
            put("jobTitle", card.jobTitle)
            put("department", card.department)
            put("address", card.address)
            put("postalCode", card.postalCode)
            put("mobile", card.mobile)
            put("officePhone", card.officePhone)
            put("fax", card.fax)
            put("email", card.email)
            put("website", card.website)
            cards.append(EvaluatedCard(
                id: meta.id,
                truth: values,
                layoutText: meta.layoutText ?? [],
                flatImagePath: meta.images?.flat ?? "docs/test-cards/images/\(meta.id)_flat.png"
            ))
        }
        return cards
    }

    private func parsedValues(_ fields: ParsedContactFields) -> [String: [String]] {
        [
            "name": fields.name.map { [$0] } ?? [],
            "company": fields.company.map { [$0] } ?? [],
            "jobTitle": fields.jobTitle.map { [$0] } ?? [],
            "department": fields.department.map { [$0] } ?? [],
            "address": fields.address.map { [$0] } ?? [],
            "postalCode": fields.postalCode.map { [$0] } ?? [],
            "mobile": fields.mobiles,
            "officePhone": fields.officePhones,
            "fax": fields.faxes,
            "email": fields.emails,
            "website": fields.websites,
        ]
    }

    /// 判定：nil 期望但识别出值 = 虚构（§8 禁止）；期望有值但为空 = 漏提；值不同 = 取值错误。
    /// 「错位」是取值错误的子类：识别出的值恰好出现在同一名片的另一个字段的 Ground Truth 里
    /// （例如公司名进了 name），错误分析时单列。§3.1 的「可选字段缺失」也单独统计。
    private enum Verdict: String {
        case ok = "正确"
        case missing = "漏提"
        case wrong = "取值错误"
        case fabricated = "虚构"
    }

    private static let optionalFields: Set<String> = ["department", "fax", "postalCode"]

    private func judge(expected: [String], got: [String]) -> Verdict {
        if expected == got { return .ok }
        if expected.isEmpty { return .fabricated }
        if got.isEmpty { return .missing }
        return .wrong
    }

    /// 识别值是否出现在本名片其他字段的 Ground Truth 中（即「放错了字段」）。
    private func isMisplaced(value: [String], field: String, in truth: [String: [String]]) -> Bool {
        guard !value.isEmpty else { return false }
        return truth.contains { otherField, otherValues in
            otherField != field && value.contains { otherValues.contains($0) }
        }
    }

    func testEndToEndVisionAccuracyReport() async throws {
        let cards = try loadEvaluatedCards()
        XCTAssertEqual(cards.count, 40, "B 层应评价 40 张名片（C41 空白卡不参与）")

        let service = VisionOCRService()
        let parser = BusinessCardFieldParser()

        var totalChecks = 0
        var correctChecks = 0
        var presentChecks = 0
        var presentCorrect = 0
        var absentChecks = 0
        var absentCorrect = 0
        var fabricated = 0
        var missed = 0
        var wrong = 0
        var misplaced = 0
        var optionalMissed = 0
        var allCorrectCards = 0
        var processedCards = 0
        var fabricatedDetails: [String] = []

        var cardReports: [[String: Any]] = []
        var tableRows: [String] = []
        var errorDetails: [String] = []

        for card in cards {
            let imageURL = repoRoot.appendingPathComponent(card.flatImagePath)
            let imageData = try Data(contentsOf: imageURL)

            var report: [String: Any] = ["id": card.id, "source": card.layoutText]
            do {
                let ocr = try await service.recognizeText(in: imageData, languages: ["zh-Hans", "en-US"])
                processedCards += 1
                let fields = parser.parse(ocr.rawText)
                let got = parsedValues(fields)

                var cardCorrect = 0
                var cardMissed = 0
                var cardWrong = 0
                var cardFabricated = 0
                var fieldReports: [[String: Any]] = []

                for field in Self.fieldOrder {
                    let expected = card.truth[field] ?? []
                    let actual = got[field] ?? []
                    let verdict = judge(expected: expected, got: actual)

                    totalChecks += 1
                    if !expected.isEmpty {
                        presentChecks += 1
                        if verdict == .ok { presentCorrect += 1 }
                    } else {
                        absentChecks += 1
                        if verdict == .ok { absentCorrect += 1 }
                    }

                    switch verdict {
                    case .ok:
                        correctChecks += 1
                        cardCorrect += 1
                    case .missing:
                        missed += 1
                        cardMissed += 1
                        if Self.optionalFields.contains(field) { optionalMissed += 1 }
                    case .wrong:
                        wrong += 1
                        cardWrong += 1
                        if isMisplaced(value: actual, field: field, in: card.truth) { misplaced += 1 }
                    case .fabricated:
                        fabricated += 1
                        cardFabricated += 1
                        fabricatedDetails.append("\(card.id) \(field): 识别出 \(actual.joined(separator: " / "))，名片上无该字段")
                    }

                    if verdict != .ok {
                        errorDetails.append(
                            "| \(card.id) | \(field) | \(card.truth[field]?.joined(separator: " / ") ?? "（无）") | "
                                + "\(actual.isEmpty ? "（空）" : actual.joined(separator: " / ")) | \(verdict.rawValue) |"
                        )
                    }
                    fieldReports.append([
                        "field": field,
                        "expected": expected,
                        "got": actual,
                        "verdict": verdict.rawValue,
                    ])
                }

                if cardCorrect == Self.fieldOrder.count { allCorrectCards += 1 }

                let confidence = ocr.blocks.isEmpty
                    ? 0
                    : ocr.blocks.map(\.confidence).reduce(0, +) / Float(ocr.blocks.count)

                report["rawOCRText"] = ocr.rawText
                report["blockCount"] = ocr.blocks.count
                report["averageConfidence"] = Double(confidence)
                report["parsed"] = got
                report["groundTruth"] = card.truth
                report["unclassifiedLines"] = fields.unclassifiedLines
                report["fields"] = fieldReports
                report["cardCorrectFields"] = cardCorrect

                tableRows.append(
                    "| \(card.id) | \(cardCorrect)/\(Self.fieldOrder.count) | \(cardMissed) | \(cardWrong) | "
                        + "\(cardFabricated) | \(String(format: "%.2f", confidence)) | \(fields.unclassifiedLines.count) |"
                )
            } catch {
                report["error"] = error.localizedDescription
                tableRows.append("| \(card.id) | 0/\(Self.fieldOrder.count) | \(Self.fieldOrder.count) | 0 | 0 | — | OCR 失败 |")
                errorDetails.append("| \(card.id) | （整张） | — | — | OCR 失败：\(error.localizedDescription) |")
            }
            cardReports.append(report)
        }

        // ---- 汇总输出（CI 用 grep OCR-ACCURACY 抽取） ----
        func pct(_ numerator: Int, _ denominator: Int) -> String {
            guard denominator > 0 else { return "n/a" }
            return String(format: "%.1f%%", Double(numerator) * 100 / Double(denominator))
        }
        let fieldAccuracy = pct(correctChecks, totalChecks)
        let recall = pct(presentCorrect, presentChecks)
        let absentPrecision = pct(absentCorrect, absentChecks)
        let cardAccuracy = pct(allCorrectCards, cards.count)

        // 指标结构完整性：与 docs/ocr-accuracy.md §2/§3 的 440 = 248 + 192 契约一致。
        XCTAssertEqual(totalChecks, cards.count * Self.fieldOrder.count)
        XCTAssertEqual(presentChecks + absentChecks, totalChecks)
        // Ground Truth 契约：有值字段 248 项、空字段 192 项。若数据集被改动而这里失败，
        // 说明评价分母变了，需要先更新 docs/ocr-accuracy.md 再调整本断言。
        XCTAssertEqual(presentChecks, 248, "Ground Truth 有值字段应为 248 项")
        XCTAssertEqual(absentChecks, 192, "Ground Truth 空字段应为 192 项")

        print("OCR-ACCURACY field-level: \(correctChecks)/\(totalChecks) = \(fieldAccuracy)")
        print("OCR-ACCURACY present-recall: \(presentCorrect)/\(presentChecks) = \(recall)")
        print("OCR-ACCURACY absent-precision: \(absentCorrect)/\(absentChecks) = \(absentPrecision)")
        print("OCR-ACCURACY fabrications: \(fabricated)")
        print("OCR-ACCURACY misplaced: \(misplaced) | optional-missed: \(optionalMissed)")
        print("OCR-ACCURACY card-level-all-correct: \(allCorrectCards)/\(cards.count) = \(cardAccuracy)")

        // ---- 写报告（每次运行覆盖） ----
        let buildDir = repoRoot.appendingPathComponent("build", isDirectory: true)
        try FileManager.default.createDirectory(at: buildDir, withIntermediateDirectories: true)

        let stamp = ISO8601DateFormatter().string(from: Date())
        var markdown = """
        # OCR / 字段抽取端到端准确率报告（B 层）

        - 生成时间：\(stamp)
        - 运行环境：\(runtimeDescription)（模拟器或真机）
        - 数据集：40 张合成名片 `flat` 变体；Ground Truth 来自 `docs/test-cards/ground-truth.json`
        - 链路：Vision `VNRecognizeTextRequest`（accurate，zh-Hans + en-US，minimumTextHeight 0.01）→ `BusinessCardFieldParser`
        - 说明：并行/串行与设备性能不影响结果判定；本报告只代表该数据集与系统版本，见 `docs/ocr-accuracy.md` §6

        ## 汇总

        | 指标 | 结果 |
        | --- | --- |
        | 字段级准确率（11 字段 × 40 张 = 440 项） | \(correctChecks)/\(totalChecks) = \(fieldAccuracy) |
        | 有值召回（Ground Truth 有值的字段） | \(presentCorrect)/\(presentChecks) = \(recall) |
        | 缺失字段精度（Ground Truth 为空的字段保持为空） | \(absentCorrect)/\(absentChecks) = \(absentPrecision) |
        | 虚构字段（§8 禁止项） | \(fabricated) |
        | 漏提 / 取值错误 | \(missed) / \(wrong) |
        | 其中：错位（值出现在其他字段）/ 可选字段缺失 | \(misplaced) / \(optionalMissed) |
        | 名片级全对率 | \(allCorrectCards)/\(cards.count) = \(cardAccuracy) |
        | 完成识别的名片 | \(processedCards)/\(cards.count) |

        ## 逐张结果

        | 名片 | 字段正确 | 漏提 | 取值错误 | 虚构 | 平均置信度 | 未分类行 |
        | --- | --- | --- | --- | --- | --- | --- |

        """
        markdown += tableRows.joined(separator: "\n") + "\n\n"

        markdown += "## 错误明细\n\n"
        if errorDetails.isEmpty {
            markdown += "无字段级错误。\n"
        } else {
            markdown += "| 名片 | 字段 | Ground Truth | 识别结果 | 判定 |\n| --- | --- | --- | --- | --- |\n"
            markdown += errorDetails.joined(separator: "\n") + "\n"
            markdown += "\n### 出错名片的原始文本\n\n"
            markdown += "「原图文字」来自 `layoutText`（生成脚本写入卡片的原始文本），用于区分**OCR 识别错误**与**解析归类错误**："
            markdown += "原图文字与 Ground Truth 一致而 OCR 文本不同 → 识别问题；OCR 文本包含正确文字但字段错位 → 解析问题。\n\n"
            for report in cardReports where (report["fields"] as? [[String: Any]])?.contains(where: { ($0["verdict"] as? String) != Verdict.ok.rawValue }) == true {
                let id = report["id"] as? String ?? "?"
                let source = (report["source"] as? [String] ?? []).joined(separator: " ｜ ")
                let raw = report["rawOCRText"] as? String ?? "（无）"
                let unclassified = (report["unclassifiedLines"] as? [String] ?? []).joined(separator: " ｜ ")
                markdown += "#### \(id)\n\n**原图文字**：\(source)\n\n**未分类行**：\(unclassified.isEmpty ? "（无）" : unclassified)\n\n"
                markdown += "**Vision OCR 原始输出**：\n\n```text\n\(raw)\n```\n\n"
            }
        }

        let reportMarkdownURL = buildDir.appendingPathComponent("ocr-accuracy-report.md")
        try markdown.write(to: reportMarkdownURL, atomically: true, encoding: .utf8)

        let summary: [String: Any] = [
            "generatedAt": stamp,
            "environment": runtimeDescription,
            "dataset": "40 flat synthetic cards",
            "metrics": [
                "fieldAccuracy": ["correct": correctChecks, "total": totalChecks, "percent": fieldAccuracy],
                "presentRecall": ["correct": presentCorrect, "total": presentChecks, "percent": recall],
                "absentPrecision": ["correct": absentCorrect, "total": absentChecks, "percent": absentPrecision],
                "fabrications": fabricated,
                "missed": missed,
                "wrongValue": wrong,
                "misplaced": misplaced,
                "optionalMissed": optionalMissed,
                "cardAllCorrect": ["correct": allCorrectCards, "total": cards.count, "percent": cardAccuracy],
                "processedCards": processedCards,
            ],
            "cards": cardReports,
        ]
        let reportJSONURL = buildDir.appendingPathComponent("ocr-accuracy-report.json")
        let jsonData = try JSONSerialization.data(withJSONObject: summary, options: [.prettyPrinted, .sortedKeys])
        try jsonData.write(to: reportJSONURL, options: .atomic)

        print("OCR-ACCURACY report: \(reportMarkdownURL.path)")
        print("OCR-ACCURACY report: \(reportJSONURL.path)")

        // ---- 断言：只对 §8 硬约束与完整性负责 ----
        XCTAssertEqual(processedCards, cards.count, "40 张名片必须全部完成 Vision 识别；失败：\n" + errorDetails.joined(separator: "\n"))
        XCTAssertEqual(fabricated, 0, "出现虚构字段（作业 §8 硬约束）：\n" + fabricatedDetails.joined(separator: "\n"))
    }
    #endif
}
