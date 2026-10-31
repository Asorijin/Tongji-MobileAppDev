import Foundation
import XCTest
// iOS 工程直接测试 App 模块；SwiftPM 校验包中 Domain / Data 是独立模块。
#if os(iOS)
@testable import CamCardClone
#else
import CamCardData
import CamCardDomain
#endif

/// T12–T18 的数据层确定性用例：新增 / 编辑 / 删除 / 搜索 / 标签 / 持久化。
/// 与 iOS 版 RepositoryTests 使用同一套断言思路，这里跑在临时目录上。
@MainActor
final class CardStoreTests: XCTestCase {
    private var directory: URL!

    override func setUp() async throws {
        try await super.setUp()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("cardstore-test-\(UUID().uuidString)")
    }

    override func tearDown() async throws {
        if let directory {
            try? FileManager.default.removeItem(at: directory)
        }
        try await super.tearDown()
    }

    private func makeStore() -> CardStore {
        CardStore(directory: directory)
    }

    // MARK: - 新增与列表（T12）

    func testAddInsertsAtTopAndPersists() {
        let store = makeStore()
        store.add(BusinessCard(name: "朱宏明"))
        store.add(BusinessCard(name: "李娜"))
        XCTAssertEqual(store.cards.map(\.name), ["李娜", "朱宏明"], "新名片插入列表顶部")
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent("store.json").path))
    }

    func testStoreReloadsFromDisk() {
        let first = makeStore()
        let card = first.add(BusinessCard(name: "David Chen", company: "ABC Technologies Inc.",
                                          mobiles: ["+1 555 010 2233"]))
        let second = makeStore()
        XCTAssertEqual(second.cards.count, 1)
        XCTAssertEqual(second.card(withID: card.id)?.name, "David Chen")
        XCTAssertEqual(second.cards.first?.mobiles, ["+1 555 010 2233"])
    }

    func testCorruptedStoreFileIsIgnoredGracefully() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: directory.appendingPathComponent("store.json"))
        let store = makeStore()
        XCTAssertTrue(store.cards.isEmpty, "损坏的存档不应让 App 崩溃")
    }

    // MARK: - 编辑（T13）

    func testUpdateKeepsIdentityAndMovesValues() {
        let store = makeStore()
        let card = store.add(BusinessCard(name: "朱宏明"))
        var edited = card
        edited.jobTitle = "教授"
        edited.mobiles = ["138 1234 5678"]
        store.update(edited)

        let reloaded = makeStore()
        XCTAssertEqual(reloaded.cards.count, 1, "编辑不新增记录")
        XCTAssertEqual(reloaded.card(withID: card.id)?.jobTitle, "教授")
        XCTAssertEqual(reloaded.card(withID: card.id)?.mobiles, ["138 1234 5678"])
    }

    func testUpdateIgnoresUnknownCard() {
        let store = makeStore()
        store.update(BusinessCard(name: "Ghost"))
        XCTAssertTrue(store.cards.isEmpty)
    }

    // MARK: - 删除（T14 / T17）

    func testDeleteRemovesCardAndItsImages() throws {
        let store = makeStore()
        var card = store.add(BusinessCard(name: "陈晨"))
        let paths = try store.saveImages(original: Data([0x01]), processed: Data([0x02]), cardID: card.id)
        // 与 CardEditView 真实流程一致：先保存图片路径到名片，再更新入库。
        card.originalImagePath = paths.original
        card.processedImagePath = paths.processed
        store.update(card)
        XCTAssertNotNil(store.images.data(forRelativePath: paths.original))

        store.delete(cardID: card.id)
        XCTAssertTrue(store.cards.isEmpty)
        XCTAssertNil(store.images.data(forRelativePath: paths.original), "删除名片时图片一并清理")
        XCTAssertTrue(makeStore().cards.isEmpty, "删除已持久化")
    }

    // MARK: - 搜索（T15）

    func testSearchAcrossNameCompanyTitlePhoneEmail() {
        let store = makeStore()
        let zhuhongming = store.add(BusinessCard(
            name: "朱宏明", company: "同济大学", jobTitle: "教授",
            mobiles: ["138 1234 5678"], emails: ["zhuhm@example.edu.cn"]))
        let david = store.add(BusinessCard(
            name: "David Chen", company: "ABC Technologies Inc.", jobTitle: "Technical Director",
            officePhones: ["555 010 8899"], emails: ["david.chen@example.com"]))

        XCTAssertEqual(store.search("朱宏明").map(\.id), [zhuhongming.id])
        XCTAssertEqual(store.search("同济").map(\.id), [zhuhongming.id])
        XCTAssertEqual(store.search("138").map(\.id), [zhuhongming.id])
        XCTAssertEqual(store.search("example.com").map(\.id), [david.id])
        XCTAssertEqual(store.search("technical director").map(\.id), [david.id])
        XCTAssertEqual(store.search("DAVID").map(\.id), [david.id], "搜索不区分大小写")
        XCTAssertEqual(store.search("不存在的关键词").count, 0)
        XCTAssertEqual(store.search("   ").count, 2, "空白查询返回全部")
    }

    func testSearchTreatsRegexCharactersLiterally() {
        let store = makeStore()
        store.add(BusinessCard(name: "A(B)C"))
        store.add(BusinessCard(name: "ABC"))
        // 子串匹配而非正则：括号应被当作普通字符。
        XCTAssertEqual(store.search("A(B)C").map(\.name), ["A(B)C"])
        XCTAssertEqual(store.search("[").count, 0)
    }

    // MARK: - 标签（T16）

    func testTagLifecycle() {
        let store = makeStore()
        let conference = store.createTag(named: "Conference")
        XCTAssertNotNil(conference)
        XCTAssertEqual(store.createTag(named: "  "), nil, "空标签名被拒绝")

        let duplicate = store.createTag(named: "conference")
        XCTAssertEqual(duplicate?.id, conference?.id, "同名标签不重复创建")

        let card = store.add(BusinessCard(name: "李娜"))
        store.toggleTag(conference!.id, on: card.id)
        XCTAssertEqual(store.card(withID: card.id)?.tagIDs, [conference!.id])
        XCTAssertEqual(store.cards(withTag: conference!.id).map(\.id), [card.id])

        store.toggleTag(conference!.id, on: card.id)
        XCTAssertTrue(store.card(withID: card.id)?.tagIDs.isEmpty ?? false, "再次切换即移除")

        store.toggleTag(conference!.id, on: card.id)
        store.deleteTag(conference!.id)
        XCTAssertTrue(store.tags.isEmpty)
        XCTAssertTrue(store.card(withID: card.id)?.tagIDs.isEmpty ?? false, "删除标签需从名片上摘除")
        XCTAssertTrue(makeStore().tags.isEmpty, "标签删除已持久化")
    }

    func testTagsAndCardsSurviveReload() {
        let store = makeStore()
        let tag = store.createTag(named: "Customer")!
        let card = store.add(BusinessCard(name: "王强"))
        store.toggleTag(tag.id, on: card.id)

        let reloaded = makeStore()
        XCTAssertEqual(reloaded.tags.map(\.name), ["Customer"])
        XCTAssertEqual(reloaded.tags(for: reloaded.cards[0]).map(\.name), ["Customer"])
    }

    // MARK: - 图片存储

    func testImageStoreRelativePaths() throws {
        let store = makeStore()
        let id = UUID()
        let paths = try store.saveImages(original: Data([0xAA, 0xBB]), processed: Data([0xCC]), cardID: id)
        XCTAssertEqual(paths.original, "\(id.uuidString)-original.jpg")
        XCTAssertEqual(paths.processed, "\(id.uuidString)-processed.jpg")
        XCTAssertEqual(store.images.data(forRelativePath: paths.processed), Data([0xCC]))
        XCTAssertNil(store.images.data(forRelativePath: nil))
    }

    // MARK: - 展示名兜底

    func testDisplayNameFallbackOrder() {
        XCTAssertEqual(BusinessCard(name: "朱宏明").displayName, "朱宏明")
        XCTAssertEqual(BusinessCard(company: "星辰科技").displayName, "星辰科技")
        XCTAssertEqual(BusinessCard(emails: ["a@example.com"]).displayName, "a@example.com")
        XCTAssertEqual(BusinessCard().displayName, "未命名名片")
        XCTAssertEqual(BusinessCard(name: "David Chen").displayInitials, "DC")
        XCTAssertEqual(BusinessCard(name: "朱宏明").displayInitials, "朱")
    }
}
