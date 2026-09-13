import Foundation

struct SayProcessResult: Sendable {
    let status: Int32
    let standardOutput: String
    let standardError: String

    func checked() throws -> String {
        guard status == 0 else {
            throw SpeechError.processFailed(standardError.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "The system speech process exited with status \(status)."
                : standardError.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return standardOutput
    }
}

/// Runs the system binary directly. Files keep diagnostics from filling a pipe and
/// blocking a long synthesis job before its termination callback can run.
@MainActor final class SayProcess {
    private var processes: [UUID: Process] = [:]

    func run(arguments: [String], input: Data? = nil,
             beforeInput: (@MainActor (Int32) async throws -> Void)? = nil) async throws -> SayProcessResult {
        try Task.checkCancellation()
        let identifier = UUID()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(identifier.uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false,
                                               attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(at: directory) }
        let outputURL = directory.appendingPathComponent("stdout")
        let errorURL = directory.appendingPathComponent("stderr")
        try Data().write(to: outputURL)
        try Data().write(to: errorURL)
        let output = try FileHandle(forWritingTo: outputURL)
        let error = try FileHandle(forWritingTo: errorURL)
        defer { try? output.close(); try? error.close() }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
        process.arguments = arguments
        let inputPipe = input == nil ? nil : Pipe()
        process.standardInput = inputPipe ?? FileHandle.nullDevice as Any
        process.standardOutput = output
        process.standardError = error
        processes[identifier] = process
        defer { processes.removeValue(forKey: identifier) }

        let status: Int32 = try await withTaskCancellationHandler {
            try process.run()
            do {
                if let beforeInput { try await beforeInput(process.processIdentifier) }
                try Task.checkCancellation()
                if let input, let inputPipe {
                    try await Task.detached {
                        defer { try? inputPipe.fileHandleForWriting.close() }
                        try inputPipe.fileHandleForWriting.write(contentsOf: input)
                    }.value
                }
            } catch {
                if process.isRunning { process.terminate() }
                await Task.detached { process.waitUntilExit() }.value
                throw error
            }
            return await Task.detached {
                process.waitUntilExit()
                return process.terminationStatus
            }.value
        } onCancel: {
            Task { @MainActor in
                if process.isRunning { process.terminate() }
            }
        }
        try Task.checkCancellation()
        return SayProcessResult(status: status,
                                standardOutput: String(decoding: try Data(contentsOf: outputURL), as: UTF8.self),
                                standardError: String(decoding: try Data(contentsOf: errorURL), as: UTF8.self))
    }

    func stop() {
        for process in processes.values where process.isRunning { process.terminate() }
    }
}
