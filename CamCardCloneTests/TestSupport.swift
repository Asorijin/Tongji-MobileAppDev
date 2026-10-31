import Foundation
import XCTest
// 两种构建形态共用同一份测试：
// - iOS 工程（Xcode / 模拟器）：这些源码直接属于 App 模块 CamCardClone；
// - SwiftPM 纯校验包（Windows / Linux）：Domain / Export 是独立模块。
// 注意不能用 canImport(CamCardDomain)：Windows 的 Swift 工具链也会 define Xcode。
#if os(iOS)
@testable import CamCardClone
#else
import CamCardDomain
import CamCardExport
#endif

/// 合成测试名片（无真实个人信息），对应 docs/test-cards/ 中的测试集。
/// 这里的 OCR 原始文本模拟 Vision 识别输出的典型形态：每行一个文本块。
enum SampleCards {
    // C01 中文名片（完整字段）
    static let chineseFull = """
    同济大学
    朱宏明
    教授
    计算机科学与技术学院
    手机：13812345678
    电话：021-65981234
    传真：021-65981235
    邮箱：zhuhm@example.edu.cn
    网址：www.example.edu.cn
    地址：上海市杨浦区四平路1239号
    邮编：200092
    """

    // C02 英文名片（无网址 —— T09 字段缺失）
    static let englishMissingWebsite = """
    ABC Technologies Inc.
    David Chen
    Technical Director
    Mobile: +1 (555) 010-2233
    Office: 555-010-8899
    Email: david.chen@example.com
    500 Market Street, Suite 900, San Francisco, CA
    """

    // C03 中英双语名片
    static let bilingual = """
    Tongji University
    李娜
    Associate Professor
    School of Software Engineering
    手机: +86 139 0000 1111
    Tel: +86 (21) 6958 9000
    Email: lina@example.edu.cn
    """

    // C04 多电话（手机 / 办公电话 / 传真各一）
    static let multiplePhones = """
    王强
    项目经理
    华东建设集团
    手机：137 1111 2222
    办公电话：021-5888 1234
    传真：021-5888 5678
    """

    // C05 多 Email
    static let multipleEmails = """
    Emily Zhang
    Product Manager
    Nova Robotics Lab
    emily.zhang@example.com
    e.zhang@example.org
    """

    // C06 竖版极简名片（字段几乎全缺失）
    static let minimal = """
    陈晨
    设计师
    """

    // C07 字段歧义：单个词 "Apple"
    static let ambiguousApple = """
    Apple
    """

    // C08 人名与公司混淆：Jordan Lee / Lee Consulting
    static let jordanLee = """
    Jordan Lee
    Lee Consulting
    """

    // C09 带称谓 + 全角标点（OCR 常见形态）
    static let honorificFullWidth = """
    Dr. David Chen
    ABC University
    Mobile：+86 138 1234 5678
    Email：david@example.com
    """

    // C10 编号式英文名片（Street / 电话无标签）
    static let unlabeledEnglish = """
    Michael Brown
    Senior Software Engineer
    Northwind Systems
    555-014-7788
    12 Oak Avenue, Springfield
    """

    // C11 教师示例名片（作业 §7.5 的原始示例）
    static let professorExample = """
    Dr. David Chen
    Professor
    School of Computer Science
    ABC University
    Mobile: +86 138 1234 5678
    Email: david@abc.edu
    """

    // C12 无任何结构化信息的图片（OCR 只得到 Logo 文字）
    static let logoOnly = """
    LOGO
    """
}
