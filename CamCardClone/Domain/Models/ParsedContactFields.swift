import Foundation

/// 字段解析（OCR Raw Text → Structured Fields）的结果。
///
/// 所有字段均为"尽力识别"：无法确认的字段保持 nil / 空数组，
/// 不做任何基于语义的推断与补全。
public struct ParsedContactFields: Codable, Equatable {
    public var name: String?
    public var company: String?
    public var jobTitle: String?
    public var department: String?
    public var mobiles: [String] = []
    public var officePhones: [String] = []
    public var faxes: [String] = []
    public var emails: [String] = []
    public var websites: [String] = []
    public var address: String?
    public var postalCode: String?
    public var unclassifiedLines: [String] = []

    /// 解析器内部标记：某字段已由显式标签确认为"名片上不存在"（如 `Website: (none)`），
    /// 后续启发式不得再用其它行填充该字段。输出时不参与编码/比较。
    var exhausted: Set<ExhaustedField> = []

    enum ExhaustedField: String, Codable, Hashable {
        case company, jobTitle, department, address, website
    }

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case name, company, jobTitle, department, mobiles, officePhones, faxes,
             emails, websites, address, postalCode, unclassifiedLines
    }

    public var hasAnyField: Bool {
        [name, company, jobTitle, department, address, postalCode]
            .contains { $0?.isEmpty == false }
            || !mobiles.isEmpty || !officePhones.isEmpty || !faxes.isEmpty
            || !emails.isEmpty || !websites.isEmpty
    }
}
