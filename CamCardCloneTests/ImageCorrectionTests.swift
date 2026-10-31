import XCTest
#if canImport(UIKit)
import UIKit
#endif
#if canImport(CamCardDomain)
import CamCardDomain
#else
@testable import CamCardClone
#endif

/// T06：名片区域检测与透视校正。
/// 本地（Windows）无法运行 Vision，本套用例在 iOS 模拟器上执行；Windows 下编译为空。
final class ImageCorrectionTests: XCTestCase {
    #if canImport(UIKit)
    private func fixtureData(_ id: String, _ variant: String) throws -> Data {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // CamCardCloneTests
            .deletingLastPathComponent()   // 仓库根目录
        let url = root.appendingPathComponent("docs/test-cards/images/\(id)_\(variant).png")
        return try Data(contentsOf: url)
    }

    /// C03 的 tilt 变体由脚本生成时带有一个已知的四角（见 fixtures/_manifest.json），
    /// 因此必须能自动检测到名片区域。
    func testDetectsTiltedCardQuad() throws {
        let data = try fixtureData("C03", "tilt")
        let corrected = try CardImageCorrector.correct(data)
        XCTAssertTrue(corrected.detected, "倾斜拍摄的名片应检测到区域")
        XCTAssertNotEqual(corrected.quad, .wholeImage)
        XCTAssertFalse(corrected.data.isEmpty)
    }

    /// 方向校正：EXIF 标注为旋转的图片，校正后必须能正常解码（尺寸不颠倒）。
    func testOrientedImageIsNormalized() throws {
        let source = UIImage(systemName: "rectangle.fill")!
        let data = try XCTUnwrap(source.jpegData(compressionQuality: 0.9))
        let corrected = try CardImageCorrector.correct(data)
        let image = UIImage(data: corrected.data)
        XCTAssertNotNil(image)
        XCTAssertEqual(image?.imageOrientation, .up) // normalizedUp 后重新编码为 up
    }

    func testUnreadableDataThrows() {
        XCTAssertThrowsError(try CardImageCorrector.correct(Data([0x00, 0x01, 0x02])))
    }
    #endif
}
