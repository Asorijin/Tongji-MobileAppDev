import Foundation

/// 文本规范化：OCR 输出在不同引擎/平台之间存在可预期的非语义差异，
/// 在进入字段解析之前统一处理，保证解析规则与平台无关。
public enum TextNormalizer {
    private static let mapping: [Character: Character] = [
        "：": ":", "，": ",", "。": ".", "；": ";", "（": "(", "）": ")",
        "－": "-", "—": "-", "–": "-", "～": "~", "、": "/", "｜": "|", "　": " ",
        "\u{00A0}": " ", "\u{2028}": "\n", "\u{2029}": "\n", "\r": "\n",
    ]

    public static func normalize(_ text: String) -> String {
        var out = String()
        out.reserveCapacity(text.count)
        for character in text {
            if let replaced = mapping[character] {
                out.append(replaced)
            } else {
                out.append(character)
            }
        }
        return out
    }

    /// 按行切分并去除首尾空白；空行丢弃。
    public static func lines(_ text: String) -> [String] {
        normalize(text)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// 去除空白后比较，用于判断空值。
    public static func isBlank(_ value: String?) -> Bool {
        value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
    }

    public static func sanitized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
