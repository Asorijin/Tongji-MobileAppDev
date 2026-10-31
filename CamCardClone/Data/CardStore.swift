import Foundation
#if canImport(CamCardDomain)
import CamCardDomain
#endif
#if canImport(Combine)
import Combine
#else
/// Windows / Linux 的 SwiftPM 校验环境没有 Combine；提供最小协议占位，
/// 使数据层可以在本地编译并运行同样的 XCTest 用例。iOS 构建使用真正的 Combine。
public protocol ObservableObject: AnyObject {}
#endif

/// 本地持久化的名片与标签仓库。
///
/// - 落盘位置由调用方传入（App 使用 Application Support，测试使用临时目录）。
/// - 写入采用原子写，避免进程被杀导致 JSON 损坏（T18 持久化）。
/// - 搜索覆盖姓名、公司、职位、电话、邮箱（T15）。
@MainActor
public final class CardStore: ObservableObject {
    public private(set) var cards: [BusinessCard] = [] {
        didSet { notifyChange() }
    }
    public private(set) var tags: [Tag] = [] {
        didSet { notifyChange() }
    }

    #if canImport(Combine)
    public let objectWillChange = ObservableObjectPublisher()

    private func notifyChange() {
        objectWillChange.send()
    }
    #else
    private func notifyChange() {}
    #endif

    public let images: ImageStore
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private struct Payload: Codable {
        var cards: [BusinessCard]
        var tags: [Tag]
    }

    public init(directory: URL, fileManager: FileManager = .default) {
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        self.fileURL = directory.appendingPathComponent("store.json")
        self.images = ImageStore(directory: directory.appendingPathComponent("images"))
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
        load()
    }

    public static func makeDefault() -> CardStore {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return CardStore(directory: base.appendingPathComponent("CamCardClone"))
    }

    // MARK: - 持久化

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        guard let payload = try? decoder.decode(Payload.self, from: data) else { return }
        cards = payload.cards
        tags = payload.tags
    }

    private func persist() {
        let payload = Payload(cards: cards, tags: tags)
        guard let data = try? encoder.encode(payload) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    // MARK: - 名片 CRUD

    public func card(withID id: UUID) -> BusinessCard? {
        cards.first { $0.id == id }
    }

    @discardableResult
    public func add(_ card: BusinessCard) -> BusinessCard {
        var card = card
        card.updatedAt = Date()
        cards.insert(card, at: 0)
        persist()
        return card
    }

    public func update(_ card: BusinessCard) {
        guard let index = cards.firstIndex(where: { $0.id == card.id }) else { return }
        var updated = card
        updated.updatedAt = Date()
        cards[index] = updated
        persist()
    }

    public func delete(cardID: UUID) {
        guard let index = cards.firstIndex(where: { $0.id == cardID }) else { return }
        images.deleteAll(for: cards[index])
        cards.remove(at: index)
        persist()
    }

    public func saveImages(original: Data, processed: Data, cardID: UUID) throws -> (original: String, processed: String) {
        let originalPath = try images.save(original, id: cardID, suffix: "original")
        let processedPath = try images.save(processed, id: cardID, suffix: "processed")
        return (originalPath, processedPath)
    }

    // MARK: - 搜索

    public func search(_ query: String) -> [BusinessCard] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return cards }
        let needle = trimmed.lowercased()
        return cards.filter { card in
            let haystack = [
                card.name, card.company, card.jobTitle, card.department, card.address,
            ].compactMap { $0 } + card.mobiles + card.officePhones + card.faxes + card.emails
            return haystack.contains { $0.lowercased().contains(needle) }
        }
    }

    // MARK: - 标签

    @discardableResult
    public func createTag(named name: String) -> Tag? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let existing = tags.first(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return existing
        }
        let tag = Tag(name: trimmed)
        tags.append(tag)
        persist()
        return tag
    }

    public func deleteTag(_ tagID: UUID) {
        tags.removeAll { $0.id == tagID }
        for index in cards.indices {
            cards[index].tagIDs.removeAll { $0 == tagID }
        }
        persist()
    }

    public func toggleTag(_ tagID: UUID, on cardID: UUID) {
        guard let index = cards.firstIndex(where: { $0.id == cardID }) else { return }
        if cards[index].tagIDs.contains(tagID) {
            cards[index].tagIDs.removeAll { $0 == tagID }
        } else {
            cards[index].tagIDs.append(tagID)
        }
        cards[index].updatedAt = Date()
        persist()
    }

    public func tags(for card: BusinessCard) -> [Tag] {
        tags.filter { card.tagIDs.contains($0.id) }
    }

    public func cards(withTag tagID: UUID) -> [BusinessCard] {
        cards.filter { $0.tagIDs.contains(tagID) }
    }
}
