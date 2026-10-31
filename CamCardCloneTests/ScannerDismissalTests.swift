import XCTest
#if canImport(CamCardDomain)
import CamCardDomain
#else
@testable import CamCardClone
#endif

/// T20：扫描流程中的取消 / 返回不得残留页面，也不得写入任何数据。
/// 对应的 UI 路径见 `ExceptionPathUITests.testUnrecognizableImageOffersManualFallback`（模拟器）。
final class ScannerDismissalTests: XCTestCase {
    /// 识别成功 → 确认表单关闭（保存或取消）→ 扫描页一并关闭。
    func testRecognizedCardClosesScannerWhenFormCloses() {
        XCTAssertTrue(ScannerDismissal.shouldCloseScannerAfterEdit(sessionReady: true, isManualEntry: false))
    }

    /// 识别失败 → 手动录入 → 取消：必须回到名片夹（T20「取消后名片夹仍为空」）。
    func testManualEntryCancelClosesScanner() {
        XCTAssertTrue(ScannerDismissal.shouldCloseScannerAfterEdit(sessionReady: false, isManualEntry: true))
    }

    /// 识别失败且未打开表单：扫描页保留，用户可重试或改用手动录入。
    func testFailureOverlayWithoutFormKeepsScanner() {
        XCTAssertFalse(ScannerDismissal.shouldCloseScannerAfterEdit(sessionReady: false, isManualEntry: false))
    }

    /// 两种结束条件同时成立时也只会关闭一次（幂等）。
    func testBothConditionsCloseScanner() {
        XCTAssertTrue(ScannerDismissal.shouldCloseScannerAfterEdit(sessionReady: true, isManualEntry: true))
    }
}
