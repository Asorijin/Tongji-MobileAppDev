import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// 调试 / UI 测试启动参数。
///
/// UI 测试无法操作相机，因此通过启动参数把打包内的合成名片注入识别链路：
///   -scanFixture C03        使用 docs/test-cards/fixtures 对应的合成名片
///   -scanFixtureVariant tilt 变体：flat（默认）/ tilt / rotate / shadow
///   -resetStore             启动前清空本地存档（见 AppEnvironment.makeForLaunch）
///
/// Release 构建中书签仍是 true 但参数不会被设置，行为与普通启动一致。
enum LaunchOptions {
    static let arguments = ProcessInfo.processInfo.arguments

    static var injectedScanFixtureID: String? {
        value(after: "-scanFixture")
    }

    static var injectedScanVariant: String {
        value(after: "-scanFixtureVariant") ?? "flat"
    }

    /// UI 测试无法操作系统权限弹窗，用启动参数模拟相机权限结果（T03）。
    /// 仅 DEBUG 有效，取值 "denied" / "authorized"。
    static var cameraAuthorizationOverride: String? {
        #if DEBUG
        value(after: "-cameraAuthorization")
        #else
        nil
        #endif
    }

    /// 首次启动写入固定示例名片（T13 详情 / T14 编辑 / T15 搜索 / T17 删除 / T19 导出）。
    /// 仅在本地存档为空时生效，UI 测试配合 -resetStore 使用。
    static var seedsSampleCards: Bool {
        #if DEBUG
        arguments.contains("-seedSampleCards")
        #else
        false
        #endif
    }

    /// UI 测试的重启验证（T18）：第二次启动时保留已有存档，
    /// 用来模拟「Kill App → Relaunch」。
    static var keepsStore: Bool {
        #if DEBUG
        arguments.contains("-keepStore")
        #else
        false
        #endif
    }

    private static func value(after flag: String) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }
}

/// 读取 App 包内的合成测试名片图像（docs/test-cards/images/Cxx_<variant>.png）。
enum Fixtures {
    static func imageData(id: String, variant: String = "flat") -> Data? {
        #if canImport(UIKit)
        // 资源由 project.yml 的 Debug 构建脚本原样拷贝到 App.app/TestCardFixtures/。
        // 部分测试宿主环境下 Bundle.main 可能不同，两种方式都尝试。
        let candidates = [
            Bundle.main.resourceURL?.appendingPathComponent("TestCardFixtures/\(id)_\(variant).png"),
            Bundle.main.url(forResource: "\(id)_\(variant)", withExtension: "png", subdirectory: "TestCardFixtures"),
        ]
        for case let url? in candidates {
            if let data = try? Data(contentsOf: url) { return data }
        }
        #endif
        return nil
    }
}
