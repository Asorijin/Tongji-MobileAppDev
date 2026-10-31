import Foundation
#if canImport(CamCardDomain)
import CamCardDomain
#endif

/// vCard 3.0 导出（T19）。字段映射：
/// 姓名→FN/N、公司→ORG、职位→TITLE、手机→TEL;TYPE=CELL、
/// 办公电话→TEL;TYPE=WORK、传真→TEL;TYPE=FAX、邮箱→EMAIL、网址→URL、地址→ADR。
public enum VCardExporter {
    public enum ExportError: Error, LocalizedError {
        case nothingToExport

        public var errorDescription: String? {
            switch self {
            case .nothingToExport: return "名片没有任何可导出的字段"
            }
        }
    }

    public static func vCard(for card: BusinessCard) throws -> String {
        guard card.hasStructuredContent else { throw ExportError.nothingToExport }

        var lines: [String] = ["BEGIN:VCARD", "VERSION:3.0"]

        if let name = card.name {
            let parts = name.split(separator: " ").map(String.init)
            let family = parts.count > 1 ? parts.last! : ""
            let given = parts.count > 1 ? parts.dropLast().joined(separator: " ") : (parts.first ?? "")
            lines.append("N:\(escape(family));\(escape(given));;;")
            lines.append("FN:\(escape(name))")
        } else if let company = card.company {
            lines.append("FN:\(escape(company))")
        }

        if let company = card.company {
            lines.append("ORG:\(escape(company))")
        }
        if let title = card.jobTitle {
            lines.append("TITLE:\(escape(title))")
        }
        if let department = card.department {
            lines.append("X-DEPARTMENT:\(escape(department))")
        }
        for phone in card.mobiles {
            lines.append("TEL;TYPE=CELL:\(escape(phone))")
        }
        for phone in card.officePhones {
            lines.append("TEL;TYPE=WORK:\(escape(phone))")
        }
        for fax in card.faxes {
            lines.append("TEL;TYPE=FAX:\(escape(fax))")
        }
        for email in card.emails {
            lines.append("EMAIL;TYPE=INTERNET:\(escape(email))")
        }
        for site in card.websites {
            lines.append("URL:\(escape(site))")
        }
        if let address = card.address {
            lines.append("ADR;TYPE=WORK:;;\(escape(address));;;;")
        }
        if let postal = card.postalCode {
            lines.append("X-POSTAL-CODE:\(escape(postal))")
        }
        if let notes = card.notes {
            lines.append("NOTE:\(escape(notes))")
        } else if let raw = card.rawOCRText, !raw.isEmpty {
            lines.append("NOTE:\(escape(raw.replacingOccurrences(of: "\n", with: " ")))")
        }

        lines.append("END:VCARD")
        return lines.joined(separator: "\r\n") + "\r\n"
    }

    /// 写入临时文件，供分享面板以文件形式导出发送到系统联系人。
    @discardableResult
    public static func writeFile(for card: BusinessCard, in directory: URL) throws -> URL {
        let content = try vCard(for: card)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileName = "\(card.displayName.replacingOccurrences(of: "/", with: "-")).vcf"
        let url = directory.appendingPathComponent(fileName)
        try Data(content.utf8).write(to: url, options: .atomic)
        return url
    }

    public static func writeAll(cards: [BusinessCard], in directory: URL) throws -> URL {
        let content = try cards.map { try vCard(for: $0) }.joined()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("BusinessCards.vcf")
        try Data(content.utf8).write(to: url, options: .atomic)
        return url
    }

    /// 转义 RFC 6350 规定的特殊字符。
    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
}
