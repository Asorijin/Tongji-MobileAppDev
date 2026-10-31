import Foundation

/// 确定性字段解析器：OCR 原始文本 → 结构化联系人字段。
///
/// 设计约束（见 docs/spec.md §7.4-7.5 与 §8）：
/// 1. 只提取原文中出现的字段，绝不补全或猜测不存在的字段；
/// 2. 多值字段（电话 / 邮箱 / 网址）保留全部出现值，按语义分为 Mobile / Office / Fax；
/// 3. 同一输入必须产生同一输出（无随机、无网络、无平台差异）。
public struct BusinessCardFieldParser {
    private let rules: FieldExtractionRules

    private enum LabelTarget {
        case name, company, jobTitle, department, address, postalCode
    }

    private enum PhoneKind {
        case mobile, office, fax
    }

    public init(rules: FieldExtractionRules = .default) {
        self.rules = rules
    }

    public func parse(_ rawText: String) -> ParsedContactFields {
        var fields = ParsedContactFields()
        let lines = TextNormalizer.lines(rawText)
        var consumed = Set<Int>()

        // Pass 1：多值字段，整行消费。
        for (index, line) in lines.enumerated() {
            if let emails = emails(in: line) {
                appendUnique(emails, to: &fields.emails)
                consumed.insert(index)
                continue
            }
            if let urls = websites(in: line) {
                appendUnique(urls, to: &fields.websites)
                consumed.insert(index)
                continue
            }
            if let found = phones(in: line) {
                for phone in found {
                    switch phone.kind {
                    case .mobile: appendUnique([phone.value], to: &fields.mobiles)
                    case .office: appendUnique([phone.value], to: &fields.officePhones)
                    case .fax: appendUnique([phone.value], to: &fields.faxes)
                    }
                }
                consumed.insert(index)
            }
        }

        // Pass 2：显式标签，如 "姓名：朱宏明"、"Name: David Chen"。
        let labels = explicitLabels()
        for (index, line) in lines.enumerated() where !consumed.contains(index) {
            // OCR 会把标签与值连成一行（"地址北京市…"），带标签前缀的行必须先
            // 按标签切分；否则整个字符串会被当成字段值（运行 5 C02 / C03）。
            if let (target, value) = matchLabel(line: line, labels: labels) ?? matchGluedLabel(line: line, labels: labels) {
                let absent = isAbsentPlaceholder(value)
                switch target {
                case .name: if fields.name == nil, !absent { fields.name = value }
                case .company:
                    if absent { fields.exhausted.insert(.company) }
                    else if fields.company == nil { fields.company = value }
                case .jobTitle:
                    if absent { fields.exhausted.insert(.jobTitle) }
                    else if fields.jobTitle == nil { fields.jobTitle = value }
                case .department:
                    if absent { fields.exhausted.insert(.department) }
                    else if fields.department == nil { fields.department = value }
                case .address:
                    if absent { fields.exhausted.insert(.address) }
                    else if fields.address == nil { fields.address = value }
                case .postalCode: if fields.postalCode == nil, !absent { fields.postalCode = value }
                }
                consumed.insert(index)
                continue
            }
            // 网络类字段的显式标签（如 "网址：无"）也视为已消费的行；
            // 内容由 Pass 1 负责提取，这里只防止占位行落入未分类。
            if let kind = networkLabelKind(line: line) {
                if kind == .website, isAbsentPlaceholder(valueAfterLabel(line, labels: labels)) {
                    fields.exhausted.insert(.website)
                }
                consumed.insert(index)
            }
        }

        // Pass 3：无标签行的语义启发式。
        var remaining = lines.indices
            .filter { !consumed.contains($0) }
            .map { lines[$0] }
            .filter { !isLabelOnly($0) }
        // 竖排版式：姓名逐字成行，必须先把这些行合成姓名再进入启发式，
        // 否则"云和实验室"这类含地址字的公司会被地址规则抢占。
        mergeVerticalNameFragments(&remaining)
        let verticalName = takeVerticalName(&remaining)

        if !fields.exhausted.contains(.jobTitle),
           fields.jobTitle == nil, let line = takeFirst(&remaining, where: isJobTitle) {
            fields.jobTitle = line
        }
        if !fields.exhausted.contains(.department),
           fields.department == nil, let line = takeFirst(&remaining, where: isDepartment) {
            fields.department = line
        }
        // 姓名先于公司：地址启发式会误吞"云和实验室"这类名字。
        if fields.name == nil, let name = verticalName {
            fields.name = name
        } else if fields.name == nil, let line = takeFirst(&remaining, where: isNameLike) {
            fields.name = stripHonorific(line)
        }
        if !fields.exhausted.contains(.company),
           fields.company == nil, let line = takeFirst(&remaining, where: isCompany) {
            fields.company = line
        }
        if !fields.exhausted.contains(.address),
           fields.address == nil, let line = takeFirst(&remaining, where: isAddressLike) {
            fields.address = line
        }
        remaining.removeAll(where: isLogoLike)

        // 显式姓名同样去除称谓。
        fields.name = fields.name.map(stripHonorific)

        // 剩下的行原样保留，用于人工校正与错误分析，不臆造补全。
        fields.unclassifiedLines = remaining
        return fields
    }

    // MARK: - 显式标签

    private func explicitLabels() -> [(label: String, target: LabelTarget)] {
        var pairs: [(String, LabelTarget)] = []
        pairs += rules.nameLabels.map { ($0.lowercased(), .name) }
        pairs += rules.companyLabels.map { ($0.lowercased(), .company) }
        pairs += rules.jobTitleLabels.map { ($0.lowercased(), .jobTitle) }
        pairs += rules.departmentLabels.map { ($0.lowercased(), .department) }
        pairs += rules.addressLabels.map { ($0.lowercased(), .address) }
        pairs += rules.postalCodeLabels.map { ($0.lowercased(), .postalCode) }
        // 长标签优先，避免 "company" 抢先匹配 "company address"。
        return pairs.sorted { $0.0.count > $1.0.count }.map { label, target in (label, target) }
    }

    private func matchLabel(line: String, labels: [(label: String, target: LabelTarget)]) -> (LabelTarget, String)? {
        let lower = line.lowercased()
        for entry in labels {
            let label = entry.label
            if lower == label || lower == "\(label):" { continue }
            if lower.hasPrefix("\(label):") {
                if let value = TextNormalizer.sanitized(String(line.dropFirst(label.count + 1))) {
                    return (entry.target, value)
                }
            } else if lower.hasPrefix("\(label) ") {
                if let value = TextNormalizer.sanitized(String(line.dropFirst(label.count + 1))) {
                    return (entry.target, value)
                }
            }
        }
        return nil
    }

    /// 无分隔符的"标签+值"合并行（"地址北京市海淀区…"、"部门研发中心"）。
    ///
    /// 只接受以该字段专属标签开头、且剩余部分本身可判定为该字段的行；
    /// 姓名/公司等易与正文混淆的字段不参与，避免误切普通文本。
    private func matchGluedLabel(line: String, labels: [(label: String, target: LabelTarget)]) -> (LabelTarget, String)? {
        let lower = line.lowercased()
        for entry in labels {
            let target: (String) -> Bool
            switch entry.target {
            case .department:
                target = isDepartment
            case .address:
                target = isAddressLike
            default:
                continue
            }
            guard lower.hasPrefix(entry.label), line.count > entry.label.count else { continue }
            let remainder = TextNormalizer.sanitized(String(line.dropFirst(entry.label.count)))
            guard let value = remainder, target(value) else { continue }
            return (entry.target, value)
        }
        return nil
    }

    private func isLabelOnly(_ line: String) -> Bool {
        let lower = line.lowercased()
        let all = rules.nameLabels + rules.companyLabels + rules.jobTitleLabels
            + rules.departmentLabels + rules.addressLabels + rules.postalCodeLabels
            + rules.mobileLabels + rules.officeLabels + rules.faxLabels + rules.websiteLabels
        return all.contains { lower == $0 || lower == "\($0):" }
    }

    private enum NetworkFieldKind {
        case phone, website
    }

    private func networkLabelKind(line: String) -> NetworkFieldKind? {
        let lower = line.lowercased()
        if (rules.mobileLabels + rules.officeLabels + rules.faxLabels)
            .contains(where: { lower.hasPrefix("\($0):") || lower.hasPrefix("\($0) ") }) {
            return .phone
        }
        if rules.websiteLabels.contains(where: { lower.hasPrefix("\($0):") || lower.hasPrefix("\($0) ") }) {
            return .website
        }
        return nil
    }

    /// 标签行 "网址：无" 中冒号后的值；无冒号时返回空串。
    private func valueAfterLabel(_ line: String, labels: [(label: String, target: LabelTarget)]) -> String {
        for separator in [":", "："] where line.contains(separator) {
            let value = TextNormalizer.sanitized(String(line.split(separator: Character(separator), maxSplits: 1).last ?? "")) ?? ""
            return value.lowercased()
        }
        return ""
    }

    // MARK: - 邮箱 / 网址 / 电话

    private func emails(in line: String) -> [String]? {
        let matches = regexMatches(in: line, pattern: "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}")
        guard !matches.isEmpty else { return nil }
        return matches.map { $0.lowercased() }
    }

    private func websites(in line: String) -> [String]? {
        let lower = line.lowercased()
        guard !lower.contains("@") else { return nil }
        let hasLabel = rules.websiteLabels.contains { lower.hasPrefix("\($0):") || lower.hasPrefix("\($0) ") }
        guard hasLabel || lower.contains("www.") || lower.contains("http://") || lower.contains("https://") else { return nil }
        let matches = regexMatches(in: line, pattern: "(?:https?://|www\\.)[A-Za-z0-9][A-Za-z0-9.-]*(?:/[^\\s]*)?", caseInsensitive: true)
        guard !matches.isEmpty else { return nil }
        return matches.map { url in
            var value = url
            while let last = value.last, ",.;)".contains(last) { value = String(value.dropLast()) }
            return value
        }
    }

    private func phones(in line: String) -> [(kind: PhoneKind, value: String)]? {
        let matches = regexMatches(in: line, pattern: "\\+?\\d[\\d\\s().-]{5,}\\d")
        guard !matches.isEmpty else { return nil }
        let labelKind = explicitPhoneKind(for: line)
        return matches.compactMap { raw -> (PhoneKind, String)? in
            let digits = raw.filter(\.isNumber)
            guard digits.count >= 7 else { return nil }
            let kind = labelKind ?? Self.inferredPhoneKind(digits)
            return (kind, normalizePhone(raw))
        }
    }

    private func explicitPhoneKind(for line: String) -> PhoneKind? {
        let lower = line.lowercased()
        if hasLabelPrefix(lower, rules.faxLabels) { return .fax }
        if hasLabelPrefix(lower, rules.mobileLabels) { return .mobile }
        if hasLabelPrefix(lower, rules.officeLabels) { return .office }
        if lower.contains("mobile") || lower.contains("cell") || lower.contains("手机") { return .mobile }
        if lower.contains("fax") || lower.contains("传真") { return .fax }
        return nil
    }

    private func hasLabelPrefix(_ lower: String, _ labels: [String]) -> Bool {
        labels.contains { lower.hasPrefix("\($0):") || lower.hasPrefix("\($0) ") }
    }

    /// 无标签时的兜底：中国大陆 11 位 1 开头视为手机，其余按座机处理。
    private static func inferredPhoneKind(_ digits: String) -> PhoneKind {
        var value = digits
        for prefix in ["0086", "86"] where value.hasPrefix(prefix) && value.count > 11 {
            value = String(value.dropFirst(prefix.count))
            break
        }
        return value.count == 11 && value.hasPrefix("1") ? .mobile : .office
    }

    private func normalizePhone(_ raw: String) -> String {
        let cleaned = raw.replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .replacingOccurrences(of: "-", with: " ")
            .split(separator: " ").joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        let compact = raw.replacingOccurrences(of: " ", with: "")
        var digits = String(raw.filter(\.isNumber))

        // 展示格式契约（与 docs/test-cards/ground-truth.json 一致）：
        //   +86 手机 → 3-4-4；+86 座机 → 去掉国家码并补回 0 区号；
        //   0086 / 86 前缀 → 统一为本地的 3-4-4；
        //   其它 +国际码 → 去括号/连字符，保留分组空格；
        //   无国家码 → 去括号、连字符换空格。
        if compact.hasPrefix("+86") {
            if digits.hasPrefix("86") { digits = String(digits.dropFirst(2)) }
            if digits.count == 11, digits.hasPrefix("1") {
                return Self.formatChineseMobile(digits)
            }
            var body = cleaned.hasPrefix("+86")
                ? String(cleaned.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                : cleaned
            if !body.hasPrefix("0") { body = "0" + body }
            return body
        }
        if digits.hasPrefix("0086") || (digits.hasPrefix("86") && digits.count > 11) {
            if digits.hasPrefix("0086") {
                digits = String(digits.dropFirst(4))
            } else {
                digits = String(digits.dropFirst(2))
            }
            if digits.count == 11, digits.hasPrefix("1") {
                return Self.formatChineseMobile(digits)
            }
            return cleaned
        }
        // 其它 +国际码：国家码后按 3 位一组重排（+1 的 10 位本地号按 3-3-4）。
        // 前提是原号码在国家码后留有空格或括号，才能确定国家码的边界。
        if compact.hasPrefix("+") {
            let parts = cleaned.dropFirst().split(separator: " ", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { return cleaned }
            let code = parts[0].filter(\.isNumber)
            let national = Array(parts[1].filter(\.isNumber))
            guard !code.isEmpty, !national.isEmpty else { return cleaned }
            var groups: [String] = []
            if national.count == 10 {
                groups = [String(national[0..<3]), String(national[3..<6]), String(national[6..<10])]
            } else {
                var start = 0
                while start < national.count {
                    groups.append(String(national[start..<min(start + 3, national.count)]))
                    start += 3
                }
            }
            return "+\(code) " + groups.joined(separator: " ")
        }
        if digits.count == 11, digits.hasPrefix("1") {
            return Self.formatChineseMobile(digits)
        }
        return cleaned
    }

    private static func formatChineseMobile(_ digits: String) -> String {
        let chars = Array(digits)
        return "\(String(chars[0...2])) \(String(chars[3...6])) \(String(chars[7...10]))"
    }

    // MARK: - 语义启发式

    private func isAbsentPlaceholder(_ value: String) -> Bool {
        let lower = value.lowercased()
        return rules.absentPlaceholders.contains { lower == $0 }
    }

    /// 多词英文行里含公司后缀词的，判定为公司名，避免被姓名启发式抢走。
    private func isCompanySuffixLine(_ line: String) -> Bool {
        let lower = line.lowercased()
        let tokens = Self.tokens(lower)
        return tokens.count > 1 && rules.companyKeywords.contains { containsKeyword(lower, tokens: tokens, keyword: $0) }
    }

    private func isJobTitle(_ line: String) -> Bool {
        let lower = line.lowercased()
        guard !lower.contains("@"), !lower.contains("www.") else { return false }
        let tokens = Self.tokens(lower)
        return rules.jobTitleKeywords.contains { containsKeyword(lower, tokens: tokens, keyword: $0) }
    }

    private func isDepartment(_ line: String) -> Bool {
        for pattern in rules.departmentPatterns {
            if line.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil { return true }
        }
        if rules.departmentKeywords.contains(where: { line.contains($0) }) { return true }
        // 中文部门后缀："人力资源部""研发中心"；至少 4 字以避免与姓名混淆。
        return line.count >= 4 && rules.departmentSuffixes.contains { line.hasSuffix($0) }
    }

    private func isCompany(_ line: String) -> Bool {
        let lower = line.lowercased()
        guard !lower.contains("@"), !lower.contains("www."), !lower.contains("http") else { return false }
        // Logo 缩写（"CO"/"TJ"）可能恰好等于公司关键词，先排除再匹配。
        guard !isLogoLike(line) else { return false }
        let tokens = Self.tokens(lower)
        guard rules.companyKeywords.contains(where: { containsKeyword(lower, tokens: tokens, keyword: $0) }) else { return false }
        // 含街道后缀的行归地址："1 University Drive, Berkeley, CA" 里有 "University"。
        return !isAddressLike(line)
    }

    /// 中文或多词关键词用子串匹配；单词关键词用词元匹配，避免 "co" 命中 "color"。
    private func containsKeyword(_ lower: String, tokens: [Substring], keyword: String) -> Bool {
        let needsSubstring = keyword.unicodeScalars.contains { !$0.isASCII }
            || keyword.contains("-") || keyword.contains(".") || keyword.contains(" ")
        if needsSubstring { return lower.contains(keyword) }
        return tokens.contains { $0 == Substring(keyword) }
    }

    private static func tokens(_ lower: String) -> [Substring] {
        lower.split { !$0.isLetter && !$0.isNumber && $0 != "&" }
    }

    private func isNameLike(_ line: String) -> Bool {
        let candidate = stripHonorific(line)
        guard !isJobTitle(candidate), !isCompany(candidate), !isDepartment(candidate), !isAddressLike(candidate) else { return false }
        guard !candidate.contains("@"), !candidate.contains("www.") else { return false }
        // 含职位/公司关键词的多词行不可能是姓名："Account Executive"。
        let tokens = Self.tokens(candidate.lowercased())
        let containsVocabulary = rules.jobTitleKeywords.contains { containsKeyword(candidate.lowercased(), tokens: tokens, keyword: $0) }
            || rules.companyKeywords.contains { containsKeyword(candidate.lowercased(), tokens: tokens, keyword: $0) }
        guard !containsVocabulary else { return false }
        let cjk = candidate.filter { $0.unicodeScalars.first.map(isCJK) ?? false }
        if !cjk.isEmpty {
            let compact = candidate.replacingOccurrences(of: " ", with: "")
            return cjk.count == compact.count && (2...4).contains(cjk.count)
        }
        let words = candidate.split(separator: " ").map(String.init)
        guard (2...3).contains(words.count) else { return false }
        // 末尾是 Ltd / Consulting / Lab 等组织后缀的多词行是公司，不是姓名。
        guard !isCompanySuffixLine(candidate) else { return false }
        return words.allSatisfy { $0.allSatisfy(\.isLetter) }
    }

    /// token 化后只剩 isAllUppercase 的大写缩写行。规则：全部字母大写，且
    /// 普通正文中不会全大写出现的 >2 字母 token 也视为 Logo（TJ / ABC / BR）。
    private func isLogoLike(_ line: String) -> Bool {
        let letters = line.filter(\.isLetter)
        guard (2...5).contains(letters.count) else { return false }
        guard letters.unicodeScalars.allSatisfy(\.isASCII) else { return false }
        let alphanumerics = line.filter { $0.isLetter || $0.isNumber }
        guard line.count == letters.count || alphanumerics.count == letters.count else { return false }
        return line == line.uppercased()
    }

    /// 竖排版式会把姓名逐字识别成多行，中间还可能夹着公司、部门、职位行。
    /// 识别到 2–4 个单字行时按版面顺序合成一个姓名，但要求它们之间的每一行
    /// 都是组织/部门/职位类文本——其它内容（如第二张名片的姓名）不允许被吞掉。
    private func mergeVerticalNameFragments(_ lines: inout [String]) {
        let indices = lines.indices.filter { isSingleCJK(lines[$0]) }
        guard (2...4).contains(indices.count) else { return }
        for pair in zip(indices, indices.dropFirst()) {
            let bridge = lines[(pair.0 + 1)..<pair.1].filter { !isVerticalNameBridge($0) }
            guard bridge.isEmpty else { return }
        }
        let name = indices.map { lines[$0] }.joined()
        let removals = Set(indices)
        lines = lines.enumerated().filter { !removals.contains($0.offset) }.map(\.element)
        lines.insert(name, at: indices[0])
    }

    /// 竖排姓名两字之间允许夹着的行：公司 / 部门 / 职位。
    private func isVerticalNameBridge(_ line: String) -> Bool {
        isCompany(line) || isDepartment(line) || isJobTitle(line)
    }

    /// 取出"逐字成行"合并后的竖排姓名（2–4 个汉字整行、且不是职位/公司/部门词）。
    private func takeVerticalName(_ lines: inout [String]) -> String? {
        guard let index = lines.firstIndex(where: { line in
            let compact = line.replacingOccurrences(of: " ", with: "")
            let isCJKName = (2...4).contains(compact.count)
                && compact.allSatisfy { $0.unicodeScalars.first.map(isCJK) ?? false }
            return isCJKName && !isJobTitle(line) && !isDepartment(line)
                && !isCompany(line) && !isAddressLike(line)
        }) else { return nil }
        return lines.remove(at: index)
    }

    private func isSingleCJK(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.count == 1, let scalar = trimmed.unicodeScalars.first else { return false }
        return isCJK(scalar)
    }

    /// 去除姓名前的称谓（Dr. / Mr. / Prof. 等），保留人物姓名本体。
    private func stripHonorific(_ line: String) -> String {
        var words = line.split(separator: " ").map(String.init)
        while let first = words.first, rules.nameHonorifics.contains(first.lowercased()) {
            words.removeFirst()
        }
        return words.joined(separator: " ")
    }

    private func isAddressLike(_ line: String) -> Bool {
        if rules.addressTokens.contains(where: { line.contains($0) }) { return true }
        let lower = line.lowercased()
        // 英文街道后缀必须按整词匹配："Jordan" 里含 "rd"，但不是地址。
        let words = lower.split { !$0.isLetter && !$0.isNumber && $0 != "." }
        if rules.streetSuffixWords.contains(where: { words.contains(Substring($0)) }) { return true }
        let digits = line.filter(\.isNumber)
        return (digits.count == 5 || digits.count == 6) && digits.count == line.count
    }

    // MARK: - 工具

    private func takeFirst(_ lines: inout [String], where predicate: (String) -> Bool) -> String? {
        guard let index = lines.firstIndex(where: predicate) else { return nil }
        return lines.remove(at: index)
    }

    private func appendUnique(_ values: [String], to array: inout [String]) {
        for value in values where !array.contains(value) { array.append(value) }
    }

    private func regexMatches(in text: String, pattern: String, caseInsensitive: Bool = false) -> [String] {
        var options: NSRegularExpression.Options = []
        if caseInsensitive { options.insert(.caseInsensitive) }
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return [] }
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            .compactMap { Range($0.range, in: text) }
            .map { String(text[$0]) }
    }

    private func isCJK(_ scalar: Unicode.Scalar) -> Bool {
        (0x4E00...0x9FFF).contains(scalar.value) || (0x3400...0x4DBF).contains(scalar.value)
    }

    private func isASCII(_ scalar: Unicode.Scalar) -> Bool {
        scalar.value < 0x80
    }
}
