import Foundation
#if canImport(UIKit)
import UIKit
import Vision
#endif

/// OCR 服务抽象。保留原始文本，供人工校正与错误分析使用。
public protocol OCRService {
    func recognizeText(in imageData: Data, languages: [String]) async throws -> OCRResult
}

public struct OCRResult {
    /// 按观察到的行顺序拼接的原始文本（保留换行）。
    public let rawText: String
    /// 每个文本块及其置信度，用于字段级错误分析。
    public let blocks: [OCRTextBlock]
    public init(rawText: String, blocks: [OCRTextBlock]) {
        self.rawText = rawText
        self.blocks = blocks
    }
}

public struct OCRTextBlock {
    public let text: String
    public let confidence: Float
    /// 归一化包围盒（左下原点），用于版式分析。
    public let boundingBox: CGRect?
    public init(text: String, confidence: Float, boundingBox: CGRect?) {
        self.text = text
        self.confidence = confidence
        self.boundingBox = boundingBox
    }
}

public enum OCRError: Error, LocalizedError {
    case emptyResult
    case imageUnreadable

    public var errorDescription: String? {
        switch self {
        case .emptyResult: return "未能从名片中识别出文字，请重拍或手动录入"
        case .imageUnreadable: return "图片无法读取"
        }
    }
}

#if canImport(UIKit)
/// Apple Vision 实现的 OCR，端上运行、无需联网，中英文混合识别。
public final class VisionOCRService: OCRService {
    public init() {}

    public func recognizeText(in imageData: Data, languages: [String]) async throws -> OCRResult {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    continuation.resume(returning: try Self.recognize(imageData, languages: languages))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func recognize(_ data: Data, languages: [String]) throws -> OCRResult {
        guard let image = UIImage(data: data)?.cgImage else { throw OCRError.imageUnreadable }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = languages.isEmpty ? ["zh-Hans", "en-US"] : languages
        request.minimumTextHeight = 0.01

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])
        guard let observations = request.results, !observations.isEmpty else { throw OCRError.emptyResult }

        let blocks = observations
            .compactMap { observation -> OCRTextBlock? in
                guard let candidate = observation.topCandidates(1).first else { return nil }
                return OCRTextBlock(
                    text: candidate.string,
                    confidence: candidate.confidence,
                    boundingBox: observation.boundingBox
                )
            }
        guard !blocks.isEmpty else { throw OCRError.emptyResult }

        let rawText = blocks.map(\.text).joined(separator: "\n")
        return OCRResult(rawText: rawText, blocks: blocks)
    }
}
#endif
