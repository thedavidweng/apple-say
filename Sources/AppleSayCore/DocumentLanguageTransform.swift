import Foundation

public struct DocumentTranslationUnit: Equatable, Sendable {
    public let id: Int
    public let text: String
}

/// Separates translatable speech from Timed Text syntax so a language service
/// never receives ownership of timestamps or metadata.
public struct DocumentTranslationPlan: Sendable {
    public let units: [DocumentTranslationUnit]
    private let document: String
    private let ranges: [NSRange]

    public init?(document: String) {
        let parsed = TimedDocumentParser.parse(document)
        guard parsed.format != .enhancedLRC else { return nil }

        self.document = document
        if parsed.format == .plainText {
            guard !document.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            ranges = [NSRange(document.startIndex..<document.endIndex, in: document)]
            units = [DocumentTranslationUnit(id: 0, text: document)]
            return
        }

        let matches = Self.lrcContent.matches(
            in: document,
            range: NSRange(document.startIndex..<document.endIndex, in: document)
        )
        let contentRanges = matches.compactMap { match -> NSRange? in
            let range = match.range(at: 1)
            guard range.location != NSNotFound, range.length > 0 else { return nil }
            return range
        }
        guard !contentRanges.isEmpty else { return nil }
        ranges = contentRanges
        units = contentRanges.enumerated().map { index, range in
            DocumentTranslationUnit(id: index, text: (document as NSString).substring(with: range))
        }
    }

    public func applying(_ translations: [String]) -> String {
        precondition(translations.count == ranges.count)
        let result = NSMutableString(string: document)
        for (range, translation) in zip(ranges, translations).reversed() {
            result.replaceCharacters(in: range, with: translation)
        }
        return result as String
    }

    private static let lrcContent = try! NSRegularExpression(
        pattern: #"(?m)^[ \t]*(?:\[[0-9]+:[0-5][0-9](?:\.[0-9]{1,3})?\])+([^\r\n]*)"#
    )
}

public enum TimedTextMarkup {
    public static func ranges(in document: String, intersecting enclosingRange: NSRange) -> [NSRange] {
        guard TimedDocumentParser.parse(document).format != .plainText else { return [] }
        let fullRange = NSRange(document.startIndex..<document.endIndex, in: document)
        return markup.matches(in: document, range: fullRange).compactMap { match in
            let intersection = NSIntersectionRange(match.range, enclosingRange)
            return intersection.length > 0 ? intersection : nil
        }
    }

    private static let markup = try! NSRegularExpression(
        pattern: #"\[[0-9]+:[0-5][0-9](?:\.[0-9]{1,3})?\]|<[0-9]+:[0-5][0-9](?:\.[0-9]{1,3})?>|\[(?:ar|al|ti|au|by|re|ve|length|offset):[^\[\]\r\n]*\]"#
    )
}
