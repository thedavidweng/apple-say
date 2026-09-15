import Foundation
import CoreAudio
import XCTest
@testable import AppleSayCore

final class SayBoundaryTests: XCTestCase {
    func testCatalogPreservesNamesWithSpacesAndLocaleMetadata() {
        let listing = """
        Samantha            en_US    # Hello! My name is Samantha.
        Eddy (German (Germany)) de_DE # Hallo!
        Personal Voice 2    zh_CN    # 你好
        not a voice listing
        """
        XCTAssertEqual(SayCatalog.voices(from: listing), [
            Voice(id: "Samantha", name: "Samantha", language: "en_US"),
            Voice(id: "Eddy (German (Germany))", name: "Eddy (German (Germany))", language: "de_DE"),
            Voice(id: "Personal Voice 2", name: "Personal Voice 2", language: "zh_CN")
        ])
    }

    func testDeviceCatalogPreservesNumericIdentityAndFullName() {
        XCTAssertEqual(SayCatalog.devices(from: "   74 MacBook Air Speakers\n109 USB Audio Device\nerror"), [
            AudioDevice(id: "74", name: "MacBook Air Speakers"),
            AudioDevice(id: "109", name: "USB Audio Device")
        ])
    }

    func testSystemLanguagePrefersAnExactInstalledVoiceLocale() {
        let voices = [
            Voice(id: "uk", name: "Daniel", language: "en_GB"),
            Voice(id: "us", name: "Samantha", language: "en_US"),
            Voice(id: "cn", name: "Tingting", language: "zh_CN")
        ]
        XCTAssertEqual(VoiceLanguage.systemDefault(among: voices, preferredLanguages: ["en-US"]), "en_US")
        XCTAssertEqual(VoiceLanguage.systemDefault(among: voices, preferredLanguages: ["zh-Hans-CN"]), "zh_CN")
    }

    func testSystemLanguageUsesTheFirstAvailableSameLanguageVariant() {
        let voices = [Voice(id: "fr", name: "Thomas", language: "fr_FR")]
        XCTAssertEqual(VoiceLanguage.systemDefault(among: voices, preferredLanguages: ["de-DE", "fr-CA"]), "fr_FR")
        XCTAssertNil(VoiceLanguage.systemDefault(among: voices, preferredLanguages: ["ja-JP"]))
    }

    func testVoiceRecommendationPrefersQualityAndRejectsSurprisingDefaults() {
        let voices = [
            Voice(id: "personal", name: "My Voice", language: "en_US", isPersonal: true, quality: .premium),
            Voice(id: "novelty", name: "Bells", language: "en_US", isNovelty: true, quality: .premium),
            Voice(id: "standard", name: "Ralph", language: "en_US"),
            Voice(id: "compact", name: "Samantha", language: "en_US", quality: .compact),
            Voice(id: "enhanced", name: "Ava (Enhanced)", language: "en_US", quality: .enhanced),
            Voice(id: "chinese", name: "Tingting", language: "zh_CN", quality: .premium)
        ]
        XCTAssertEqual(VoiceRecommendation.best(among: voices, language: "en_US")?.id, "enhanced")
        XCTAssertEqual(VoiceRecommendation.best(among: voices, language: "zh_CN")?.id, "chinese")
        XCTAssertNil(VoiceRecommendation.best(among: voices, language: "fr_FR"))
    }

    func testVoiceRecommendationSkipsLanguagesWithoutANaturalCandidate() {
        let voices = [
            Voice(id: "novelty", name: "Bells", language: "en_US", isNovelty: true, quality: .premium),
            Voice(id: "personal", name: "My Voice", language: "en_US", isPersonal: true, quality: .premium),
            Voice(id: "french", name: "Thomas", language: "fr_FR", quality: .compact)
        ]
        XCTAssertEqual(VoiceRecommendation.best(
            among: voices,
            preferredLanguages: ["en-US", "fr-FR"]
        )?.id, "french")
    }

    func testVoiceRecommendationPrioritizesHighestQualityAcrossPreferredLanguages() {
        let voices = [
            Voice(id: "chinese_compact", name: "Tingting", language: "zh_CN", quality: .compact),
            Voice(id: "english_premium", name: "Ava (Premium)", language: "en_US", quality: .premium),
            Voice(id: "english_compact", name: "Samantha", language: "en_US", quality: .compact)
        ]
        // Even though zh-Hans-CN is listed first, Ava (Premium) has far better quality and gives the best first impression
        XCTAssertEqual(VoiceRecommendation.best(
            among: voices,
            preferredLanguages: ["zh-Hans-CN", "en-US"]
        )?.id, "english_premium")
    }

    func testVoiceRecommendationRespectsLanguagePreferenceWhenQualityIsEqual() {
        let voices = [
            Voice(id: "chinese_compact", name: "Tingting", language: "zh_CN", quality: .compact),
            Voice(id: "english_compact", name: "Samantha", language: "en_US", quality: .compact)
        ]
        // When qualities are equal, respect the user's primary language preference
        XCTAssertEqual(VoiceRecommendation.best(
            among: voices,
            preferredLanguages: ["zh-Hans-CN", "en-US"]
        )?.id, "chinese_compact")
        XCTAssertEqual(VoiceRecommendation.best(
            among: voices,
            preferredLanguages: ["en-US", "zh-Hans-CN"]
        )?.id, "english_compact")
    }

    @MainActor func testVoiceMetadataMergeRejectsAmbiguousPersonalVoiceNames() {
        let catalog = [Voice(id: "Samantha", name: "Samantha", language: "en_US")]
        let metadata = [
            SystemVoiceMetadata(name: "Samantha", language: "en-US", isPersonal: false,
                                isNovelty: false, quality: .compact),
            SystemVoiceMetadata(name: "Samantha", language: "en-US", isPersonal: true,
                                isNovelty: false, quality: .premium)
        ]
        XCTAssertTrue(SystemSpeech.merge(catalog: catalog, metadata: metadata).isEmpty)
    }

    func testSpeechContentNeverBecomesAProcessArgument() throws {
        var settings = SpeechSettings(voice: Voice(id: "a", name: "A Voice", language: "en_US"))
        settings.speed = 212
        let text = "--voice=Other; $(touch /tmp/no); `echo no`\n世界"
        let request = SpeechRequest(text: text, settings: settings,
                                    destination: URL(fileURLWithPath: "/tmp/a file;name.wav"),
                                    output: ExportSettings(container: .wav))
        let arguments = try SayArguments.make(for: request, input: URL(fileURLWithPath: "/tmp/input file"))
        XCTAssertEqual(arguments, [
            "-r", "212", "-f", "/tmp/input file", "-v", "A Voice",
            "-o", "/tmp/a file;name.wav", "--file-format=WAVE", "--data-format=LEI16"
        ])
        XCTAssertEqual(try SayArguments.inputText(for: request), text)
    }

    func testSystemVoiceSelectionOmitsExplicitVoiceArgument() throws {
        var settings = SpeechSettings(voice: nil)
        settings.speed = 180
        let request = SpeechRequest(text: "Hello", settings: settings,
                                    destination: URL(fileURLWithPath: "/tmp/out.aiff"),
                                    output: ExportSettings(container: .aiff))
        let arguments = try SayArguments.make(for: request, input: URL(fileURLWithPath: "/tmp/in.txt"))
        XCTAssertFalse(arguments.contains("-v"))
        XCTAssertEqual(arguments, [
            "-r", "180", "-f", "/tmp/in.txt",
            "-o", "/tmp/out.aiff", "--file-format=AIFF", "--data-format=BEI16"
        ])
    }

    func testCurrentSystemVoiceInspectionDoesNotCrash() {
        let info = SystemSpeech.currentSystemVoice()
        if let info {
            XCTAssertFalse(info.identifier.isEmpty)
            XCTAssertFalse(info.name.isEmpty)
        }
    }

    func testPitchUsesSpeechMarkupWithoutChangingDocument() throws {
        var settings = SpeechSettings()
        settings.pitch = 150
        let request = SpeechRequest(text: "Hello", settings: settings)
        XCTAssertEqual(try SayArguments.inputText(for: request), "[[pbas 150.0]]Hello")
        XCTAssertEqual(request.text, "Hello")
        settings.pitch = .nan
        XCTAssertThrowsError(try SayArguments.inputText(for: SpeechRequest(text: "Hello", settings: settings)))
    }

    func testConflictingPlaybackRoutesAndExportRoutingAreRejected() throws {
        var settings = SpeechSettings()
        settings.outputDevice = "74"
        settings.networkService = ":52800"
        let input = URL(fileURLWithPath: "/tmp/input")
        XCTAssertThrowsError(try SayArguments.make(for: SpeechRequest(text: "Hello", settings: settings), input: input))
        settings.networkService = nil
        XCTAssertThrowsError(try SayArguments.make(for: SpeechRequest(text: "Hello", settings: settings,
                                                                      destination: URL(fileURLWithPath: "/tmp/output.aiff")), input: input))
    }

    func testExportValidationUsesTheSelectedDataFormatProfile() throws {
        let capabilities = SpeechCapabilities(outputs: [
            OutputCapability(container: .m4a, profiles: [
                AudioDataCapability(dataFormat: "aac", channels: [1], bitRates: [128_000], supportsQuality: true),
                AudioDataCapability(dataFormat: "alac", channels: [1, 2])
            ])
        ])
        var output = ExportSettings(container: .m4a)
        output.dataFormat = "aac"
        output.channels = 1
        output.bitRate = 128_000
        output.quality = 96
        XCTAssertNoThrow(try capabilities.validate(.init(), output: output, timed: false))

        output.channels = 2
        XCTAssertThrowsError(try capabilities.validate(.init(), output: output, timed: false))
        output.dataFormat = "alac"
        output.channels = 2
        XCTAssertThrowsError(try capabilities.validate(.init(), output: output, timed: false),
                             "AAC settings must not leak into the ALAC profile")
    }

    func testAnyPersonalVoiceNativeOutputRejectionProducesTheTypedCompatibilityResult() {
        let result = SayProcessResult(status: 1, standardOutput: "", standardError: "本机不支持直接输出")
        guard case .nativeOutputUnavailable(let message) = SystemSpeech.personalVoiceNativeError(from: result) else {
            return XCTFail("Expected typed native-output unavailability")
        }
        XCTAssertEqual(message, "本机不支持直接输出")
        XCTAssertNil(SystemSpeech.personalVoiceNativeError(
            from: SayProcessResult(status: 0, standardOutput: "", standardError: "warning")))
    }

    @MainActor func testRealCapabilityDiscoveryCompletesQuickly() async throws {
        let runner = SayProcess()
        let start = Date()
        let caps = try await SayCapabilityDiscovery.discover(using: runner)
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertFalse(caps.outputs.isEmpty)
        XCTAssertLessThan(elapsed, 3.0, "Discovery must complete in under 3 seconds, but took \(elapsed)s")
    }
}
