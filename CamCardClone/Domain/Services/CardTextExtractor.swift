import Foundation

public protocol CardTextExtractor {
    func extractText(from imageData: Data) async throws -> String
}
