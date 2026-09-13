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
        XCTAssertFalse(arguments.contains(text))
        XCTAssertEqual(arguments, ["-r", "212", "-f", "/tmp/input file", "-v", "A Voice", "-o", "/tmp/a file;name.wav", "--file-format=WAVE", "--data-format=LEI16"])
        XCTAssertEqual(try SayArguments.inputText(for: request), text)
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
        guard case .nativeOutputUnavailable(let message) = PersonalVoiceNativeOutput.unavailable(from: result) else {
            return XCTFail("Expected typed native-output unavailability")
        }
        XCTAssertEqual(message, "本机不支持直接输出")
        XCTAssertNil(PersonalVoiceNativeOutput.unavailable(
            from: SayProcessResult(status: 0, standardOutput: "", standardError: "warning")))
    }

    func testCaptureCleanupFailureRemainsObservableAndRetryable() {
        var deviceDestroyAttempts = 0
        var tapDestroyAttempts = 0
        let operations = CoreAudioCleanupOperations(
            stopDevice: { _, _ in noErr },
            destroyIO: { _, _ in noErr },
            destroyDevice: { _ in
                deviceDestroyAttempts += 1
                return deviceDestroyAttempts == 1 ? -1 : noErr
            },
            destroyTap: { _ in tapDestroyAttempts += 1; return noErr }
        )
        let lifecycle = CaptureResourceLifecycle(operations: operations)
        lifecycle.deviceID = 10
        lifecycle.tapID = 20

        XCTAssertEqual(lifecycle.destroyObjects(), -1)
        XCTAssertEqual(lifecycle.deviceID, 10, "A failed destroy must retain the ID for cleanup retry")
        XCTAssertEqual(lifecycle.tapID, 20, "The tap remains owned by the aggregate device until that device is destroyed")
        XCTAssertEqual(tapDestroyAttempts, 0)
        XCTAssertEqual(lifecycle.destroyObjects(), noErr)
        XCTAssertEqual(lifecycle.deviceID, AudioObjectID(kAudioObjectUnknown))
        XCTAssertEqual(lifecycle.tapID, AudioObjectID(kAudioObjectUnknown))
        XCTAssertEqual(tapDestroyAttempts, 1)
    }

    func testCaptureCleanupRetainsTheDeviceUntilIOProcDestructionCanBeRetried() {
        var destroyIOAttempts = 0
        var destroyedObjects = 0
        let operations = CoreAudioCleanupOperations(
            stopDevice: { _, _ in noErr },
            destroyIO: { _, _ in
                destroyIOAttempts += 1
                return destroyIOAttempts == 1 ? -1 : noErr
            },
            destroyDevice: { _ in destroyedObjects += 1; return noErr },
            destroyTap: { _ in destroyedObjects += 1; return noErr }
        )
        let lifecycle = CaptureResourceLifecycle(operations: operations)
        lifecycle.deviceID = 10
        lifecycle.tapID = 20
        lifecycle.ioProc = { _, _, _, _, _, _, _ in noErr }
        lifecycle.isRunning = true

        XCTAssertEqual(lifecycle.stopIO(), -1)
        XCTAssertNotNil(lifecycle.ioProc)
        XCTAssertEqual(lifecycle.destroyObjects(), kAudioHardwareIllegalOperationError)
        XCTAssertEqual(destroyedObjects, 0)
        XCTAssertEqual(lifecycle.deviceID, 10)
        XCTAssertEqual(lifecycle.tapID, 20)

        XCTAssertEqual(lifecycle.stopIO(), noErr)
        XCTAssertNil(lifecycle.ioProc)
        XCTAssertEqual(lifecycle.destroyObjects(), noErr)
        XCTAssertEqual(destroyedObjects, 2)
    }
}
