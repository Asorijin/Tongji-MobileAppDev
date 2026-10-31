import Foundation
import XCTest
#if canImport(CamCardDomain)
import CamCardDomain
import CamCardExport
#else
@testable import CamCardClone
#endif

/// T19 的确定性部分：BusinessCard → vCard 3.0 字段映射。
final class VCardExporterTests: XCTestCase {
    private func makeCard() -> BusinessCard {
        BusinessCard(
            name: "David Chen",
            company: "ABC Technologies Inc.",
            jobTitle: "Technical Director",
            department: "Engineering",
            mobiles: ["+1 555 010 2233"],
            officePhones: ["555 010 8899"],
            faxes: ["555 010 1122"],
            emails: ["david.chen@example.com"],
            websites: ["www.example.com"],
            address: "500 Market Street, San Francisco, CA",
            postalCode: "94105",
            notes: "Met at Mobile Computing Conference"
        )
    }

    func testCoreFieldsAreMapped() throws {
        let vcard = try VCardExporter.vCard(for: makeCard())
        XCTAssertTrue(vcard.hasPrefix("BEGIN:VCARD\r\nVERSION:3.0\r\n"))
        XCTAssertTrue(vcard.hasSuffix("END:VCARD\r\n"))
        XCTAssertTrue(vcard.contains("\r\nFN:David Chen\r\n"))
        XCTAssertTrue(vcard.contains("N:Chen;David;;;\r\n"))
        XCTAssertTrue(vcard.contains("\r\nORG:ABC Technologies Inc.\r\n"))
        XCTAssertTrue(vcard.contains("\r\nTITLE:Technical Director\r\n"))
        XCTAssertTrue(vcard.contains("\r\nTEL;TYPE=CELL:+1 555 010 2233\r\n"))
        XCTAssertTrue(vcard.contains("\r\nTEL;TYPE=WORK:555 010 8899\r\n"))
        XCTAssertTrue(vcard.contains("\r\nTEL;TYPE=FAX:555 010 1122\r\n"))
        XCTAssertTrue(vcard.contains("\r\nEMAIL;TYPE=INTERNET:david.chen@example.com\r\n"))
        XCTAssertTrue(vcard.contains("\r\nURL:www.example.com\r\n"))
        XCTAssertTrue(vcard.contains("ADR;TYPE=WORK:;;500 Market Street\\, San Francisco\\, CA;;;;"))
        XCTAssertTrue(vcard.contains("\r\nNOTE:Met at Mobile Computing Conference\r\n"))
    }

    func testCompanyOnlyCardExportsFilenOff() throws {
        let card = BusinessCard(company: "星辰科技有限公司", emails: ["info@example.cn"])
        let vcard = try VCardExporter.vCard(for: card)
        XCTAssertFalse(vcard.contains("\r\nN:"), "无姓名时不应生成空 N 字段")
        XCTAssertTrue(vcard.contains("\r\nFN:星辰科技有限公司\r\n"))
        XCTAssertTrue(vcard.contains("\r\nORG:星辰科技有限公司\r\n"))
    }

    func testSpecialCharactersAreEscaped() throws {
        let card = BusinessCard(name: "Smith, John", company: "A;B\\C", notes: "line1\nline2")
        let vcard = try VCardExporter.vCard(for: card)
        XCTAssertTrue(vcard.contains("FN:Smith\\, John"))
        XCTAssertTrue(vcard.contains("ORG:A\\;B\\\\C"))
        XCTAssertTrue(vcard.contains("NOTE:line1\\nline2"))
    }

    func testRawOCRTextFallsBackToNote() throws {
        var card = BusinessCard(name: "李娜")
        card.rawOCRText = "李娜\nAssociate Professor"
        let vcard = try VCardExporter.vCard(for: card)
        XCTAssertTrue(vcard.contains("NOTE:李娜 Associate Professor"))
    }

    func testEmptyCardThrows() {
        XCTAssertThrowsError(try VCardExporter.vCard(for: BusinessCard())) { error in
            guard case VCardExporter.ExportError.nothingToExport = error else {
                return XCTFail("应为 nothingToExport，实际：\(error)")
            }
        }
    }

    func testWriteAllJoinsMultipleCards() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("vcard-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = try VCardExporter.writeAll(cards: [makeCard(), BusinessCard(name: "李娜")], in: directory)
        let text = try String(contentsOf: url, encoding: .utf8)
        XCTAssertEqual(text.components(separatedBy: "BEGIN:VCARD").count - 1, 2)
        XCTAssertEqual(text.components(separatedBy: "END:VCARD").count - 1, 2)
    }
}
