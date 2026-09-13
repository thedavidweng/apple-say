import Foundation
import AVFAudio
import Testing
@testable import AppleSayCore

@MainActor final class TestSpeechSystem: SpeechSystem {
    var requests: [SpeechRequest] = []
    var captureRequests: [SpeechRequest] = []
    var stopped = false
    var durations: [String: Double] = [:]
    var auth: PersonalVoiceAuthorization = .notDetermined
    var rejectNativePersonalOutput = false
    var captureSucceeds = false
    var captureError: SpeechError?
    var waitsUntilStopped = false
    let availableVoices = [Voice(id: "standard", name: "Standard", language: "en_US"),
                           Voice(id: "personal", name: "Personal", language: "en_US", isPersonal: true)]
    var availableCapabilities = SpeechCapabilities(outputs: [.init(container: .caf, profiles: [
        .init(dataFormat: "LEI16", channels: [1]),
        .init(dataFormat: "LEF32", channels: [1])
    ])], devices: [.init(id: "device-1", name: "Test Device")], speedRange: 100...400)
    func voices() async throws -> [Voice] { availableVoices }
    func capabilities() async throws -> SpeechCapabilities { availableCapabilities }
    func authorization() -> PersonalVoiceAuthorization { auth }
    func requestAuthorization() async -> PersonalVoiceAuthorization { auth = .authorized; return auth }
    func speak(_ request: SpeechRequest) async throws {
        requests.append(request)
        while waitsUntilStopped && !stopped { try await Task.sleep(for: .milliseconds(10)) }
        if rejectNativePersonalOutput, request.settings.voice?.isPersonal == true, request.destination != nil {
            throw SpeechError.nativeOutputUnavailable("Test route")
        }
        if let destination = request.destination { try writeAudio(for: request, to: destination) }
    }
    func capturePersonalVoice(_ request: SpeechRequest) async throws {
        captureRequests.append(request)
        if let captureError { throw captureError }
        guard captureSucceeds, let destination = request.destination else { throw SpeechError.captureUnavailable("Test") }
        try writeAudio(for: request, to: destination)
    }
    func stop() { stopped = true }

    private func writeAudio(for request: SpeechRequest, to destination: URL) throws {
        let natural = durations[request.text] ?? 0.2
        let duration = natural * 175 / Double(request.settings.speed)
        let format = AVAudioFormat(standardFormatWithSampleRate: AudioFiles.sampleRate, channels: 1)!
        let file = try AVAudioFile(forWriting: destination, settings: format.settings)
        let frames = AVAudioFrameCount((duration * format.sampleRate).rounded())
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        for index in 0..<Int(frames) { buffer.floatChannelData![0][index] = 0.2 }
        try file.write(from: buffer)
    }
}

@MainActor final class TestAudioPlayback: AudioPlayback {
    var durations: [Double] = []
    var devices: [String?] = []
    var stopped = false
    func play(_ url: URL, device: String?) async throws {
        durations.append(try AudioFiles.duration(of: url))
        devices.append(device)
    }
    func stop() { stopped = true }
}

@Suite @MainActor struct SpeechBehaviorTests {
    @Test func validLRCIsRecognizedWithMetadataAndRepeatedTimestamps() {
        let document = SpeechController.analyze("[ar:Artist]\n[00:03.25][00:06.00]Hello\n[00:01.00]First")
        #expect(document.format == .lrc)
        #expect(document.segments.map(\.start) == [1, 3.25, 6])
        #expect(document.segments.map(\.text) == ["First", "Hello", "Hello"])
    }

    @Test func offsetsAndMalformedTimedSyntaxRemainAuthoritative() {
        let shifted = SpeechController.analyze("[offset:+250]\n[00:01.00]Hello")
        #expect(shifted.format == .lrc)
        #expect(shifted.segments.first?.start == 0.75)
        for text in ["", "ordinary [123] prose", "[00:01]Hello\nnot timed", "[00:60]bad", "[00:01.0000]bad", "[00:01][broken]bad", "[ar:Only metadata]"] {
            #expect(SpeechController.analyze(text).format == .plainText)
        }
    }

    @Test func enhancedLRCPreservesTimedFragmentsBesideLineOnlySegments() {
        let document = SpeechController.analyze("[00:01.00]<00:01.00>Hello <00:01.50>world\n[00:03.00]Line only")
        #expect(document.format == .enhancedLRC)
        #expect(document.segments.count == 2)
        #expect(document.segments[0].text == "Hello world")
        #expect(document.segments[0].fragments == [
            TimedFragment(start: 1, text: "Hello ", end: 1.5),
            TimedFragment(start: 1.5, text: "world", end: nil)
        ])
        #expect(document.segments[1].fragments.isEmpty)
    }

    @Test func malformedInlineTimingKeepsTheWholeDocumentPlainText() {
        for text in [
            "[00:01]prefix <00:01>word",
            "[00:01]<00:00.50>early",
            "[00:01]<00:02>b<00:01>a",
            "[00:01]<broken>word",
            "[00:01]<00:01>ok<broken>",
            "[00:01][00:03]<00:01>duplicate"
        ] {
            #expect(SpeechController.analyze(text).format == .plainText)
        }
    }

    @Test func plainTextExportUsesTheNativeSpeechRequestAndPublishesAudio() async throws {
        let system = TestSpeechSystem()
        let controller = SpeechController(system: system)
        try await controller.refresh()
        var settings = SpeechSettings(voice: system.availableVoices[0])
        settings.speed = 220
        settings.pitch = 120
        var output = ExportSettings(container: .caf)
        output.dataFormat = "LEI16"
        output.channels = 1
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".caf")
        defer { try? FileManager.default.removeItem(at: destination) }

        try await controller.export(text: "Ordinary speech", settings: settings, output: output, to: destination)

        #expect(system.requests.count == 1)
        let request = try #require(system.requests.first)
        #expect(request.text == "Ordinary speech")
        #expect(request.settings == settings)
        #expect(request.output == output)
        #expect(request.destination != nil)
        #expect(try AudioFiles.duration(of: destination) > 0)
        #expect(controller.lastResult?.format == .plainText)
    }

    @Test func lrcExportFitsSpeechAndPreservesAbsolutePlacement() async throws {
        let system = TestSpeechSystem()
        system.durations = ["First": 2, "Second": 0.25]
        let controller = SpeechController(system: system)
        try await controller.refresh()
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".caf")
        defer { try? FileManager.default.removeItem(at: destination) }

        try await controller.export(
            text: "[00:01.00]First\n[00:02.00]Second",
            settings: .init(voice: system.availableVoices[0]),
            output: .init(container: .caf), to: destination
        )

        let placements = try #require(controller.lastResult?.placements)
        #expect(placements.map(\.start) == [1, 2])
        #expect(placements[0].speed > 175)
        #expect(placements[0].start + placements[0].duration <= 2.0 + 1 / AudioFiles.sampleRate)
        let exportedDuration = try AudioFiles.duration(of: destination)
        #expect(exportedDuration >= 2.24)
    }

    @Test func timedExportPreflightsTheExactConverterBeforeSynthesizingText() async throws {
        let system = TestSpeechSystem()
        system.availableCapabilities.outputs = [OutputCapability(container: .caf, profiles: [
            AudioDataCapability(dataFormat: "unsupported", channels: [1])
        ])]
        let controller = SpeechController(system: system)
        try await controller.refresh()
        var output = ExportSettings(container: .caf)
        output.dataFormat = "unsupported"
        output.channels = 1
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".caf")
        defer { try? FileManager.default.removeItem(at: destination) }

        await #expect(throws: SpeechError.self) {
            try await controller.export(text: "[00:01]Never spoken", settings: .init(),
                                        output: output, to: destination)
        }
        #expect(system.requests.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: destination.path))
    }

    @Test func unsatisfiedLRCConstraintReportsTheRelevantTimingError() async throws {
        let system = TestSpeechSystem()
        system.durations = ["Too long": 10]
        let controller = SpeechController(system: system)
        try await controller.refresh()
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".caf")
        defer { try? FileManager.default.removeItem(at: destination) }
        do {
            try await controller.export(text: "[00:01.00]Too long\n[00:01.10]Next",
                                        settings: .init(voice: system.availableVoices[0]),
                                        output: .init(container: .caf), to: destination)
            Issue.record("Expected a Timing Error")
        } catch let error as TimingError {
            #expect(error.line == 1)
            #expect(error.fragment == nil)
            #expect(error.deadline == 1.1)
        }
        #expect(!FileManager.default.fileExists(atPath: destination.path))
    }

    @Test func enhancedLRCUsesFragmentLevelSynthesisAndPlacement() async throws {
        let system = TestSpeechSystem()
        system.durations = ["Hello ": 0.2, "world": 0.2, "Line": 0.2]
        let controller = SpeechController(system: system)
        try await controller.refresh()
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".caf")
        defer { try? FileManager.default.removeItem(at: destination) }

        try await controller.export(text: "[00:01]<00:01>Hello <00:01.50>world\n[00:02]Line",
                                    settings: .init(voice: system.availableVoices[0]),
                                    output: .init(container: .caf), to: destination)

        let placements = try #require(controller.lastResult?.placements)
        #expect(controller.lastResult?.format == .enhancedLRC)
        #expect(placements.map(\.start) == [1, 1.5, 2])
        #expect(placements.map(\.fragment) == [1, 2, nil])
        #expect(system.requests.map(\.text) == ["Hello ", "world", "Line"])
    }

    @Test func timedTextPreviewUsesTheSameAbsoluteTimelineAsExport() async throws {
        let system = TestSpeechSystem()
        system.durations = ["One": 0.2, "Two": 0.2]
        let playback = TestAudioPlayback()
        let controller = SpeechController(system: system, playback: playback)
        try await controller.refresh()
        var settings = SpeechSettings(voice: system.availableVoices[0])
        settings.outputDevice = "device-1"

        try await controller.preview(text: "[00:01]One\n[00:03]Two", settings: settings)

        #expect(controller.lastResult?.format == .lrc)
        #expect(controller.lastResult?.placements.map(\.start) == [1, 3])
        #expect(playback.devices.count == 1)
        #expect(playback.devices[0] == "device-1")
        #expect(playback.durations.first ?? 0 >= 3.19)
    }

    @Test func personalVoiceExportUsesCaptureOnlyAfterNativeOutputIsUnavailable() async throws {
        let system = TestSpeechSystem()
        system.auth = .authorized
        system.rejectNativePersonalOutput = true
        system.captureSucceeds = true
        let controller = SpeechController(system: system)
        try await controller.refresh()
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".caf")
        defer { try? FileManager.default.removeItem(at: destination) }

        try await controller.export(text: "Personal speech", settings: .init(voice: system.availableVoices[1]),
                                    output: .init(container: .caf), to: destination)

        #expect(controller.lastResult?.usedPersonalVoiceCapture == true)
        #expect(try AudioFiles.duration(of: destination) > 0)
        #expect(system.requests.count == 1)
    }

    @Test func personalVoiceKeepsAValidNativeOutputWithoutInvokingCapture() async throws {
        let system = TestSpeechSystem()
        system.auth = .authorized
        let controller = SpeechController(system: system)
        try await controller.refresh()
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".caf")
        defer { try? FileManager.default.removeItem(at: destination) }

        try await controller.export(text: "Native Personal", settings: .init(voice: system.availableVoices[1]),
                                    output: .init(container: .caf), to: destination)

        #expect(controller.lastResult?.usedPersonalVoiceCapture == false)
        #expect(try AudioFiles.duration(of: destination) > 0)
    }

    @Test func unavailablePersonalVoiceCaptureFailsClosedWithoutAffectingOrdinaryVoice() async throws {
        let system = TestSpeechSystem()
        system.auth = .authorized
        system.rejectNativePersonalOutput = true
        let controller = SpeechController(system: system)
        try await controller.refresh()
        let failedDestination = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".caf")
        let standardDestination = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".caf")
        defer {
            try? FileManager.default.removeItem(at: failedDestination)
            try? FileManager.default.removeItem(at: standardDestination)
        }
        do {
            try await controller.export(text: "Personal", settings: .init(voice: system.availableVoices[1]),
                                        output: .init(container: .caf), to: failedDestination)
            Issue.record("Expected Personal Voice capture to fail closed")
        } catch let error as SpeechError {
            guard case .captureUnavailable = error else {
                Issue.record("Expected captureUnavailable, received \(error)")
                return
            }
        }
        #expect(!FileManager.default.fileExists(atPath: failedDestination.path))

        try await controller.export(text: "Standard", settings: .init(voice: system.availableVoices[0]),
                                    output: .init(container: .caf), to: standardDestination)
        #expect(try AudioFiles.duration(of: standardDestination) > 0)
        #expect(controller.lastResult?.usedPersonalVoiceCapture == false)
    }

    @Test func personalVoiceCaptureFailureIsObservableAndPublishesNoArtifact() async throws {
        let system = TestSpeechSystem()
        system.auth = .authorized
        system.rejectNativePersonalOutput = true
        system.captureError = .captureFailed("Writer failed")
        let controller = SpeechController(system: system)
        try await controller.refresh()
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".caf")
        defer { try? FileManager.default.removeItem(at: destination) }
        do {
            try await controller.export(text: "Personal", settings: .init(voice: system.availableVoices[1]),
                                        output: .init(container: .caf), to: destination)
            Issue.record("Expected capture failure")
        } catch let error as SpeechError {
            #expect(error == .captureFailed("Writer failed"))
        }
        #expect(!FileManager.default.fileExists(atPath: destination.path))
        #expect(controller.state == .failed("Personal Voice audio capture failed: Writer failed"))
    }

    @Test func personalVoiceLRCUsesTheSharedTimelineAndCapturePath() async throws {
        let system = TestSpeechSystem()
        system.auth = .authorized
        system.rejectNativePersonalOutput = true
        system.captureSucceeds = true
        system.durations = ["One": 0.2, "Two": 0.2]
        let controller = SpeechController(system: system)
        try await controller.refresh()
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".caf")
        defer { try? FileManager.default.removeItem(at: destination) }

        try await controller.export(text: "[00:01]One\n[00:02]Two",
                                    settings: .init(voice: system.availableVoices[1]),
                                    output: .init(container: .caf), to: destination)

        #expect(controller.lastResult?.format == .lrc)
        #expect(controller.lastResult?.usedPersonalVoiceCapture == true)
        #expect(controller.lastResult?.placements.map(\.start) == [1, 2])
        #expect(system.captureRequests.map(\.settings.voice?.id) == ["personal", "personal"])
    }

    @Test func personalVoiceEnhancedLRCFitsTimedFragmentsWithoutChangingVoice() async throws {
        let system = TestSpeechSystem()
        system.auth = .authorized
        system.rejectNativePersonalOutput = true
        system.captureSucceeds = true
        system.durations = ["Stretch ": 0.6, "next": 0.15, "Line": 0.2]
        let controller = SpeechController(system: system)
        try await controller.refresh()
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".caf")
        defer { try? FileManager.default.removeItem(at: destination) }

        try await controller.export(text: "[00:01]<00:01>Stretch <00:01.30>next\n[00:02]Line",
                                    settings: .init(voice: system.availableVoices[1]),
                                    output: .init(container: .caf), to: destination)

        let placements = try #require(controller.lastResult?.placements)
        #expect(controller.lastResult?.format == .enhancedLRC)
        #expect(placements.map(\.fragment) == [1, 2, nil])
        #expect(placements[0].speed > 175)
        #expect(placements[0].start + placements[0].duration <= 1.3 + 1 / AudioFiles.sampleRate)
        #expect(system.captureRequests.allSatisfy { $0.settings.voice?.id == "personal" })
    }

    @Test func unsatisfiedEnhancedLRCConstraintIdentifiesTheTimedFragment() async throws {
        let system = TestSpeechSystem()
        system.durations = ["Impossible": 10]
        let controller = SpeechController(system: system)
        try await controller.refresh()
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".caf")
        defer { try? FileManager.default.removeItem(at: destination) }
        do {
            try await controller.export(text: "[00:01]<00:01>Impossible<00:01.10>next",
                                        settings: .init(voice: system.availableVoices[0]),
                                        output: .init(container: .caf), to: destination)
            Issue.record("Expected a Timed Fragment error")
        } catch let error as TimingError {
            #expect(error.line == 1)
            #expect(error.fragment == 1)
            #expect(error.deadline == 1.1)
        }
    }

    @Test func personalVoiceAuthorizationStatesFlowThroughTheOrchestrationSeam() async throws {
        let system = TestSpeechSystem()
        let controller = SpeechController(system: system)
        for state: PersonalVoiceAuthorization in [.notDetermined, .denied, .restricted, .authorized] {
            system.auth = state
            try await controller.refresh()
            #expect(controller.authorization == state)
        }
        system.auth = .notDetermined
        try await controller.authorizePersonalVoice()
        #expect(controller.authorization == .authorized)
        #expect(controller.voices.contains { $0.isPersonal })
    }

    @Test func systemAudioConversionProducesRequestedCompressedArtifact() throws {
        let system = TestSpeechSystem()
        let source = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".caf")
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
        defer {
            try? FileManager.default.removeItem(at: source)
            try? FileManager.default.removeItem(at: destination)
        }
        try system.speakSynchronouslyForTest(text: "Audio", destination: source)
        var output = ExportSettings(container: .m4a)
        output.dataFormat = "aac"
        output.bitRate = 128_000
        output.quality = 96
        try AudioFiles.convert(source, to: destination, settings: output)
        #expect(try AudioFiles.duration(of: destination) > 0)
    }

    @Test func plainTextPreviewPreservesArbitraryInput() async throws {
        let system = TestSpeechSystem()
        let controller = SpeechController(system: system)
        let text = "Hello $(touch /tmp/unsafe); 'quoted'\n你好"
        try await controller.preview(text: text, settings: .init())
        #expect(system.requests.count == 1)
        #expect(system.requests.first?.text == text)
        #expect(system.requests.first?.destination == nil)
        #expect(controller.state == .completed)
        controller.stop()
        #expect(system.stopped)
    }

    @Test func stopKeepsTheJobBusyUntilCancellationFinishes() async throws {
        let system = TestSpeechSystem()
        system.waitsUntilStopped = true
        let controller = SpeechController(system: system)
        try await controller.refresh()
        let running = Task {
            try await controller.preview(text: "Long preview", settings: .init())
        }
        while controller.state != .previewing { await Task.yield() }
        controller.stop()
        #expect(controller.state == .stopping)
        #expect(controller.state.isActive)
        do {
            try await controller.preview(text: "Too soon", settings: .init())
            Issue.record("Expected the cancelling job to remain busy")
        } catch let error as SpeechError {
            #expect(error == .busy)
        }
        _ = await running.result
        #expect(controller.state == .cancelled)
        system.waitsUntilStopped = false
        try await controller.preview(text: "Next preview", settings: .init())
        #expect(controller.state == .completed)
    }
}

private extension TestSpeechSystem {
    func speakSynchronouslyForTest(text: String, destination: URL) throws {
        try writeAudio(for: SpeechRequest(text: text, settings: .init(), destination: destination,
                                          output: .init(container: .caf)), to: destination)
    }
}
