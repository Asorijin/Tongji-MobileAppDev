import Foundation
#if canImport(CamCardDomain)
import CamCardDomain
#endif

/// 名片图片的落盘存储。图片内容不进入 JSON，只保存相对路径。
public struct ImageStore {
    public let directory: URL
    private let fileManager = FileManager.default

    public init(directory: URL) {
        self.directory = directory
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// 保存图片并返回相对路径（相对 store 目录）。
    @discardableResult
    public func save(_ data: Data, id: UUID, suffix: String) throws -> String {
        let fileName = "\(id.uuidString)-\(suffix).jpg"
        try data.write(to: directory.appendingPathComponent(fileName), options: .atomic)
        return fileName
    }

    public func data(forRelativePath path: String?) -> Data? {
        guard let path else { return nil }
        return try? Data(contentsOf: directory.appendingPathComponent(path))
    }

    public func delete(_ path: String?) {
        guard let path else { return }
        try? fileManager.removeItem(at: directory.appendingPathComponent(path))
    }

    public func deleteAll(for card: BusinessCard) {
        delete(card.originalImagePath)
        delete(card.processedImagePath)
    }
}
