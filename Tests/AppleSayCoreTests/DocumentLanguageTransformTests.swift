import Foundation
import Testing
@testable import AppleSayCore

@Suite struct DocumentLanguageTransformTests {
    @Test func plainTextIsTranslatedAsOneUnit() throws {
        let plan = try #require(DocumentTranslationPlan(document: "Hello\nworld"))

        #expect(plan.units == [DocumentTranslationUnit(id: 0, text: "Hello\nworld")])
        #expect(plan.applying(["Bonjour\nle monde"]) == "Bonjour\nle monde")
    }

    @Test func lrcTranslationPreservesTimestampsMetadataAndLineEndings() throws {
        let source = "[ar:Artist]\r\n[00:01.00]Hello\r\n[00:03][00:05]World"
        let plan = try #require(DocumentTranslationPlan(document: source))

        #expect(plan.units.map(\.text) == ["Hello", "World"])
        #expect(plan.applying(["你好", "世界"]) ==
            "[ar:Artist]\r\n[00:01.00]你好\r\n[00:03][00:05]世界")
    }

    @Test func enhancedLRCRequiresASeparateTimingAwareWorkflow() {
        #expect(DocumentTranslationPlan(document: "[00:01]<00:01>Hello <00:02>world") == nil)
    }

    @Test func writingToolsIgnoreOnlyTimedTextMarkup() {
        let source = "[ar:Artist]\n[00:01.00]<00:01>Hello <00:02>world"
        let fullRange = NSRange(source.startIndex..<source.endIndex, in: source)
        let ignored = TimedTextMarkup.ranges(in: source, intersecting: fullRange)
            .map { (source as NSString).substring(with: $0) }

        #expect(ignored == ["[ar:Artist]", "[00:01.00]", "<00:01>", "<00:02>"])
        #expect(TimedTextMarkup.ranges(in: "Ordinary [bracketed] prose", intersecting: fullRange).isEmpty)
    }
}
