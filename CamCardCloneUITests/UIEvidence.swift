import XCTest

/// Week 6「UI 截图对比」的取证工具。
///
/// 把关键页面截图作为 `XCTAttachment` 写进测试结果包；CI / 本地脚本用
/// `xcrun xcresulttool export attachments` 导出为 PNG，供与 `docs/spec.md`
/// 的页面状态逐项人工比对。截图只来自本 App 的模拟器运行，不涉及参考 App。
///
/// 放在单独的 Activity 里附加，`.keepAlways` 保证通过用例的截图也会被保留
/// （XCTest 默认只在失败时保留附件）。
enum UIEvidence {
    /// 截取 App 当前界面并附加到测试结果。`name` 会出现在导出文件名中，保持 ASCII。
    static func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        XCTContext.runActivity(named: "截图 \(name)") { activity in
            activity.add(attachment)
        }
    }
}
