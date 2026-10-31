import Foundation
import SwiftUI

/// 名片编辑草稿：既用于新识别名片的确认，也用于已有名片的编辑。
struct CardDraft {
    var card: BusinessCard
    var rawOCRText: String?
    var originalImageData: Data?
    var processedImageData: Data?

    init(card: BusinessCard = BusinessCard(), rawOCRText: String? = nil,
         originalImageData: Data? = nil, processedImageData: Data? = nil) {
        self.card = card
        self.rawOCRText = rawOCRText
        self.originalImageData = originalImageData
        self.processedImageData = processedImageData
    }

    init(fields: ParsedContactFields, rawOCRText: String,
         originalImageData: Data?, processedImageData: Data?) {
        self.init(
            card: BusinessCard(fields: fields, rawOCRText: rawOCRText),
            rawOCRText: rawOCRText,
            originalImageData: originalImageData,
            processedImageData: processedImageData
        )
    }
}
