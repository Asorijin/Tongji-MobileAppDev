import Combine
import SwiftUI

@main
struct CamCardCloneApp: App {
    @StateObject private var environment = AppEnvironment.makeForLaunch()

    var body: some Scene {
        WindowGroup {
            CardListView()
                .environmentObject(environment)
        }
    }
}

@MainActor
final class AppEnvironment: ObservableObject {
    let store: CardStore
    let textExtractor: CardTextExtractor

    #if DEBUG
    /// UI 测试注入的合成名片只自动扫描一次：用户取消保存后再次打开扫描页，
    /// 应当看到正常的拍摄 / 导入选择界面。
    private(set) static var pendingInjectedScan = true
    static func consumeInjectedScan() { pendingInjectedScan = false }
    #endif

    /// 观察者转发：CardStore 是独立的 ObservableObject，持有它的 AppEnvironment 不会自动转发变化。
    /// 不订阅的话，列表 / 详情 / 标签页在增删改之后不会随数据刷新。
    private var storeObservation: AnyCancellable?

    init(store: CardStore, textExtractor: CardTextExtractor = VisionCardTextExtractor()) {
        self.store = store
        self.textExtractor = textExtractor
        storeObservation = store.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    /// UI 测试通过 `-resetStore` 启动参数获得干净的数据目录。
    static func makeForLaunch() -> AppEnvironment {
        let arguments = ProcessInfo.processInfo.arguments
        // -resetStore 显式清空；-seedSampleCards 默认也从干净存档开始（除非同时给了 -keepStore，
        // 用于 T18 的 Kill App → Relaunch 验证）。普通手动启动不带这些参数，不影响用户数据。
        let shouldReset = arguments.contains("-resetStore")
            || (arguments.contains("-seedSampleCards") && !arguments.contains("-keepStore"))
        if shouldReset {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            try? FileManager.default.removeItem(at: base.appendingPathComponent("CamCardClone"))
        }
        let environment = AppEnvironment(store: .makeDefault())
        #if DEBUG
        // UI 测试的固定起点：本地存档为空时写入示例名片（仅 Debug、仅显式启动参数）。
        if LaunchOptions.seedsSampleCards, environment.store.cards.isEmpty {
            SampleCards.install(into: environment.store)
        }
        #endif
        return environment
    }
}

#if DEBUG
/// 固定示例名片：数据全部为虚构信息，与 docs/test-cards 的合成名片一致的字段结构。
/// 只在 UI 测试（-seedSampleCards）中使用，不进入 Release 构建。
enum SampleCards {
    /// CardStore 是 @MainActor 隔离的；Makefile/CI 生成的 App 模块以并发检查编译，
    /// 这里显式标注主线程隔离，与调用方 AppEnvironment.makeForLaunch 一致。
    @MainActor
    static func install(into store: CardStore) {
        let colleague = store.createTag(named: "同事")
        let client = store.createTag(named: "客户")

        var cards = [
            makeCard(
                name: "朱宏明", company: "同济大学", jobTitle: "教授",
                department: "计算机科学与技术学院", mobile: "138 0000 0001",
                office: "021 6598 1234", fax: "021 6598 1235",
                email: "zhuhm@example.edu.cn", website: "www.example.edu.cn",
                address: "上海市杨浦区四平路1239号", postal: "200092"
            ),
            makeCard(
                name: "赵敏", company: "星辰科技有限公司", jobTitle: "产品经理",
                mobile: "138 0000 0002", office: "010 5888 0002",
                email: "zhaomin@example.com", address: "北京市海淀区中关村大街1号"
            ),
            makeCard(
                name: "David Chen", company: "ABC Technologies Inc.", jobTitle: "Technical Director",
                mobile: "+1 555 010 2233", office: "555 010 8899",
                email: "david.chen@example.com", address: "500 Market Street, San Francisco, CA"
            ),
        ]
        cards[0].tagIDs = [colleague?.id].compactMap { $0 }
        cards[1].tagIDs = [client?.id].compactMap { $0 }

        // store 以头插法保存，逆序写入后列表顺序为 朱宏明 / 赵敏 / David Chen。
        for card in cards.reversed() {
            store.add(card)
        }
    }

    private static func makeCard(
        name: String?, company: String?, jobTitle: String?,
        department: String? = nil, mobile: String? = nil, office: String? = nil,
        fax: String? = nil, email: String? = nil, website: String? = nil,
        address: String? = nil, postal: String? = nil
    ) -> BusinessCard {
        BusinessCard(
            name: name, company: company, jobTitle: jobTitle, department: department,
            mobiles: mobile.map { [$0] } ?? [], officePhones: office.map { [$0] } ?? [],
            faxes: fax.map { [$0] } ?? [], emails: email.map { [$0] } ?? [],
            websites: website.map { [$0] } ?? [], address: address, postalCode: postal
        )
    }
}
#endif
