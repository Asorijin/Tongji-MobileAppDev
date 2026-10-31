import Foundation

/// 结构化名片记录。
///
/// 电话、邮箱、网址使用数组，以容纳真实名片中常见的多值情形（多手机、多座机、多邮箱）。
/// 空字段一律保持为空数组或 nil —— 系统不得根据语义"补全"名片上不存在的信息。
public struct BusinessCard: Codable, Identifiable, Hashable {
    public var id: UUID
    public var name: String?
    public var company: String?
    public var jobTitle: String?
    public var department: String?
    public var mobiles: [String]
    public var officePhones: [String]
    public var faxes: [String]
    public var emails: [String]
    public var websites: [String]
    public var address: String?
    public var postalCode: String?
    public var notes: String?
    public var tagIDs: [UUID]

    /// 原始名片图像（用户拍摄或导入）。相对路径，根目录由存储层决定。
    public var originalImagePath: String?
    /// 校正后的名片图像。
    public var processedImagePath: String?
    /// OCR 原始文本，用于 AI 输出追溯与错误分析。
    public var rawOCRText: String?

    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String? = nil,
        company: String? = nil,
        jobTitle: String? = nil,
        department: String? = nil,
        mobiles: [String] = [],
        officePhones: [String] = [],
        faxes: [String] = [],
        emails: [String] = [],
        websites: [String] = [],
        address: String? = nil,
        postalCode: String? = nil,
        notes: String? = nil,
        tagIDs: [UUID] = [],
        originalImagePath: String? = nil,
        processedImagePath: String? = nil,
        rawOCRText: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.company = company
        self.jobTitle = jobTitle
        self.department = department
        self.mobiles = mobiles
        self.officePhones = officePhones
        self.faxes = faxes
        self.emails = emails
        self.websites = websites
        self.address = address
        self.postalCode = postalCode
        self.notes = notes
        self.tagIDs = tagIDs
        self.originalImagePath = originalImagePath
        self.processedImagePath = processedImagePath
        self.rawOCRText = rawOCRText
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// 由字段解析结果构建名片。未识别出的字段保持为空。
    public init(
        fields: ParsedContactFields,
        originalImagePath: String? = nil,
        processedImagePath: String? = nil,
        rawOCRText: String? = nil
    ) {
        self.init(
            name: fields.name,
            company: fields.company,
            jobTitle: fields.jobTitle,
            department: fields.department,
            mobiles: fields.mobiles,
            officePhones: fields.officePhones,
            faxes: fields.faxes,
            emails: fields.emails,
            websites: fields.websites,
            address: fields.address,
            postalCode: fields.postalCode,
            originalImagePath: originalImagePath,
            processedImagePath: processedImagePath,
            rawOCRText: rawOCRText
        )
    }

    public var displayName: String {
        if let name, !name.isEmpty { return name }
        if let company, !company.isEmpty { return company }
        if let email = emails.first { return email }
        return "未命名名片"
    }

    /// 列表头像缩写：中文取首字，英文取前两个单词首字母。
    public var displayInitials: String {
        let source = name ?? company ?? displayName
        let cjk = source.filter { $0.unicodeScalars.first.map(Self.isCJK) ?? false }
        if let first = cjk.first { return String(first) }
        let words = source.split(separator: " ")
        let letters = words.prefix(2).compactMap { $0.first }.map(String.init)
        return letters.joined().uppercased()
    }

    public var allPhones: [String] { mobiles + officePhones + faxes }

    public var hasStructuredContent: Bool {
        [name, company, jobTitle, department, address, postalCode, notes]
            .contains { value in value?.isEmpty == false }
            || !mobiles.isEmpty || !officePhones.isEmpty || !faxes.isEmpty
            || !emails.isEmpty || !websites.isEmpty
    }

    private static func isCJK(_ scalar: Unicode.Scalar) -> Bool {
        (0x4E00...0x9FFF).contains(scalar.value) || (0x3400...0x4DBF).contains(scalar.value)
    }
}
