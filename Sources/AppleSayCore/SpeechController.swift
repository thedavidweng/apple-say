import Foundation
import Observation

public enum SpeechJobState: Equatable {
    case idle, preparing, previewing, exporting, stopping, completed, cancelled, failed(String)
    public var isActive: Bool {
        switch self { case .preparing, .previewing, .exporting, .stopping: true; default: false }
    }
}

public struct SpeechResult {
    public let format: DocumentFormat
    public let destination: URL?
    public let placements: [AudioPlacement]
    public let usedPersonalVoiceCapture: Bool
}

public struct AudioPlacement: Equatable, Sendable {
    public let start: Double
    public let duration: Double
    public let speed: Int
    public let line: Int
    public let fragment: Int?
}

@MainActor @Observable public final class SpeechController {
    public private(set) var voices: [Voice] = []
    public private(set) var capabilities = SpeechCapabilities()
    public private(set) var authorization: PersonalVoiceAuthorization = .notDetermined
    public private(set) var state: SpeechJobState = .idle
    public private(set) var lastResult: SpeechResult?
    private let system: any SpeechSystem
    private let playback: any AudioPlayback
    private var job: Task<Void, Error>?

    public init(system: any SpeechSystem) {
        self.system = system
        self.playback = TimelinePlayback()
    }

    init(system: any SpeechSystem, playback: any AudioPlayback) {
        self.system = system
        self.playback = playback
    }

    public nonisolated static func analyze(_ text: String) -> ParsedDocument {
        TimedDocumentParser.parse(text)
    }

    public func refresh() async throws {
        let availableVoices = try await system.voices()
        let availableCapabilities = try await system.capabilities()
        voices = availableVoices
        capabilities = availableCapabilities
        authorization = system.authorization()
    }

    public func authorizePersonalVoice() async throws {
        authorization = await system.requestAuthorization()
        voices = try await system.voices()
    }

    public func preview(text: String, settings: SpeechSettings) async throws {
        try await perform(text: text, settings: settings, output: nil, destination: nil)
    }

    public func export(text: String, settings: SpeechSettings, output: ExportSettings, to destination: URL) async throws {
        try await perform(text: text, settings: settings, output: output, destination: destination)
    }

    public func stop() {
        if job != nil { state = .stopping }
        job?.cancel()
        system.stop()
        playback.stop()
    }

    private func perform(text: String, settings: SpeechSettings, output: ExportSettings?, destination: URL?) async throws {
        guard job == nil else { throw SpeechError.busy }
        let document = Self.analyze(text)
        try capabilities.validate(settings, output: output, timed: document.format != .plainText)
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SpeechError.invalidSettings("The Document is empty.")
        }
        if settings.voice?.isPersonal == true, system.authorization() != .authorized {
            throw SpeechError.invalidSettings("Authorize Personal Voice access before using this Voice.")
        }
        state = .preparing
        lastResult = nil
        let task = Task { @MainActor in
            try await self.execute(text: text, document: document, settings: settings, output: output, destination: destination)
        }
        job = task
        defer { job = nil }
        do {
            try await withTaskCancellationHandler {
                try await task.value
            } onCancel: {
                task.cancel()
            }
            state = .completed
        } catch {
            if task.isCancelled || error is CancellationError {
                state = .cancelled
            } else {
                state = .failed(error.localizedDescription)
            }
            throw error
        }
    }

    private func execute(text: String, document: ParsedDocument, settings: SpeechSettings,
                         output: ExportSettings?, destination: URL?) async throws {
        if let output, document.format != .plainText || settings.voice?.isPersonal == true {
            try await Task.detached { try AudioFiles.preflight(output) }.cancellableValue()
        }
        if document.format == .plainText, destination == nil {
            state = .previewing
            try await system.speak(SpeechRequest(text: text, settings: settings))
            try Task.checkCancellation()
            lastResult = SpeechResult(format: .plainText, destination: nil, placements: [], usedPersonalVoiceCapture: false)
            return
        }
        let scratch = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: scratch) }
        let artifact = scratch.appendingPathComponent("output.\((output ?? .init(container: .caf)).container.rawValue)")
        var synthesis = settings
        // Device routing belongs to playback; intermediate speech is rendered to a file.
        synthesis.outputDevice = nil
        synthesis.networkService = nil
        var captured = false
        var placements: [AudioPlacement] = []
        if document.format == .plainText {
            state = .exporting
            captured = try await render(SpeechRequest(text: text, settings: synthesis, destination: artifact,
                                                      output: output!), scratch: scratch)
        } else {
            let result = try await renderTimeline(document, settings: synthesis, scratch: scratch)
            placements = result.placements
            captured = result.captured
            let timeline = scratch.appendingPathComponent("timeline.caf")
            let clips = result.clips
            let end = max(document.segments.map(\.start).max() ?? 0,
                          placements.map { $0.start + $0.duration }.max() ?? 0)
            try await Task.detached {
                try AudioFiles.assemble(clips, to: timeline, endingAt: end)
            }.cancellableValue()
            if let output {
                state = .exporting
                try await Task.detached { try AudioFiles.convert(timeline, to: artifact, settings: output) }.cancellableValue()
            } else {
                state = .previewing
                try await playback.play(timeline, device: settings.outputDevice)
            }
        }
        try Task.checkCancellation()
        if let destination {
            _ = try AudioFiles.duration(of: artifact)
            try publish(artifact, to: destination)
        }
        lastResult = SpeechResult(format: document.format, destination: destination, placements: placements,
                                  usedPersonalVoiceCapture: captured)
    }

    private func render(_ request: SpeechRequest, scratch: URL) async throws -> Bool {
        do {
            try await system.speak(request)
            return false
        } catch SpeechError.nativeOutputUnavailable {
            guard request.settings.voice?.isPersonal == true, let destination = request.destination else { throw errorForNativeRoute() }
            let capture = scratch.appendingPathComponent(UUID().uuidString + ".caf")
            let captureRequest = SpeechRequest(text: request.text, settings: request.settings, destination: capture,
                                               output: .init(container: .caf))
            try Task.checkCancellation()
            try await system.capturePersonalVoice(captureRequest)
            try await Task.detached {
                try AudioFiles.convert(capture, to: destination, settings: request.output)
            }.cancellableValue()
            return true
        }
    }

    private func errorForNativeRoute() -> SpeechError {
        .processFailed("The native speech output path is unavailable.")
    }

    private struct RenderedTimeline {
        var clips: [(url: URL, start: Double)] = []
        var placements: [AudioPlacement] = []
        var captured = false
    }

    private func renderTimeline(_ document: ParsedDocument, settings: SpeechSettings, scratch: URL) async throws -> RenderedTimeline {
        var result = RenderedTimeline()
        for (index, segment) in document.segments.enumerated() {
            let nextSegment = document.segments.indices.contains(index + 1) ? document.segments[index + 1].start : nil
            guard segment.start >= 0, segment.start < Double(Int64.max) / AudioFiles.sampleRate else {
                throw TimingError(line: segment.line, fragment: nil, start: segment.start, deadline: nil)
            }
            let units: [(start: Double, text: String, end: Double?, fragment: Int?)] = segment.fragments.isEmpty
                ? [(segment.start, segment.text, nextSegment, nil)]
                : segment.fragments.enumerated().map { i, fragment in
                    let end = [fragment.end, nextSegment].compactMap { $0 }.min()
                    return (fragment.start, fragment.text, end, i + 1)
                }
            for unit in units where !unit.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                guard unit.start >= segment.start else {
                    throw TimingError(line: segment.line, fragment: unit.fragment, start: unit.start, deadline: unit.end)
                }
                let source = scratch.appendingPathComponent(UUID().uuidString + ".caf")
                let normalized = scratch.appendingPathComponent(UUID().uuidString + ".caf")
                var fitted = settings
                while true {
                    try Task.checkCancellation()
                    if let end = unit.end, end <= unit.start {
                        throw TimingError(line: segment.line, fragment: unit.fragment, start: unit.start, deadline: end)
                    }
                    let usedCapture: Bool
                    do {
                        usedCapture = try await render(SpeechRequest(text: unit.text, settings: fitted, destination: source,
                                                                   output: .init(container: .caf)), scratch: scratch)
                    } catch let error as SpeechError {
                        // A rate rejected during fitting is an unsatisfied timing constraint.
                        if fitted.speed != settings.speed, case .processFailed = error {
                            throw TimingError(line: segment.line, fragment: unit.fragment, start: unit.start, deadline: unit.end)
                        }
                        throw error
                    }
                    result.captured = result.captured || usedCapture
                    try await Task.detached { try AudioFiles.normalize(source, to: normalized) }.cancellableValue()
                    let duration = try AudioFiles.duration(of: normalized)
                    if let end = unit.end, (unit.start * AudioFiles.sampleRate).rounded() + (duration * AudioFiles.sampleRate).rounded() > (end * AudioFiles.sampleRate).rounded() {
                        guard fitted.speed < capabilities.speedRange.upperBound else {
                            throw TimingError(line: segment.line, fragment: unit.fragment, start: unit.start, deadline: end)
                        }
                        let proposed = ceil(Double(fitted.speed) * duration / (end - unit.start) * 1.02)
                        fitted.speed = Int(min(Double(capabilities.speedRange.upperBound), max(Double(fitted.speed + 1), proposed)))
                        continue
                    }
                    result.clips.append((normalized, unit.start))
                    result.placements.append(AudioPlacement(start: unit.start, duration: duration, speed: fitted.speed,
                                                            line: segment.line, fragment: unit.fragment))
                    break
                }
            }
        }
        return result
    }

    private func publish(_ artifact: URL, to destination: URL) throws {
        // Stage beside the destination so replacement is atomic even across volumes.
        let staged = destination.deletingLastPathComponent().appendingPathComponent(".apple-say-" + UUID().uuidString)
        try FileManager.default.copyItem(at: artifact, to: staged)
        defer { try? FileManager.default.removeItem(at: staged) }
        if FileManager.default.fileExists(atPath: destination.path) {
            _ = try FileManager.default.replaceItemAt(destination, withItemAt: staged)
        } else {
            try FileManager.default.moveItem(at: staged, to: destination)
        }
    }
}

private extension Task where Failure == Error {
    func cancellableValue() async throws -> Success {
        try await withTaskCancellationHandler { try await value } onCancel: { cancel() }
    }
}
