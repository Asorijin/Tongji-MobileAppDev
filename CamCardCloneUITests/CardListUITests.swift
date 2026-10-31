import CoreGraphics
import XCTest

/// T01 / T12–T19 的确定性 UI 路径，在 iOS 模拟器上运行。
/// 固定起点：`-resetStore` 清空存档，`-seedSampleCards` 写入 3 张虚构示例名片
/// （朱宏明 / 赵敏 / David Chen，见 CamCardCloneApp.swift 的 SampleCards）。
///
/// 说明：模拟器上的 `typeText` 对中文输入法不可靠，因此所有输入统一使用 ASCII
/// （姓名改 David Chen → David Chen Jr.，标签 Conference，搜索词 David / ABC / 138）。
final class CardListUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        return app
    }

    private func seededApp() -> XCUIApplication {
        let app = launch(["-seedSampleCards"])
        XCTAssertTrue(app.navigationBars["名片夹"].waitForExistence(timeout: 20), "App 未启动到名片夹")
        return app
    }

    /// 标识符可能落在 cell / button / staticText 上，用不区分类型的查询定位。
    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func exists(_ element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        element.waitForExistence(timeout: timeout)
    }

    private func waitForLabel(_ element: XCUIElement, _ expected: String, timeout: TimeInterval = 10) -> Bool {
        let predicate = NSPredicate(format: "label == %@", expected)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    private func clearText(in field: XCUIElement) {
        guard let value = field.value as? String, !value.isEmpty else { return }
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count))
    }

    /// 打开详情页右上角的菜单并等待展开。
    ///
    /// iOS 18 模拟器上对 SwiftUI `Menu` 直接 `.tap()` 会先执行 AX scroll-to-visible，
    /// 计算出的点击点为 {-1, -1} 并报 `kAXErrorCannotComplete`（菜单其实可见、可手动点击）。
    /// 这是 XCUITest 对工具栏菜单的已知行为，因此用坐标点击绕开滚动步骤，不改被测 UI。
    private func openCardMenu(_ app: XCUIApplication) {
        let menu = app.buttons["detail-menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 10), "详情页应提供菜单按钮")
        menu.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons["编辑"].waitForExistence(timeout: 10), "详情菜单应展开")
    }

    /// 滚到列表底部（最新保存的名片排在最前，旧名片在下方）。
    private static func scrollToBottom(_ app: XCUIApplication) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
        for _ in 0..<3 { start.press(forDuration: 0.05, thenDragTo: end) }
    }

    // MARK: - T01 首次启动

    /// 首次启动 → 名片夹 → 空状态（含扫描/手动录入入口）。
    func testFirstLaunchShowsEmptyState() {
        // 用例按字母序执行，前面的用例会写入存档；-resetStore 才是真正的「首次启动」。
        let app = launch(["-resetStore"])
        XCTAssertTrue(exists(app.staticTexts["empty-state-title"]), "首次启动应显示空名片夹提示")
        XCTAssertTrue(app.buttons["empty-state-scan"].exists, "空状态应提供扫描入口")
        XCTAssertTrue(app.buttons["empty-state-manual"].exists, "空状态应提供手动录入入口")
        XCTAssertTrue(app.buttons["scan-button"].exists, "名片夹应提供扫描入口")
    }

    // MARK: - T13 详情

    /// 打开名片 → 正确显示全部保存字段。
    func testDetailShowsAllSavedFields() {
        let app = seededApp()
        // 全新存档写入顺序为 朱宏明 / 赵敏 / David Chen（头插法），旧名片在屏幕下方，
        // 小屏设备上需要滚动才能点击。
        let row = element(app, "card-row-朱宏明")
        XCTAssertTrue(exists(row))
        if !row.isHittable { Self.scrollToBottom(app) }
        row.tap()
        XCTAssertTrue(exists(app.navigationBars["名片详情"]))
        XCTAssertEqual(element(app, "detail-name").label, "朱宏明")
        XCTAssertTrue(element(app, "detail-mobile").label.contains("138 0000 0001"))
        XCTAssertTrue(element(app, "detail-office").label.contains("021 6598 1234"))
        XCTAssertTrue(element(app, "detail-fax").label.contains("021 6598 1235"))
        XCTAssertTrue(element(app, "detail-email").label.contains("zhuhm@example.edu.cn"))
        XCTAssertTrue(element(app, "detail-website").label.contains("www.example.edu.cn"))
        XCTAssertTrue(element(app, "detail-address").label.contains("上海市杨浦区四平路1239号"))
        XCTAssertTrue(element(app, "detail-postalCode").label.contains("200092"))
        XCTAssertTrue(element(app, "detail-department").label.contains("计算机科学与技术学院"))
        XCTAssertFalse(element(app, "detail-notes").exists, "示例名片没有备注，不应显示备注行")
        app.navigationBars["名片详情"].buttons.firstMatch.tap()
        XCTAssertTrue(exists(app.navigationBars["名片夹"]))
    }

    // MARK: - T14 编辑

    /// 编辑姓名 → 保存 → 详情页与列表正确更新。
    func testEditNameUpdatesListAndDetail() {
        let app = seededApp()
        element(app, "card-row-David Chen").tap()
        XCTAssertTrue(exists(app.navigationBars["名片详情"]))
        openCardMenu(app)
        app.buttons["编辑"].tap()

        let name = app.textFields["field-name"]
        XCTAssertTrue(exists(name))
        clearText(in: name)
        name.typeText("David Chen Jr.")
        app.buttons["edit-save"].tap()

        XCTAssertTrue(waitForLabel(element(app, "detail-name"), "David Chen Jr."), "详情页应显示修改后的姓名")
        app.navigationBars["名片详情"].buttons.firstMatch.tap()
        XCTAssertTrue(exists(element(app, "card-row-David Chen Jr.")), "列表应显示修改后的姓名")
        XCTAssertFalse(element(app, "card-row-David Chen").exists)
    }

    // MARK: - T15 搜索

    /// 搜索姓名 / 公司 / 电话 → 返回正确名片；无结果时显示提示；清空后恢复全部。
    func testSearchByNameCompanyAndPhone() {
        let app = seededApp()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(exists(search))
        search.tap()
        search.typeText("David")
        XCTAssertTrue(exists(element(app, "card-row-David Chen")))
        XCTAssertFalse(element(app, "card-row-朱宏明").exists, "搜索应过滤不匹配的名片")

        clearText(in: search)
        search.typeText("ABC")
        XCTAssertTrue(exists(element(app, "card-row-David Chen")), "应能按公司名搜索")
        XCTAssertFalse(element(app, "card-row-朱宏明").exists)

        clearText(in: search)
        search.typeText("138")
        XCTAssertTrue(exists(element(app, "card-row-朱宏明")), "应能按电话搜索")
        XCTAssertFalse(element(app, "card-row-David Chen").exists)

        clearText(in: search)
        search.typeText("zzz-no-match")
        XCTAssertTrue(exists(app.staticTexts["search-empty-title"]), "无匹配时应显示空结果提示")

        clearText(in: search)
        XCTAssertTrue(exists(element(app, "card-row-朱宏明")), "清空搜索后应恢复全部名片")
        XCTAssertTrue(element(app, "card-row-赵敏").exists)
        XCTAssertTrue(element(app, "card-row-David Chen").exists)
    }

    // MARK: - T16 标签

    /// 新建标签 → 添加到名片 → 按标签筛选 → 删除标签（名片保留）。
    func testTagCreateFilterAndDelete() {
        let app = seededApp()
        app.buttons["tags-button"].tap()
        XCTAssertTrue(exists(app.navigationBars["标签"]))

        let field = app.textFields["tag-name-field"]
        XCTAssertTrue(exists(field))
        field.tap()
        field.typeText("Conference")
        app.buttons["tag-add"].tap()
        XCTAssertTrue(exists(element(app, "tag-row-Conference")), "新标签应出现在标签列表")
        app.buttons["完成"].tap()

        // 给赵敏添加标签
        element(app, "card-row-赵敏").tap()
        XCTAssertTrue(exists(app.navigationBars["名片详情"]))
        openCardMenu(app)
        app.buttons["编辑"].tap()
        XCTAssertTrue(exists(app.textFields["field-name"]))
        app.buttons["Conference"].tap()
        app.buttons["edit-save"].tap()
        XCTAssertTrue(exists(app.navigationBars["名片详情"]))
        app.navigationBars["名片详情"].buttons.firstMatch.tap()

        // 按标签筛选
        app.buttons["tags-button"].tap()
        XCTAssertTrue(exists(element(app, "tag-row-Conference")))
        element(app, "tag-row-Conference").tap()
        XCTAssertTrue(exists(app.buttons["clear-tag-filter"]), "应出现标签筛选指示")
        XCTAssertTrue(exists(element(app, "card-row-赵敏")))
        XCTAssertFalse(element(app, "card-row-朱宏明").exists, "筛选后只显示带该标签的名片")

        // 清除筛选
        app.buttons["clear-tag-filter"].tap()
        XCTAssertTrue(exists(element(app, "card-row-朱宏明")))

        // 删除标签
        app.buttons["tags-button"].tap()
        let row = element(app, "tag-row-Conference")
        XCTAssertTrue(exists(row))
        row.swipeLeft()
        app.buttons["删除"].firstMatch.tap()
        XCTAssertFalse(exists(element(app, "tag-row-Conference"), timeout: 3), "标签应被删除")
        app.buttons["完成"].tap()
        XCTAssertTrue(exists(element(app, "card-row-赵敏")), "删除标签不应删除名片")
    }

    // MARK: - T17 删除

    /// 详情页删除（带确认）→ 返回列表 → 名片消失。
    func testDeleteFromDetailRemovesCard() {
        let app = seededApp()
        element(app, "card-row-David Chen").tap()
        openCardMenu(app)
        let deleteItem = app.buttons["删除"]
        XCTAssertTrue(deleteItem.waitForExistence(timeout: 10), "详情菜单应提供删除项")
        deleteItem.tap()
        // iOS 16 的 .alert(_:isPresented:) 标题取自渲染时的静态参数，明确匹配标题并不可靠；
        // 场景要求的是「删除前出现确认，且确认后才删除」，因此以弹窗与两个按钮作为判据。
        let confirm = app.alerts.firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 10), "删除前应弹出确认")
        XCTAssertTrue(confirm.buttons["删除"].exists, "确认弹窗应提供删除按钮")
        XCTAssertTrue(confirm.buttons["取消"].exists, "确认弹窗应提供取消按钮")
        confirm.buttons["删除"].tap()
        XCTAssertTrue(exists(app.navigationBars["名片夹"]))
        XCTAssertFalse(exists(element(app, "card-row-David Chen"), timeout: 5), "删除后名片应从列表消失")
        XCTAssertTrue(element(app, "card-row-朱宏明").exists)
    }

    // MARK: - T18 持久化

    /// 编辑保存 → 终止 App → 重新启动（不重置存档）→ 修改保持。
    func testEditsSurviveRelaunch() {
        let app = seededApp()
        element(app, "card-row-David Chen").tap()
        openCardMenu(app)
        app.buttons["编辑"].tap()
        let name = app.textFields["field-name"]
        XCTAssertTrue(exists(name))
        clearText(in: name)
        name.typeText("David Chen Sr.")
        app.buttons["edit-save"].tap()
        XCTAssertTrue(waitForLabel(element(app, "detail-name"), "David Chen Sr."))
        app.terminate()

        app.launchArguments = ["-seedSampleCards", "-keepStore"]   // 不重置存档（保留修改）
        app.launch()
        XCTAssertTrue(exists(element(app, "card-row-David Chen Sr.")), "重启后修改应保持")
    }

    // MARK: - T19 导出

    /// 详情 → 导出联系人（VCF）→ 出现系统分享面板；关闭后回到详情页。
    func testExportOpensShareSheet() {
        let app = seededApp()
        element(app, "card-row-David Chen").tap()
        XCTAssertTrue(exists(app.navigationBars["名片详情"]))
        openCardMenu(app)
        app.buttons["导出联系人（VCF）"].tap()

        // 分享面板的呈现方式随 iOS 版本 / 语言不同，命中任一系统元素即视为成功。
        let presentIndicators = [
            app.otherElements["ActivityListView"],
            app.navigationBars["UIActivityContentView"],
            app.buttons["Close"],
            app.buttons["关闭"],
            app.buttons["拷贝"],
            app.buttons["Copy"],
        ]
        var appeared = false
        let deadline = Date().addingTimeInterval(15)
        while Date() < deadline && !appeared {
            appeared = presentIndicators.contains { $0.exists }
            if !appeared { RunLoop.current.run(until: Date().addingTimeInterval(0.5)) }
        }
        XCTAssertTrue(appeared, "应出现系统分享面板。Debug 描述：\(app.debugDescription)")

        // 关闭面板：优先点关闭按钮，否则下拉关闭。
        let close = [app.buttons["Close"], app.buttons["关闭"], app.buttons["Done"], app.buttons["完成"]]
        if let dismiss = close.first(where: { $0.exists }) {
            dismiss.tap()
        } else {
            app.otherElements["ActivityListView"].swipeDown()
        }
        XCTAssertTrue(exists(app.navigationBars["名片详情"]), "关闭分享面板后应回到名片详情")
    }
}
