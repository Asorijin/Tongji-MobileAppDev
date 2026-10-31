import Foundation

/// 字段抽取规则表。
///
/// 规则全部是确定性的字符串匹配，不依赖模型推理，因此可以离线单元测试、
/// 也可以在不同平台（Windows / macOS）上得到完全一致的结果。
public struct FieldExtractionRules {
    // MARK: - 行首字段标签（标签后必须跟冒号）

    public var nameLabels = ["姓名", "名字", "name"]
    public var companyLabels = ["公司名称", "公司", "单位", "company name", "company", "organization", "organisation", "org"]
    public var jobTitleLabels = ["职位", "职务", "岗位", "job title", "title", "position"]
    public var departmentLabels = ["部门", "事业部", "department", "dept."]
    public var addressLabels = ["公司地址", "工作地址", "地址", "住址", "company address", "work address", "address"]
    public var postalCodeLabels = ["邮政编码", "邮编", "postal code", "postcode", "zip"]

    // MARK: - 行内电话标签

    public var faxLabels = ["传真号码", "传真", "fax", "f:"]
    public var mobileLabels = ["手机号码", "手机号", "手机", "移动电话", "mobile", "cell", "m:"]
    public var officeLabels = ["办公电话", "固定电话", "座机", "电话", "office", "tel", "phone", "t:"]
    public var websiteLabels = ["网址", "网站", "主页", "website", "web", "url", "homepage"]

    // MARK: - 关键词

    public var departmentPatterns = [
        "^(department|dept\\.?|school|faculty|college|institute|centre|center)\\s+of\\b",
    ]
    /// 中文部门行常见后缀，如"人力资源部""研发中心"。
    public var departmentSuffixes = ["部", "中心"]
    public var departmentKeywords = ["学院", "部门", "事业部"]

    public var jobTitleKeywords = [
        "教授", "副教授", "讲师", "研究员", "副研究员", "工程师", "高级工程师", "架构师", "建筑师",
        "程序员", "开发者", "设计师", "产品经理", "项目经理", "技术经理", "总经理",
        "经理", "总监", "技术总监", "主管", "负责人", "主任", "处长", "科长", "院长",
        "校长", "所长", "组长", "队长", "顾问", "分析师", "董事", "总裁", "副总裁", "主席",
        "编辑", "律师", "护士长", "音乐人", "译者",
        "professor", "director", "manager", "engineer", "developer", "designer", "architect",
        "analyst", "specialist", "consultant", "officer", "president", "founder", "co-founder",
        "lead", "chief", "researcher", "scientist", "dean", "chairman", "head",
        "ceo", "cto", "cfo", "coo", "cio", "cmo", "vp",
        "writer", "editor", "nurse", "lawyer", "translator", "teacher", "student",
        "musician", "account executive",
    ]

    public var companyKeywords = [
        "有限公司", "有限责任公司", "股份有限公司", "集团", "公司", "大学", "研究所", "研究院",
        "医院", "银行", "工作室", "出版社", "事务所", "设计院", "物流", "贸易", "文化",
        "投资", "科技", "人力资源",
        "inc", "incorporated", "ltd", "limited", "llc", "llp", "corp", "corporation",
        "company", "co", "gmbh", "group", "holdings", "technologies", "technology",
        "solutions", "consulting", "studio", "labs", "lab", "systems", "networks",
        "media", "university", "college", "institute", "bank", "partners", "firm",
        "financial",
    ]

    /// 中文地址常见的字眼。"室"不在其中：它是"工作室"（组织名）的常用字，
    /// 而带门牌的地址行"3号楼5层502室"已经能被"号/楼/层"命中。
    public var addressTokens = ["省", "市", "区", "路", "街", "道", "号", "弄", "栋", "楼", "层", "单元", "村", "镇"]
    public var streetSuffixWords = [
        "street", "st.", "st", "road", "rd.", "rd", "avenue", "ave.", "ave",
        "boulevard", "blvd.", "blvd", "lane", "ln.", "ln", "suite", "floor", "room",
        "drive", "dr.", "court", "way", "place", "plaza", "parkway", "highway",
        "terrace", "circle",
    ]

    public var nameHonorifics = ["dr.", "dr", "mr.", "mr", "mrs.", "mrs", "ms.", "ms", "prof.", "prof", "miss"]
    public var nameParticles = ["van", "von", "de", "da", "der", "bin", "al"]

    /// 显式标签后紧跟这些占位词时，视为"名片上确认没有该字段"，
    /// 阻止后续启发式再从其它行猜测（作业 §9 不臆造字段）。
    public var absentPlaceholders = ["无", "暂无", "没有", "n/a", "na", "none", "null", "-", "--"]

    public static let `default` = FieldExtractionRules()

    public init() {}
}
