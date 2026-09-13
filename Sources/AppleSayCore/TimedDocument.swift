import Foundation

public enum DocumentFormat: String, Sendable {
    case plainText = "Plain Text", lrc = "LRC", enhancedLRC = "Enhanced LRC"
}

public struct TimedFragment: Equatable, Sendable {
    public let start: Double
    public let text: String
    public let end: Double?
}

public struct Segment: Equatable, Sendable {
    public let start: Double
    public let text: String
    public let fragments: [TimedFragment]
    public let line: Int
}

public struct ParsedDocument: Equatable, Sendable {
    public let format: DocumentFormat
    public let segments: [Segment]
}

enum TimedDocumentParser {
    private static let plain = ParsedDocument(format: .plainText, segments: [])
    private static let stamp = #"([0-9]+):([0-5][0-9])(?:\.([0-9]{1,3}))?"#
    private static let lineTag = try! NSRegularExpression(pattern: #"^\["# + stamp + #"\]"#)
    private static let inlineTag = try! NSRegularExpression(pattern: #"<"# + stamp + #">"#)
    private static let metadata = try! NSRegularExpression(pattern: #"^\[(ar|al|ti|au|by|re|ve|length):[^\[\]\r\n]*\]$"#)
    private static let offsetTag = try! NSRegularExpression(pattern: #"^\[offset:([+-]?[0-9]+)\]$"#)

    static func parse(_ text: String) -> ParsedDocument {
        var segments: [Segment] = []
        var offset: Double?
        var hasFragments = false
        for (index, raw) in text.components(separatedBy: .newlines).enumerated() {
            var line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || matches(metadata, line) { continue }
            if let match = offsetTag.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
                guard offset == nil, let range = Range(match.range(at: 1), in: line),
                      let value = Double(line[range]), value.isFinite else { return plain }
                offset = value / 1000
                continue
            }
            var starts: [Double] = []
            while let match = lineTag.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
                guard let time = timestamp(match, in: line) else { return plain }
                starts.append(time)
                line = String(line.dropFirst(match.range.length))
            }
            guard !starts.isEmpty, !line.hasPrefix("[") else { return plain }
            let fragments: [TimedFragment]
            if line.contains("<") || line.contains(">") {
                guard starts.count == 1, let parsed = parseFragments(in: line),
                      parsed.first?.start ?? -.infinity >= starts[0] else { return plain }
                fragments = parsed
                line = parsed.map(\.text).joined()
                hasFragments = true
            } else {
                fragments = []
            }
            for start in starts {
                segments.append(Segment(start: start, text: line, fragments: fragments, line: index + 1))
            }
        }
        guard !segments.isEmpty else { return plain }
        if let offset {
            // Positive LRC offsets display/speak earlier, so subtract from each Timestamp.
            segments = segments.map { segment in
                Segment(start: segment.start - offset, text: segment.text,
                        fragments: segment.fragments.map {
                            TimedFragment(start: $0.start - offset, text: $0.text,
                                          end: $0.end.map { $0 - offset })
                        }, line: segment.line)
            }
        }
        segments.sort { $0.start == $1.start ? $0.line < $1.line : $0.start < $1.start }
        return ParsedDocument(format: hasFragments ? .enhancedLRC : .lrc, segments: segments)
    }

    private static func matches(_ regex: NSRegularExpression, _ text: String) -> Bool {
        regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    private static func timestamp(_ match: NSTextCheckingResult, in text: String) -> Double? {
        func group(_ index: Int) -> String {
            guard let range = Range(match.range(at: index), in: text) else { return "" }
            return String(text[range])
        }
        guard let minutes = Double(group(1)), let seconds = Double(group(2)) else { return nil }
        let fraction = group(3)
        let result = minutes * 60 + seconds + (fraction.isEmpty ? 0 : Double("0." + fraction)!)
        return result.isFinite ? result : nil
    }

    private static func parseFragments(in text: String) -> [TimedFragment]? {
        let range = NSRange(text.startIndex..., in: text)
        let matches = inlineTag.matches(in: text, range: range)
        guard !matches.isEmpty, matches[0].range.location == 0 else { return nil }
        var remainder = text
        for match in matches.reversed() {
            guard let range = Range(match.range, in: remainder) else { return nil }
            remainder.removeSubrange(range)
        }
        guard !remainder.contains("<"), !remainder.contains(">") else { return nil }
        var fragments: [TimedFragment] = []
        for (index, match) in matches.enumerated() {
            guard let start = timestamp(match, in: text) else { return nil }
            let textStart = match.range.location + match.range.length
            let textEnd = index + 1 < matches.count ? matches[index + 1].range.location : range.length
            guard textEnd >= textStart,
                  let fragmentRange = Range(NSRange(location: textStart, length: textEnd - textStart), in: text) else { return nil }
            let next = index + 1 < matches.count ? timestamp(matches[index + 1], in: text) : nil
            guard next == nil || next! > start else { return nil }
            fragments.append(TimedFragment(start: start, text: String(text[fragmentRange]), end: next))
        }
        return fragments
    }
}
