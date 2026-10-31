import XCTest
#if canImport(UIKit)
import UIKit
#endif

/// T20：取消、返回、权限拒绝、无法识别、字段为空等异常路径。
/// 这类用例需要在 iOS 模拟器上渲染真实界面，Windows 下编译为空。
final class ExceptionPathUITests: XCTestCase {
    #if canImport(UIKit)
    /// UI 测试进程同样运行在模拟器沙盒中，`#filePath` 是宿主机上的源码路径，
    /// 因此可以直接从仓库目录读取测试图像（仅测试进程使用，App 自身不访问该路径）。
    private func fixtureData(_ id: String, variant: String = "flat") -> Data? {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // CamCardCloneUITests
            .deletingLastPathComponent()   // 仓库根目录
        let url = root.appendingPathComponent("docs/test-cards/images/\(id)_\(variant).png")
        return try? Data(contentsOf: url)
    }

    private func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-resetStore"] + arguments
        app.launch()
        return app
    }

    private func waitForList(_ app: XCUIApplication) {
        XCTAssertTrue(app.navigationBars["名片夹"].waitForExistence(timeout: 20), "App 未启动到名片夹")
    }

    override func setUp() {
        continueAfterFailure = false
    }

    /// 空白卡片（C41）→ 校正成功但 OCR 无文本 → 显示错误 → "手动录入"进入空白表单
    /// → 空字段不可保存 → 取消后返回空名片夹（T20）。
    func testUnrecognizableImageOffersManualFallback() {
        let app = launch(["-scanFixture", "C41"])
        waitForList(app)
        app.buttons["empty-state-scan"].firstMatch.tap()

        // 识别可能成功也可能失败（取决于 Vision 对空白卡片的判定），两条路径都必须符合规格。
        let manual = app.buttons["scan-manual-fallback"]
        if manual.waitForExistence(timeout: 30) {
            manual.tap()
        }
        // CardEditView 用 HStack 自主排版（避免 iOS 16 LabeledContent 合并无障碍元素）。
        let nameField = app.textFields["field-name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 40), "应进入确认/手动录入表单")

        // 空白卡片不允许"编造"任何字段，因此空表单不可保存。
        XCTAssertEqual(nameField.value as? String, "姓名", "空白卡片不应产生姓名")
        XCTAssertFalse(app.buttons["edit-save"].isEnabled, "空表单不允许保存")
        app.buttons["edit-cancel"].tap()
        XCTAssertTrue(app.staticTexts["empty-state-title"].waitForExistence(timeout: 10),
                      "取消后回到空名片夹（T20：取消不产生数据）")
    }

    /// 相机权限被拒绝：扫描页给出说明 + 替代入口，取消后返回名片夹。
    func testCameraPermissionDeniedShowsGuidance() {
        let app = launch(["-cameraAuthorization", "denied"])
        waitForList(app)
        app.buttons["empty-state-scan"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["camera-permission-denied"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["scanner-camera"].exists, "权限拒绝时不显示拍照按钮")
        XCTAssertTrue(app.buttons["scanner-library"].exists, "仍可通过照片库导入")
        app.buttons["scanner-cancel"].tap()
        XCTAssertTrue(app.staticTexts["empty-state-title"].waitForExistence(timeout: 10))
    }

    /// 用户取消保存：识别卡片后取消，名片夹保持空状态且不写入任何数据（T20）。
    /// C40 把姓名放在侧栏、字段位于右列，是本数据集中阅读顺序最复杂的版式之一，
    /// 用来验证「识别成功 → 进入确认表单 → 取消不落库」。
    func testCancellingAfterRecognitionLeavesNoCard() {
        let app = launch(["-scanFixture", "C40"])
        waitForList(app)
        app.buttons["empty-state-scan"].firstMatch.tap()
        XCTAssertTrue(app.textFields["field-name"].waitForExistence(timeout: 60),
                      "合成名片应完成 OCR 并进入确认表单")
        app.buttons["edit-cancel"].tap()
        XCTAssertTrue(app.staticTexts["empty-state-title"].waitForExistence(timeout: 10))
    }

    /// 校正测试数据本身的可用性：本地图像必须能解码（防止 fixture 损坏而不自知）。
    func testFixtureImagesAreDecodable() {
        for variant in ["flat", "tilt", "rotate", "shadow"] {
            let data = fixtureData("C01", variant: variant)
            XCTAssertNotNil(data, "缺少 C01_\(variant).png")
            XCTAssertNotNil(data.flatMap { UIImage(data: $0) }, "C01_\(variant).png 无法解码")
        }
        XCTAssertNotNil(fixtureData("C41"), "缺少空白异常卡片 C41")
    }
    #endif
}
