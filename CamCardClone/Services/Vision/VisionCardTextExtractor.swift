import Foundation

/// 端上 OCR：Apple Vision，离线可用、无调用费用。
public struct VisionCardTextExtractor: CardTextExtractor {
    private let ocr: OCRService
    private let languages: [String]

    public init(ocr: OCRService = VisionOCRService(), languages: [String] = ["zh-Hans", "en-US"]) {
        self.ocr = ocr
        self.languages = languages
    }

    public func extractText(from imageData: Data) async throws -> String {
        try await ocr.recognizeText(in: imageData, languages: languages).rawText
    }
}
