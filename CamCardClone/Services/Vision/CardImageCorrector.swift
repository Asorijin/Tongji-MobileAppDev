import Foundation
#if canImport(UIKit)
import UIKit
import CoreImage
import Vision
#endif

/// 名片四角（归一化坐标，原点左下，与 Vision / Core Image 一致）。
public struct CardQuad: Codable, Equatable {
    public var topLeft: CGPointValue
    public var topRight: CGPointValue
    public var bottomRight: CGPointValue
    public var bottomLeft: CGPointValue

    public init(topLeft: CGPointValue, topRight: CGPointValue, bottomRight: CGPointValue, bottomLeft: CGPointValue) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomRight = bottomRight
        self.bottomLeft = bottomLeft
    }

    public static let wholeImage = CardQuad(
        topLeft: CGPointValue(x: 0, y: 1),
        topRight: CGPointValue(x: 1, y: 1),
        bottomRight: CGPointValue(x: 1, y: 0),
        bottomLeft: CGPointValue(x: 0, y: 0)
    )
}

public struct CGPointValue: Codable, Equatable {
    public var x: CGFloat
    public var y: CGFloat
    public init(x: CGFloat, y: CGFloat) {
        self.x = x
        self.y = y
    }
}

/// 图像校正结果。
public struct CorrectedImage {
    /// 校正后的名片图像（JPEG）。
    public let data: Data
    /// 原始图像（JPEG），与校正图一并保存。
    public let originalData: Data
    /// 程序识别的四角。
    public let quad: CardQuad
    /// 是否自动检测到了名片区域；false 时校正图即原图。
    public let detected: Bool

    public init(data: Data, originalData: Data, quad: CardQuad, detected: Bool) {
        self.data = data
        self.originalData = originalData
        self.quad = quad
        self.detected = detected
    }
}

public enum CorrectionError: Error, LocalizedError {
    case decodeFailed
    case renderFailed

    public var errorDescription: String? {
        switch self {
        case .decodeFailed: return "无法读取图片数据"
        case .renderFailed: return "图像校正渲染失败"
        }
    }
}

/// 名片区域检测与透视校正。
///
/// 优先使用 Vision 矩形检测，自动裁剪 + 透视校正；检测失败时返回原图，
/// 由用户进入手动调整（见 docs/spec.md §7.3）。
public enum CardImageCorrector {
    public static func correct(_ data: Data) throws -> CorrectedImage {
        #if canImport(UIKit)
        guard let source = UIImage(data: data)?.normalizedUp(), let cgImage = source.cgImage else {
            throw CorrectionError.decodeFailed
        }
        let quad = CardDetector.detectQuad(in: cgImage)
        let corrected = quad.flatMap { try? PerspectiveCorrector.warp(cgImage, quad: $0) }
        return CorrectedImage(
            data: encodeJPEG(corrected ?? cgImage),
            originalData: encodeJPEG(cgImage),
            quad: quad ?? .wholeImage,
            detected: quad != nil
        )
        #else
        throw CorrectionError.decodeFailed
        #endif
    }

    /// 用户手动调整四角后重新校正。
    public static func correct(_ data: Data, quad: CardQuad) throws -> CorrectedImage {
        #if canImport(UIKit)
        guard let image = UIImage(data: data)?.normalizedUp(), let cgImage = image.cgImage else {
            throw CorrectionError.decodeFailed
        }
        let corrected = try PerspectiveCorrector.warp(cgImage, quad: quad)
        return CorrectedImage(
            data: encodeJPEG(corrected),
            originalData: encodeJPEG(cgImage),
            quad: quad,
            detected: true
        )
        #else
        throw CorrectionError.decodeFailed
        #endif
    }

    #if canImport(UIKit)
    static func encodeJPEG(_ image: CGImage) -> Data {
        UIImage(cgImage: image).jpegData(compressionQuality: 0.85) ?? Data()
    }
    #endif
}

#if canImport(UIKit)
enum CardDetector {
    static func detectQuad(in image: CGImage) -> CardQuad? {
        let request = VNDetectRectanglesRequest()
        request.maximumObservations = 1
        request.minimumConfidence = 0.6
        request.minimumAspectRatio = 0.3
        request.maximumAspectRatio = 1.0
        request.quadratureTolerance = 30

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        guard (try? handler.perform([request])) != nil,
              let observation = request.results?.first else { return nil }
        return CardQuad(
            topLeft: CGPointValue(x: observation.topLeft.x, y: observation.topLeft.y),
            topRight: CGPointValue(x: observation.topRight.x, y: observation.topRight.y),
            bottomRight: CGPointValue(x: observation.bottomRight.x, y: observation.bottomRight.y),
            bottomLeft: CGPointValue(x: observation.bottomLeft.x, y: observation.bottomLeft.y)
        )
    }
}

enum PerspectiveCorrector {
    static func warp(_ image: CGImage, quad: CardQuad) throws -> CGImage {
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)

        let filter = CIFilter(name: "CIPerspectiveCorrection")!
        filter.setValue(CIImage(cgImage: image), forKey: kCIInputImageKey)
        filter.setValue(CIVector(x: quad.topLeft.x * width, y: quad.topLeft.y * height), forKey: "inputTopLeft")
        filter.setValue(CIVector(x: quad.topRight.x * width, y: quad.topRight.y * height), forKey: "inputTopRight")
        filter.setValue(CIVector(x: quad.bottomRight.x * width, y: quad.bottomRight.y * height), forKey: "inputBottomRight")
        filter.setValue(CIVector(x: quad.bottomLeft.x * width, y: quad.bottomLeft.y * height), forKey: "inputBottomLeft")

        guard let output = filter.outputImage else { throw CorrectionError.renderFailed }
        let context = CIContext()
        guard let cg = context.createCGImage(output, from: output.extent) else {
            throw CorrectionError.renderFailed
        }
        return cg
    }
}

extension UIImage {
    /// 按 EXIF 方向归一化，避免 OCR 读取到旋转文字。
    func normalizedUp() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
#endif
