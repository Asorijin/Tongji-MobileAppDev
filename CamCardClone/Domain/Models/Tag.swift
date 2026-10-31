import Foundation

/// 用户自定义标签（如 Conference / Professor / Customer）。
public struct Tag: Codable, Identifiable, Hashable {
    public var id: UUID
    public var name: String
    public var createdAt: Date

    public init(id: UUID = UUID(), name: String, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
}
