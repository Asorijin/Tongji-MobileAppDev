import Foundation
import XCTest
#if canImport(CamCardDomain)
import CamCardDomain
#else
@testable import CamCardClone
#endif

/// T07/T08/T09/T10 的确定性核心：OCR 原始文本 → 结构化字段（字段级准确率 100%）。
/// 所有用例均来自固定合成测试名片（见 TestSupport.swift），不含真实个人信息。
final class FieldParserTests: XCTestCase {
    private let parser = BusinessCardFieldParser()

    // MARK: - T08 中文字段分类

    func testChineseCardFullExtraction() {
        let fields = parser.parse(SampleCards.chineseFull)
        XCTAssertEqual(fields.name, "朱宏明")
        XCTAssertEqual(fields.company, "同济大学")
        XCTAssertEqual(fields.jobTitle, "教授")
        XCTAssertEqual(fields.department, "计算机科学与技术学院")
        XCTAssertEqual(fields.mobiles, ["138 1234 5678"])
        XCTAssertEqual(fields.officePhones, ["021 65981234"])
        XCTAssertEqual(fields.faxes, ["021 65981235"])
        XCTAssertEqual(fields.emails, ["zhuhm@example.edu.cn"])
        XCTAssertEqual(fields.websites, ["www.example.edu.cn"])
        XCTAssertEqual(fields.address, "上海市杨浦区四平路1239号")
        XCTAssertEqual(fields.postalCode, "200092")
        XCTAssertTrue(fields.unclassifiedLines.isEmpty, "识别出的行不应残留：\(fields.unclassifiedLines)")
    }

    func testEnglishCardShortInterleavedLabels() {
        let fields = parser.parse(SampleCards.englishMissingWebsite)
        XCTAssertEqual(fields.name, "David Chen")
        XCTAssertEqual(fields.company, "ABC Technologies Inc.")
        XCTAssertEqual(fields.jobTitle, "Technical Director")
        XCTAssertEqual(fields.mobiles, ["+1 555 010 2233"])
        XCTAssertEqual(fields.officePhones, ["555 010 8899"])
        XCTAssertEqual(fields.emails, ["david.chen@example.com"])
        XCTAssertEqual(fields.address, "500 Market Street, Suite 900, San Francisco, CA")
    }

    func testBilingualCard() {
        let fields = parser.parse(SampleCards.bilingual)
        XCTAssertEqual(fields.name, "李娜")
        XCTAssertEqual(fields.company, "Tongji University")
        XCTAssertEqual(fields.jobTitle, "Associate Professor")
        XCTAssertEqual(fields.department, "School of Software Engineering")
        XCTAssertEqual(fields.mobiles, ["139 0000 1111"])
        XCTAssertEqual(fields.officePhones, ["021 6958 9000"], "+86 座机按展示格式契约去掉国家码并补 0 区号")
        XCTAssertEqual(fields.emails, ["lina@example.edu.cn"])
    }

    func testTeacherExampleFromAssignment() {
        let fields = parser.parse(SampleCards.professorExample)
        XCTAssertEqual(fields.name, "David Chen", "称谓 Dr. 应被移除但姓名保留")
        XCTAssertEqual(fields.company, "ABC University")
        XCTAssertEqual(fields.jobTitle, "Professor")
        XCTAssertEqual(fields.department, "School of Computer Science")
        XCTAssertEqual(fields.mobiles, ["138 1234 5678"])
        XCTAssertEqual(fields.emails, ["david@abc.edu"])
        XCTAssertNil(fields.websites.first)
        XCTAssertNil(fields.address, "原图中不存在地址时不得生成")
    }

    // MARK: - T09 字段缺失不得虚构

    func testMissingWebsiteIsNotFabricated() {
        let fields = parser.parse(SampleCards.englishMissingWebsite)
        XCTAssertTrue(fields.websites.isEmpty, "名片上没有网址时不得凭空产生 Website")
        XCTAssertNil(fields.postalCode)
    }

    func testExplicitAbsentLabelBlocksHeuristics() {
        // 名片上明确印着"公司：无"，后面的行不得再被猜成公司或姓名。
        let fields = parser.parse("公司：无\n网址：无\n冯雪\n自由职业")
        XCTAssertNil(fields.company, "已声明公司不存在，启发式不得臆造")
        XCTAssertTrue(fields.websites.isEmpty)
        XCTAssertEqual(fields.name, "冯雪")
        XCTAssertEqual(fields.unclassifiedLines, ["自由职业"], "无法确认的行保留为未分类")
    }

    func testMinimalCardKeepsOnlyPresentFields() {
        let fields = parser.parse(SampleCards.minimal)
        XCTAssertEqual(fields.name, "陈晨")
        XCTAssertEqual(fields.jobTitle, "设计师")
        XCTAssertNil(fields.company)
        XCTAssertNil(fields.address)
        XCTAssertTrue(fields.mobiles.isEmpty)
        XCTAssertTrue(fields.emails.isEmpty)
        XCTAssertTrue(fields.websites.isEmpty)
        XCTAssertTrue(fields.faxes.isEmpty)
        XCTAssertEqual(fields.unclassifiedLines, [], "已识别行不残留")
    }

    func testLogoOnlyTextIsKeptAsUnclassifiedWithoutInvention() {
        let fields = parser.parse(SampleCards.logoOnly)
        // "LOGO" 是纯大写 Logo 文本，不符合姓名/公司形态：作为版式噪声丢弃，不臆造字段。
        XCTAssertNil(fields.name)
        XCTAssertNil(fields.company)
        XCTAssertEqual(fields.unclassifiedLines, [])
        XCTAssertFalse(fields.hasAnyField)
    }

    // MARK: - T10 多电话分类

    func testMultiplePhonesCategorizedByLabel() {
        let fields = parser.parse(SampleCards.multiplePhones)
        XCTAssertEqual(fields.name, "王强")
        XCTAssertEqual(fields.company, "华东建设集团")
        XCTAssertEqual(fields.jobTitle, "项目经理")
        XCTAssertEqual(fields.mobiles, ["137 1111 2222"])
        XCTAssertEqual(fields.officePhones, ["021 5888 1234"])
        XCTAssertEqual(fields.faxes, ["021 5888 5678"])
    }

    func testMultipleEmailsAllPreserved() {
        let fields = parser.parse(SampleCards.multipleEmails)
        XCTAssertEqual(fields.emails, ["emily.zhang@example.com", "e.zhang@example.org"])
        XCTAssertEqual(fields.name, "Emily Zhang")
        XCTAssertEqual(fields.company, "Nova Robotics Lab")
        XCTAssertEqual(fields.jobTitle, "Product Manager")
    }

    func testUnlabeledElevenDigitNumberInferredAsMobile() {
        let fields = parser.parse("周伟\n13912345678")
        XCTAssertEqual(fields.name, "周伟")
        XCTAssertEqual(fields.mobiles, ["139 1234 5678"])
        XCTAssertTrue(fields.officePhones.isEmpty)
    }

    // MARK: - 字段歧义（作业 §8）

    func testAmbiguousSingleWordAppleDoesNotBecomeCompanyOrName() {
        let fields = parser.parse(SampleCards.ambiguousApple)
        XCTAssertNil(fields.company, "Apple 是产品名，也是公司名关键字，规则不臆断，保留为未分类行")
        XCTAssertNil(fields.name)
        XCTAssertEqual(fields.unclassifiedLines, ["Apple"])
    }

    func testJordanLeeVersusLeeConsulting() {
        let fields = parser.parse(SampleCards.jordanLee)
        XCTAssertEqual(fields.name, "Jordan Lee")
        XCTAssertEqual(fields.company, "Lee Consulting")
    }

    func testHonorificStrippedFromName() {
        let fields = parser.parse(SampleCards.honorificFullWidth)
        XCTAssertEqual(fields.name, "David Chen")
        XCTAssertEqual(fields.company, "ABC University")
        XCTAssertEqual(fields.mobiles, ["138 1234 5678"])
        XCTAssertEqual(fields.emails, ["david@example.com"])
    }

    // MARK: - 全角标点与格式鲁棒性

    func testFullWidthColonLabelsAreNormalized() {
        let fields = parser.parse("姓名：赵敏\n公司：星辰科技\n手机：13812340000")
        XCTAssertEqual(fields.name, "赵敏")
        XCTAssertEqual(fields.company, "星辰科技")
        XCTAssertEqual(fields.mobiles, ["138 1234 0000"])
    }

    func testPosixPhoneFormatting() {
        let fields = parser.parse("x\nTel: (021) 6598-1234")
        XCTAssertEqual(fields.officePhones, ["021 6598 1234"])
    }

    func testPhoneWith0086PrefixNormalized() {
        let fields = parser.parse("张磊\n手机：0086 13812345678")
        XCTAssertEqual(fields.mobiles, ["138 1234 5678"])
    }

    /// 展示格式契约（与 docs/test-cards/ground-truth.json 一致）。
    func testInternationalPhoneDisplayContract() {
        XCTAssertEqual(parser.parse("Mobile: +1 (555) 010-2233").mobiles, ["+1 555 010 2233"])
        XCTAssertEqual(parser.parse("Mobile: +1 555 018 4410").mobiles, ["+1 555 018 4410"])
        XCTAssertEqual(parser.parse("Tel: +86 (21) 6958 9000").officePhones, ["021 6958 9000"])
        XCTAssertEqual(parser.parse("Mobile: +86 139 0000 0026").mobiles, ["139 0000 0026"])
    }

    // MARK: - 竖排版式与"室"字公司名

    func testVerticalNameFragmentsAcrossOrganizationLines() {
        // 竖排名片：姓名逐字成行，中间夹着公司 / 部门 / 职位行。
        let fields = parser.parse("吴\n启元研究院\n芳\n材料研究部\n副研究员\n手机 138 0000 0005")
        XCTAssertEqual(fields.name, "吴芳")
        XCTAssertEqual(fields.company, "启元研究院")
        XCTAssertEqual(fields.department, "材料研究部")
        XCTAssertEqual(fields.jobTitle, "副研究员")
        XCTAssertEqual(fields.mobiles, ["138 0000 0005"])
    }

    func testStudioSuffixCompanyIsNotAddress() {
        let fields = parser.parse("周伟\n设计师\n南风工作室")
        XCTAssertEqual(fields.name, "周伟")
        XCTAssertEqual(fields.company, "南风工作室", "工作室含「室」字但不是地址")
        XCTAssertNil(fields.address)
        XCTAssertEqual(fields.unclassifiedLines, [])
    }

    func testTwoLetterLogoIsNotCompany() {
        let fields = parser.parse("CO\n冯雪\n自由译者\n星火翻译工作室")
        XCTAssertEqual(fields.company, "星火翻译工作室")
        XCTAssertEqual(fields.unclassifiedLines, [])
    }

    func testUnlabeledEnglishCardHeuristics() {
        let fields = parser.parse(SampleCards.unlabeledEnglish)
        XCTAssertEqual(fields.name, "Michael Brown")
        XCTAssertEqual(fields.jobTitle, "Senior Software Engineer")
        XCTAssertEqual(fields.company, "Northwind Systems")
        XCTAssertEqual(fields.officePhones, ["555 014 7788"])
        XCTAssertEqual(fields.address, "12 Oak Avenue, Springfield")
    }

    // MARK: - 确定性（同一输入 → 同一输出）

    func testParsingIsDeterministic() {
        for sample in [SampleCards.chineseFull, SampleCards.bilingual, SampleCards.multiplePhones, SampleCards.jordanLee] {
            let first = parser.parse(sample)
            for _ in 0..<5 {
                XCTAssertEqual(parser.parse(sample), first)
            }
        }
    }
}
